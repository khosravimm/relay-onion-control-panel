# RD-3 — 3.0.0.5 test-preview validation

Date: 2026-10-09
Status: **PREVIEW, NOT RD-3 ACCEPTED**
Owner scope: application-managed Flow profile only. No Windows-wide snapshots or external-process control.

## New changes
- Bundled exact **AI Flow Bypasser v1.0.0** CRX extracted into project resources; CRX SHA-256 `AFE66509464A67B43B731AB400CE90A69F8DC65D7ED570C569063595C2900908` was checked against the user's existing D:\Code\extension-audit copy.
- Native Delphi `FlowBrowserV3.pas` locates Chrome and supports discovery of the extension from current user profiles as fallback.
- Flow launch prefers verified bundled extension files and passes isolated Chrome profile and extension load flags. No changes to the original user Chrome profile.
- `FlowNativeV3.Stop` has a second owned-child cleanup after worker join for process-spawn race.
- Normal Flow exit discovery, HTTP verification, dynamic startup failover remain present.

## Evidence
- Win64 Delphi app Build: PASS.
- RD3 state machine: 100 transitions PASS.
- Proxy+TUN exclusivity: PASS.
- Flow empty candidate load/unload: 100 cycles PASS.
- Inno Setup 6: successful installable preview build.
- Bundle manifest 104 files: 0 mismatches.
- Installer SHA256: `E48106A6209F55F2D1A0407CEF1C23A529A3C723464231E9932960011E7A72D3`.

## Important outstanding test blockers
1. The target laptop's Chrome test with a new temporary profile displayed **Profile error occurred**. The extension actually loading in the managed profile is **not verified**; modern Chrome builds may ignore command-line extension loading flags.
2. Authenticated dashboard and real Google Flow operations remain unverified. HTTP 200 is insufficient.
3. UI design acceptance, whole-app fa-IR/en-US localization, Google-only routing and failover after initial success are still pending.
4. This preview must not be reported as RD-3 complete, even if the installer installs.

## User test checklist
- Install over the preview using ordinary Windows installer.
- With app Proxy and TUN off, activate Flow.
- Observe mode indicator, Tor exit selection, dedicated Chrome profile launch.
- Inspect `chrome://extensions` within the Flow Chrome profile and verify AI Flow Bypasser enabled (not merely files present).
- Attempt Google login and opening the actual Flow project/dashboard; record the page and app UI screenshot.
- Turn Flow off and check the project-owned Tor process exits; do not touch other Tor sessions.
