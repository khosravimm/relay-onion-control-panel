'use strict';

/**
 * Isolated-world bridge: carries the patch descriptor from the service worker
 * into the page, which cannot talk to chrome.runtime itself.
 *
 * The two message names below are part of the wire protocol the page-side patch
 * listens for. They are matched literally there — do not rename them.
 */
(() => {
  const SPEC_MESSAGE = 'cfc-flow-spec';
  const SPEC_REQUEST = 'cfc-flow-spec-request';
  const WAKE_RETRY_MS = [150, 300, 600];

  let cached = null;
  let inFlight = null;

  async function askWorker() {
    try {
      const response = await chrome.runtime.sendMessage({ type: 'getSpec' });
      // Only a success is remembered. Caching a miss would wedge this tab for
      // its whole lifetime on a single cold-start hiccup.
      if (response?.ok && response.spec) cached = response.spec;
    } catch {
      /* worker asleep, or the extension context was torn down by a reload */
    }
    return cached;
  }

  function requestSpec() {
    if (cached) return Promise.resolve(cached);
    if (inFlight) return inFlight;
    inFlight = askWorker().finally(() => {
      inFlight = null;
    });
    return inFlight;
  }

  /** Give a cold service worker a few chances to wake before giving up. */
  async function resolveSpec() {
    for (let attempt = 0; attempt < WAKE_RETRY_MS.length; attempt++) {
      const spec = await requestSpec();
      if (spec) return spec;
      await new Promise((resolve) => setTimeout(resolve, WAKE_RETRY_MS[attempt]));
    }
    return requestSpec();
  }

  /**
   * Posted even when the descriptor is null: the page holds scripts inert until
   * it hears back, so silence would break Flow rather than merely leave it
   * unpatched.
   */
  function publish(spec) {
    window.postMessage({ type: SPEC_MESSAGE, spec: spec || null }, location.origin);
  }

  window.addEventListener('message', (event) => {
    if (event.source !== window) return;
    if (event.data?.type !== SPEC_REQUEST) return;
    resolveSpec().then(publish);
  });

  resolveSpec().then(publish);
})();
