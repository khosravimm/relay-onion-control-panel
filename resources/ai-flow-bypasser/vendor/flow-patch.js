'use strict';

/**
 * Runs in Flow's MAIN world at document_start.
 *
 * Flow returns its country-availability setting inside a framed batchexecute
 * response. This script intercepts only that one same-origin XHR response and
 * changes the configured boolean to true. No request bodies, prompts, media,
 * credentials, or response contents are sent anywhere.
 */
(() => {
  const DIAGNOSTIC_ATTRIBUTE = 'data-flow-local-diagnostic';
  const SPEC_MESSAGE = 'cfc-flow-spec';
  const SPEC_REQUEST = 'cfc-flow-spec-request';
  const LOG_TAG = '[AI Flow Bypasser]';

  const FALLBACK_SPEC = Object.freeze({
    origin: 'https://flow.google.com',
    path: '/_/AiSandboxAngularFrontend/data/batchexecute',
    rpcids: 'cPZSdc',
    tag: 'wrb.fr',
    flagIndex: 30,
    minLength: 32,
  });

  if (typeof module === 'object' && module.exports) {
    module.exports = { patch: (body) => patchResponse(body, FALLBACK_SPEC) };
    return;
  }

  // A persisted content-script registration can race a worker wake. Install
  // the interceptor once even if Chrome evaluates this file twice.
  if (window.__flowLocalDiagnostic) return;

  const diagnostic = (window.__flowLocalDiagnostic = {
    state: 'awaiting-spec',
    applied: 0,
  });

  function report(state, before) {
    Object.assign(diagnostic, { state, before });
    console.info(LOG_TAG, JSON.stringify(diagnostic));

    const publish = () => {
      document.documentElement.setAttribute(
        DIAGNOSTIC_ATTRIBUTE,
        JSON.stringify(diagnostic)
      );
    };

    if (document.documentElement) publish();
    else document.addEventListener('DOMContentLoaded', publish, { once: true });
  }

  function isValidSpec(value) {
    return (
      value &&
      typeof value === 'object' &&
      typeof value.origin === 'string' &&
      value.origin.startsWith('https://') &&
      typeof value.path === 'string' &&
      value.path.startsWith('/') &&
      typeof value.rpcids === 'string' &&
      value.rpcids.length > 0 &&
      typeof value.tag === 'string' &&
      value.tag.length > 0 &&
      Number.isInteger(value.flagIndex) &&
      value.flagIndex >= 0 &&
      Number.isInteger(value.minLength) &&
      value.minLength > value.flagIndex
    );
  }

  /**
   * Patch one framed batchexecute response while keeping its byte-count line
   * correct. Flow has used both UTF-8 byte counts and JavaScript string
   * lengths, so the original frame's declared length selects the same metric
   * for the replacement.
   */
  function patchResponse(body, spec) {
    const lines = body.split('\n');
    let before;
    let matches = 0;

    for (let index = 0; index < lines.length; index++) {
      if (!lines[index].startsWith('[[')) continue;

      let frame;
      try {
        frame = JSON.parse(lines[index]);
      } catch {
        continue;
      }

      let changed = false;
      for (const entry of frame) {
        if (!Array.isArray(entry) || entry[0] !== spec.tag || entry[1] !== spec.rpcids) {
          continue;
        }

        const payload = JSON.parse(entry[2]);
        const current = payload?.[spec.flagIndex];
        if (
          !Array.isArray(payload) ||
          payload.length < spec.minLength ||
          (current !== null && typeof current !== 'boolean')
        ) {
          throw new Error(`schema mismatch at ${spec.flagIndex} — unchanged`);
        }

        before = current;
        payload[spec.flagIndex] = true;
        entry[2] = JSON.stringify(payload);
        matches++;
        changed = true;
      }

      if (!changed) continue;

      const oldFrame = lines[index].replace(/\r$/, '');
      const declaredLength = Number(lines[index - 1]);
      const byteLength = (value) => new TextEncoder().encode(value).length;
      const metrics = [byteLength, (value) => value.length];
      const metric = metrics.find((measure) =>
        [0, 1, 2].includes(declaredLength - measure(oldFrame))
      );

      if (!metric) throw new Error('Unexpected frame length');

      const newFrame = JSON.stringify(frame);
      lines[index - 1] = String(declaredLength + metric(newFrame) - metric(oldFrame));
      lines[index] = newFrame;
    }

    if (matches !== 1) throw new Error('Expected one config response');
    return { body: lines.join('\n'), before };
  }

  let spec = null;
  let specResolved = false;
  const targetedRequests = new WeakMap();
  const patchedResponses = new WeakMap();

  const xhrPrototype = XMLHttpRequest.prototype;
  const originalOpen = xhrPrototype.open;

  xhrPrototype.open = function (method, url, ...rest) {
    let targeted = false;
    try {
      const parsed = new URL(url, location.href);
      if (spec) {
        targeted =
          parsed.origin === location.origin &&
          parsed.pathname === spec.path &&
          parsed.searchParams.get('rpcids') === spec.rpcids;
      } else {
        // The request can start before the isolated-world bridge returns the
        // descriptor. Remember the stable endpoint shape and wait to read the
        // response until the descriptor resolves.
        targeted =
          parsed.origin === location.origin &&
          parsed.pathname.startsWith('/data/batchexecute');
      }
    } catch {
      // A malformed URL is unrelated to the response we patch.
    }

    targetedRequests.set(this, targeted);
    patchedResponses.delete(this);
    return Reflect.apply(originalOpen, this, [method, url, ...rest]);
  };

  for (const property of ['responseText', 'response']) {
    const descriptor = Object.getOwnPropertyDescriptor(xhrPrototype, property);
    if (!descriptor?.get || !descriptor.configurable) continue;

    Object.defineProperty(xhrPrototype, property, {
      ...descriptor,
      get() {
        const original = Reflect.apply(descriptor.get, this, []);
        if (!targetedRequests.get(this) || typeof original !== 'string') return original;

        if (!spec) {
          diagnostic.heldForSpec = true;
          return this.readyState === 4 && specResolved ? original : '';
        }

        if (this.readyState === 3) {
          diagnostic.heldPartial = true;
          return '';
        }
        if (this.readyState !== 4) return original;

        if (!patchedResponses.has(this)) {
          try {
            const patched = patchResponse(original, spec);
            patchedResponses.set(this, patched.body);
            diagnostic.applied++;
            report('applied', patched.before);
          } catch (error) {
            patchedResponses.set(this, original);
            report(error.message || 'schema mismatch — unchanged');
          }
        }
        return patchedResponses.get(this);
      },
    });
  }

  window.addEventListener('message', (event) => {
    if (event.source !== window) return;
    const message = event.data;
    if (!message || message.type !== SPEC_MESSAGE || spec) return;

    if (!isValidSpec(message.spec)) {
      specResolved = true;
      report(message.spec === null ? 'spec unavailable — inert' : 'spec invalid — inert');
      return;
    }

    spec = message.spec;
    specResolved = true;
    report('armed');
  });

  let attempts = 0;
  const requestSpec = () => {
    if (spec || specResolved || attempts >= 40) {
      if (!spec) {
        specResolved = true;
        report('spec unavailable — inert');
      }
      return;
    }
    attempts++;
    window.postMessage({ type: SPEC_REQUEST }, location.origin);
    setTimeout(requestSpec, 500);
  };

  requestSpec();
  report('awaiting-spec');
})();
