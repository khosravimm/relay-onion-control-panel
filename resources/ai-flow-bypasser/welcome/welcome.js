'use strict';

const FLOW_URL = 'https://flow.google.com/';

document.getElementById('open').addEventListener('click', async () => {
  // Reuse an already-open Flow tab rather than stacking duplicates.
  const [existing] = await chrome.tabs.query({ url: `${FLOW_URL}*` });
  if (existing) {
    await chrome.tabs.update(existing.id, { active: true });
    await chrome.windows.update(existing.windowId, { focused: true });
  } else {
    await chrome.tabs.create({ url: FLOW_URL });
  }
});
