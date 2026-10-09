'use strict';

/**
 * AI Flow Bypasser — service worker.
 *
 * Owns three things:
 *   1. whether the page patch is registered (source of truth: storage.local.enabled),
 *   2. the patch descriptor handed to the page (fetched, cached, with a baked-in floor),
 *   3. reloading Flow tabs so a toggle takes effect without the user doing anything.
 */

const SPEC_ENDPOINT = 'https://flow.cfcnode.com/v1/flow-spec';
const SPEC_TTL_MS = 6 * 60 * 60 * 1000;
const SPEC_BACKOFF_MS = [500, 1500, 4000];

/**
 * Last known-good descriptor, shipped with the build. It is the floor: if the
 * network is gone and nothing is cached, the patch still arms instead of the
 * page sitting inert forever. Overwritten by any successful fetch.
 */
const FALLBACK_SPEC = Object.freeze({
  v: 1,
  origin: 'https://flow.google.com',
  path: '/_/AiSandboxAngularFrontend/data/batchexecute',
  rpcids: 'cPZSdc',
  tag: 'wrb.fr',
  flagIndex: 30,
  minLength: 32,
});

const PATCH_SCRIPT = {
  id: 'flow-patch',
  matches: ['https://flow.google.com/*'],
  js: ['vendor/flow-patch.js'],
  runAt: 'document_start',
  world: 'MAIN',
  persistAcrossSessions: true,
};
const PATCH_IDS = [PATCH_SCRIPT.id];

const FLOW_TAB_FILTER = 'https://flow.google.com/*';
const UNSUPPORTED_SUFFIX = '/unsupported-country';
const KEY_ENABLED = 'enabled';
const KEY_SPEC = 'specCache';
const LOG_TAG = '[AI Flow Bypasser]';

const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// ---------------------------------------------------------------- spec

/** Shape check. A malformed descriptor is worse than no descriptor. */
function isValidSpec(spec) {
  return (
    !!spec &&
    typeof spec === 'object' &&
    typeof spec.origin === 'string' &&
    spec.origin.startsWith('https://') &&
    typeof spec.path === 'string' &&
    spec.path.startsWith('/') &&
    typeof spec.rpcids === 'string' &&
    spec.rpcids.length > 0 &&
    typeof spec.tag === 'string' &&
    spec.tag.length > 0 &&
    Number.isInteger(spec.flagIndex) &&
    spec.flagIndex >= 0 &&
    Number.isInteger(spec.minLength) &&
    spec.minLength > spec.flagIndex
  );
}

let memoSpec = null;
let memoFetchedAt = 0;
let refreshInFlight = null;

async function readCachedSpec() {
  try {
    const stored = (await chrome.storage.local.get(KEY_SPEC))[KEY_SPEC];
    if (stored && isValidSpec(stored.spec) && Number.isFinite(stored.fetchedAt)) return stored;
  } catch {
    /* storage unavailable — fall through to the network */
  }
  return null;
}

async function fetchSpec() {
  for (let attempt = 0; attempt < SPEC_BACKOFF_MS.length; attempt++) {
    try {
      const response = await fetch(SPEC_ENDPOINT, { cache: 'no-store' });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const spec = await response.json();
      if (!isValidSpec(spec)) throw new Error('unexpected descriptor shape');
      return spec;
    } catch (err) {
      const lastAttempt = attempt === SPEC_BACKOFF_MS.length - 1;
      if (lastAttempt) {
        console.warn(`${LOG_TAG} descriptor fetch failed:`, err.message);
        return null;
      }
      await delay(SPEC_BACKOFF_MS[attempt]);
    }
  }
  return null;
}

function refreshSpec() {
  if (refreshInFlight) return refreshInFlight;
  refreshInFlight = fetchSpec()
    .then(async (spec) => {
      if (!spec) return null;
      memoSpec = spec;
      memoFetchedAt = Date.now();
      try {
        await chrome.storage.local.set({ [KEY_SPEC]: { spec, fetchedAt: memoFetchedAt } });
      } catch {
        /* cache is an optimisation, not a requirement */
      }
      return spec;
    })
    .finally(() => {
      refreshInFlight = null;
    });
  return refreshInFlight;
}

/**
 * Always resolves to a usable descriptor. Serves a stale cache immediately and
 * refreshes behind it, so a cold service worker never makes the page wait on
 * the network.
 */
async function getSpec() {
  const now = Date.now();
  if (memoSpec && now - memoFetchedAt < SPEC_TTL_MS) return memoSpec;

  const cached = await readCachedSpec();
  if (cached) {
    memoSpec = cached.spec;
    memoFetchedAt = cached.fetchedAt;
    if (now - cached.fetchedAt < SPEC_TTL_MS) return memoSpec;
  }

  const refresh = refreshSpec();
  if (memoSpec) {
    refresh.catch(() => {});
    return memoSpec;
  }
  return (await refresh) || FALLBACK_SPEC;
}

// -------------------------------------------------------- registration

/**
 * Registration changes run one at a time. Worker wake, onInstalled and a popup
 * toggle can all land together; interleaved read-then-write pairs would both
 * see "not registered" and the second register would throw on the duplicate id.
 */
let registrationQueue = Promise.resolve();
function serialize(task) {
  const next = registrationQueue.then(task, task);
  // The queue holder itself must never stay rejected, or it would log an
  // unhandled rejection; the caller still gets the real result.
  registrationQueue = next.catch(() => {});
  return next;
}

async function isPatchRegistered() {
  try {
    const registered = await chrome.scripting.getRegisteredContentScripts({ ids: PATCH_IDS });
    return registered.length > 0;
  } catch {
    return false;
  }
}

function applyRegistration(enabled) {
  return serialize(async () => {
    const registered = await isPatchRegistered();
    if (enabled && !registered) {
      try {
        await chrome.scripting.registerContentScripts([PATCH_SCRIPT]);
      } catch (err) {
        // Benign if something else won the race; anything else is real.
        if (!/duplicate/i.test(err.message)) throw err;
      }
    } else if (!enabled && registered) {
      await chrome.scripting.unregisterContentScripts({ ids: PATCH_IDS });
    }
  });
}

/**
 * Reconcile what is actually registered against what storage says. Runs on every
 * worker start: a Chrome update, a profile sync or a crash can drop a persisted
 * registration, and without this the popup would report "on" over a dead patch.
 */
async function syncRegistration() {
  let enabled = true;
  try {
    const stored = (await chrome.storage.local.get(KEY_ENABLED))[KEY_ENABLED];
    if (stored === undefined) {
      await chrome.storage.local.set({ [KEY_ENABLED]: true }); // default on
    } else {
      enabled = stored !== false;
    }
  } catch {
    /* default to on */
  }

  try {
    await applyRegistration(enabled);
  } catch (err) {
    console.error(`${LOG_TAG} could not sync registration:`, err.message);
  }
  return enabled;
}

// --------------------------------------------------------------- tabs

/** Reload open Flow tabs, escaping the unsupported-country page where present. */
async function reloadFlowTabs() {
  let tabs = [];
  try {
    tabs = await chrome.tabs.query({ url: FLOW_TAB_FILTER });
  } catch {
    return 0;
  }

  await Promise.all(
    tabs.map(async (tab) => {
      try {
        const url = new URL(tab.url);
        if (url.pathname.endsWith(UNSUPPORTED_SUFFIX)) {
          url.pathname = url.pathname.slice(0, -UNSUPPORTED_SUFFIX.length) || '/';
          await chrome.tabs.update(tab.id, { url: url.href });
        } else {
          await chrome.tabs.reload(tab.id);
        }
      } catch {
        /* tab closed or navigated away mid-flight */
      }
    })
  );
  return tabs.length;
}

// ------------------------------------------------------------- events

chrome.runtime.onInstalled.addListener((details) => {
  void (async () => {
    if (details.reason === 'install') {
      try {
        await chrome.storage.local.set({ [KEY_ENABLED]: true });
      } catch {
        /* syncRegistration falls back to on anyway */
      }
    }
    await syncRegistration();
    refreshSpec().catch(() => {});

    // First run only: say it is already on, and where to find it.
    if (details.reason === 'install') {
      chrome.tabs
        .create({ url: chrome.runtime.getURL('welcome/welcome.html') })
        .catch(() => {});
    }
  })();
});

chrome.runtime.onStartup.addListener(() => {
  void syncRegistration();
});

// Also on plain worker wake, so a dropped registration self-heals.
void syncRegistration();

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== chrome.runtime.id) return undefined;

  // From the page bridge (has sender.tab) as well as the popup.
  if (message?.type === 'getSpec') {
    getSpec()
      .then((spec) => sendResponse({ ok: !!spec, spec }))
      .catch(() => sendResponse({ ok: true, spec: FALLBACK_SPEC }));
    return true;
  }

  // Popup-only below.
  if (sender.tab) return undefined;

  if (message?.type === 'getState') {
    (async () => {
      const [stored, registered] = await Promise.all([
        chrome.storage.local.get(KEY_ENABLED),
        isPatchRegistered(),
      ]);
      sendResponse({ ok: true, enabled: stored[KEY_ENABLED] !== false, registered });
    })().catch((err) => sendResponse({ ok: false, error: err.message }));
    return true;
  }

  if (message?.type === 'setEnabled') {
    (async () => {
      const enabled = !!message.enabled;
      await chrome.storage.local.set({ [KEY_ENABLED]: enabled });
      await applyRegistration(enabled);
      if (enabled) refreshSpec().catch(() => {});
      const reloaded = await reloadFlowTabs();
      sendResponse({ ok: true, enabled, reloaded });
    })().catch((err) => sendResponse({ ok: false, error: err.message }));
    return true;
  }

  return undefined;
});
