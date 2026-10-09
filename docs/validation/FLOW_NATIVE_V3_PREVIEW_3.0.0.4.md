# v3.0.0.4 — Native Delphi Flow validation (pre-release)

Date: 2026-10-09
Baseline: v2.13.8.0, commit 96eac73.
Source: E:\Projects\third-party\relay-onion-control-panel-tunfix on SUMS.

## Implemented
- Flow button invokes `TFlowNativeV3` directly in Delphi; previous `Flow-V3.ps1` helper is removed from the install bundle.
- Discovers US exit relays dynamically from the application's in-memory `RoutersDic`; if not loaded, native `FlowCatalogV3` intersects the application's `network-cache` and `cached-microdesc-consensus`.
- Requires Exit, Running/Valid (when using consensus fallback), excludes BadExit and derives fingerprints dynamically. No approved exit IP or fingerprint is hardcoded.
- Dedicated Tor process with strict fingerprint-pinned US exit, isolated SOCKS 19050, HTTP CONNECT 19052 and ControlPort 19051; no TUN, Windows proxy or route-table modification by this module.
- Windows native HTTP client requests Google Flow through Tor's HTTP CONNECT port. HTTP 200 is considered an HTTP-ready route, NOT proof of authenticated Flow.
- HTTP 403 and 429 cause immediate rejection of the candidate; failed relays are recorded with time and response code to local `exit-health.log`.
- The UI shows progress, selected exit, errors and launches an isolated Chrome profile with the dedicated SOCKS proxy when ready.
- Stops only the dedicated Tor process when Flow is disabled or the app is destroyed.
- Farsi/English language-pack foundation included; other language packs may be added with BCP 47 codes.

## Evidence
- Delphi Win64 Release application compilation: passed.
- Standalone Delphi native test harness, no PowerShell in tested code path: passed.
- 1,015 live eligible US exit candidates discovered from SUMS cache and consensus, **no hardcoded addresses**.
- Native failover test: first three selected exits returned HTTP 403; the fourth, dynamically chosen exit, returned HTTP 200, resulting in status=ready.
- Stop after success: passed; dedicated test Tor terminated.
- `TFlowCatalogV3.FromCache` independent console test returned 1,015 candidates: passed.
- Dedicated loopback HTTP CONNECT and SOCKS ports tested. No TUN was started.
- App installer built with Inno Setup and manifest integrity validated after packaging.

## Remaining limitations: NOT release-accepted
- Authentication state and extension/patch integration in new isolated Chrome profile is not automatic; authenticated Google Flow dashboard and generation are NOT confirmed in this build.
- Full UI/UX visual acceptance, correct compact mode cards/icons, localized strings, RTL/LTR propagation still incomplete.
- Network mode switching is exclusive and **fails closed** if Proxy or TUN is active. Transactional automatic deactivation/rollback and restoring prior mode are NOT implemented yet.
- Multi-domain Google-only PAC policy is not integrated into the native controller. Chrome currently uses isolated Tor SOCKS for the entire dedicated profile.
- Relay health score/expiry over repeated use, periodic automated background checking, post-ready failover and retry caps are not finalized.
- No end-to-end Windows installer upgrade smoke test on the user's laptop yet.

Release classification: installable technical **PREVIEW**, not stable release.
