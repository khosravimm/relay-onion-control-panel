# Flow v3.0.0.0 — installation and test evidence (preview)

Date: 2026-10-09
Canonical baseline: 2.13.8.0, repository E:\Projects\third-party\relay-onion-control-panel-tunfix, baseline commit 96eac73.

## Implemented
- Delphi Win64 application version 3.0.0.0 built with RAD Studio 37.0.
- Flow mode button added alongside existing TUN and Proxy toggles. Three modes have matching original-inspired vector symbols (connected squares, branching graph and globe) and status indicator.
- Proxy and TUN button callbacks refuse activation during a Flow-requested session.
- Enabling Flow attempts to disable ordinary Proxy/TUN, then launches an isolated Tor client via tools/Flow-V3.ps1. The dedicated SOCKS listener is 127.0.0.1:19050, distinct from Tor's ordinary SOCKS 9050.
- Tor configured with ExitNodes {us} and StrictNodes 1; HTTP flow.google.com connectivity is validated before the route is declared ready.
- GoogleOnly proxy scope via a browser PAC rule and all-proxied scope via a SOCKS browser proxy (command-line helper). Chrome is launched with its own profile; user's main browser profile is not changed.
- Prototype BCP-47 localization unit LocalizationV3.pas (UTF-8 packs for fa-IR, en-US) is compiled; legacy translations remain unaffected.
- Inno Setup 6 can produce a distributable installer.

## Verified
- RAD Studio 37.0 Win64 Release compile: PASS.
- Flow PowerShell script parser: PASS.
- Isolated US-only Tor startup and Google Flow HTTP 200 on SUMS with -NoBrowser: PASS.
- Flow Stop: PASS; dedicated test Tor process removed. No TUN or Windows system proxy mutation in the Flow helper.
- Installer compiled using ISCC: PASS.
- File metadata: 3.0.0.0.
- Note: initial PowerShell script had a stop-argument issue, fixed and retested before final packaging.

## Outstanding — no release acceptance claim
- Browser authentication + third-party extension enabling: not automated. Installing an extension in the dedicated browser profile is currently a user preparation requirement.
- Actual authenticated Google Flow dashboard and generation: NOT VERIFIED in v3 on SUMS. HTTP 200 does not prove the application works.
- Exact exit relay fingerprint pinning, expiry, health queue, failover: NOT IMPLEMENTED (country-only exit restriction is implemented).
- Flow mode scope change from Delphi UI: NOT IMPLEMENTED. The helper has -Scope GoogleOnly|All but main button uses default GoogleOnly.
- Fully transactional and verified mode rollback/restoration: NOT IMPLEMENTED. On an activation failure ordinary network settings may not automatically restore.
- Complete Farsi/English UI strings, direction switching and future language pack workflows: localization foundation compiled, not migrated across all legacy controls.
- Approved mockup-sized mode cards and full v3 user interface: small VCL button icons implemented, not the full card layout.
- Installer installation/upgrade on isolated Windows test environment and click-by-click visual UI tests: pending.

Release classification: 3.0.0.0 **INSTALLABLE PREVIEW**, not final or release-accepted.
No telemetry is added. No live TUN test was performed.
