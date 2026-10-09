'use strict';

const FLOW_URL = 'https://flow.google.com/';

/** Detail lines, keyed by what the popup actually knows. */
const DETAIL = {
  off: { tone: 'closed', text: 'تا وقتی خاموش است، Flow ممکن است صفحهٔ «کشور پشتیبانی نمی‌شود» را نشان دهد.' },
  idle: { tone: 'open', text: 'یک تب Flow باز کنید تا اعمال شود.' },
  applied: { tone: 'open', text: 'روی این تب اعمال شد.' },
  armed: { tone: 'wait', text: 'آماده است؛ منتظر پاسخ Flow.' },
  preparing: { tone: 'wait', text: 'در حال آماده‌سازی…' },
  builtin: { tone: 'wait', text: 'سرور تنظیمات در دسترس نبود؛ نسخهٔ داخلی به کار رفت.' },
  outdated: { tone: 'warn', text: 'Flow تغییر کرده و افزونه به بروزرسانی نیاز دارد.' },
  reload: { tone: 'wait', text: 'این تب را دوباره بارگذاری کنید.' },
  reloaded: { tone: 'open', text: 'تب‌های باز Flow دوباره بارگذاری شدند.' },
  unregistered: { tone: 'warn', text: 'کلید روشن است اما ثبت نشده. یک بار خاموش و دوباره روشن کنید.' },
};

const HEADLINE_OPEN = 'دسترسی باز است';
const HEADLINE_CLOSED = 'دسترسی بسته است';

const els = {
  body: document.body,
  gate: document.querySelector('.gate'),
  headline: document.getElementById('headline'),
  detail: document.getElementById('detail'),
  switch: document.getElementById('switch'),
  open: document.getElementById('open'),
  error: document.getElementById('error'),
};

function render(enabled, key) {
  const detail = DETAIL[key] || DETAIL.idle;
  els.headline.textContent = enabled ? HEADLINE_OPEN : HEADLINE_CLOSED;
  els.detail.textContent = detail.text;
  els.body.dataset.tone = detail.tone;
  els.switch.setAttribute('aria-checked', String(enabled));
}

/** One ring flare on the panel, so a toggle is felt as well as read. */
function flare() {
  els.gate.classList.remove('is-flipping');
  void els.gate.offsetWidth; // restart the animation
  els.gate.classList.add('is-flipping');
}

function showError(message) {
  els.error.textContent = message;
  els.error.hidden = !message;
}

/** Translate the page patch's own diagnostic into a detail key. */
function keyFromDiagnostic(report) {
  if (!report) return 'reload';
  if (report.applied) return 'applied';

  const state = report.state || '';
  if (state === 'armed') return 'armed';
  if (state === 'awaiting-spec') return 'preparing';
  if (state.startsWith('spec unavailable') || state.startsWith('spec invalid')) return 'builtin';
  if (state.startsWith('schema mismatch')) return 'outdated';
  return 'reload';
}

async function activeFlowTab() {
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  return tab?.url?.startsWith(FLOW_URL) ? tab : null;
}

/**
 * `override` skips the per-tab probe. Used straight after a toggle, when the
 * tabs are mid-reload and would otherwise report themselves as stale.
 */
async function refresh(override) {
  const state = await chrome.runtime.sendMessage({ type: 'getState' });
  if (!state?.ok) throw new Error(state?.error || 'وضعیت افزونه خوانده نشد.');

  const { enabled, registered } = state;
  if (!enabled) return render(false, 'off');
  if (!registered) return render(true, 'unregistered');
  if (override) return render(true, override);

  const tab = await activeFlowTab();
  if (!tab) return render(true, 'idle');

  try {
    const report = await chrome.tabs.sendMessage(tab.id, { type: 'status' });
    render(true, keyFromDiagnostic(report));
  } catch {
    // No receiver: the tab loaded before the extension did.
    render(true, 'reload');
  }
}

els.switch.addEventListener('click', async () => {
  const next = els.switch.getAttribute('aria-checked') !== 'true';
  els.switch.disabled = true;
  showError('');

  // Optimistic, so the switch never feels laggy; refresh() corrects it.
  render(next, next ? 'idle' : 'off');
  flare();

  try {
    const result = await chrome.runtime.sendMessage({ type: 'setEnabled', enabled: next });
    if (!result?.ok) throw new Error(result?.error || 'تغییر وضعیت ذخیره نشد.');
    await refresh(next && result.reloaded > 0 ? 'reloaded' : undefined);
  } catch (err) {
    render(!next, !next ? 'idle' : 'off');
    showError(err.message);
  } finally {
    els.switch.disabled = false;
  }
});

els.open.addEventListener('click', async () => {
  // Reuse an open Flow tab wherever it is, rather than piling up duplicates.
  const [existing] = await chrome.tabs.query({ url: `${FLOW_URL}*` });
  if (existing) {
    await chrome.tabs.update(existing.id, { active: true });
    await chrome.windows.update(existing.windowId, { focused: true });
  } else {
    await chrome.tabs.create({ url: FLOW_URL });
  }
  window.close();
});

refresh()
  .catch((err) => showError(err.message))
  .finally(() => {
    els.switch.disabled = false;
  });
