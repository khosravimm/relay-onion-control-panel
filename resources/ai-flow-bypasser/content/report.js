'use strict';

/**
 * Reads the diagnostic the page-side patch writes onto <html> and answers the
 * popup's status query. Read-only; it never touches the page itself.
 *
 * The attribute name is written by the page patch — do not rename it.
 */
const DIAGNOSTIC_ATTRIBUTE = 'data-flow-local-diagnostic';
const MAX_STATE_LENGTH = 80;

chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (sender.id !== chrome.runtime.id || message?.type !== 'status') return undefined;

  let diagnostic = null;
  try {
    diagnostic = JSON.parse(document.documentElement.getAttribute(DIAGNOSTIC_ATTRIBUTE) || 'null');
  } catch {
    /* absent or malformed — reported as not-loaded below */
  }

  sendResponse({
    state:
      typeof diagnostic?.state === 'string'
        ? diagnostic.state.slice(0, MAX_STATE_LENGTH)
        : 'not-loaded',
    applied: diagnostic?.applied > 0,
  });
  return undefined;
});
