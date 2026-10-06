# Work Unit Ledger — 2026-10-06 — SUMS

Canonical development path:

`E:\Projects\third-party\relay-onion-control-panel-public-release`

## WU-NI-2026-10-06 — Network Integration UI and runtime

Scope:
- Add two compact controls to the main compact UI: System Proxy and TUN.
- Display desired switch state and runtime status beside each control.
- Start/stop `sing-box.exe` as the Windows network integration engine.
- Use the existing Tor SOCKS listener as the upstream proxy.
- Restore stale Windows proxy state on next startup.

Owned files:
- `source/Main.pas`
- `source/NetworkIntegration.pas`
- `source/TorControlPanel.dpr`
- `source/TorControlPanel.dproj`

Status:
- Implemented on SUMS.
- Delphi Win64 build PASS with RAD Studio path `F:\Software\Embarcadero\Studio\37.0\bin\rsvars.bat`.
- Runtime elevated TUN test is still pending.

## WU-SBPKG-2026-10-06 — sing-box runtime packaging

Scope:
- Do not commit upstream `sing-box.exe` binary to source control.
- Fetch a pinned sing-box release during release preparation.
- Verify SHA-256 before placing runtime files in the release tree.
- Include GPL license and version metadata in the package.

Owned files:
- `tools/Fetch-SingBox.ps1`
- `docs/BUILD_INSTRUCTIONS.md`
- `docs/BUILD_INSTRUCTIONS_FA.md`

Status:
- `sing-box` 1.14.2 fetch/hash/version verification PASS.
- `sing-box check` PASS for `proxy-only.json` and `proxy-tun.json`.
- Release tree runtime is generated under ignored `release/.../optional/sing-box`.

## WU-BUILD-BASELINE-2026-10-06 — Build reproducibility repair

Scope:
- Make the public-release repo buildable on SUMS.
- Treat MCPConnect as optional so its absence does not block the core executable build.
- Restore required icon resource availability.

Owned files:
- `source/TcpMcp.pas`
- `.gitignore`
- `source/TorControlPanel.icons.res`

Status:
- `MCPConnect` dependency is now optional behind `TCP_ENABLE_MCP_CONNECT`.
- `TorControlPanel.icons.res` restored from canonical sibling source and unignored.
- Baseline and Network Integration build PASS.

## Remaining gates

- Visual compact UI smoke test.
- Runtime System Proxy test.
- Runtime TUN test with elevation and rollback verification.
- Installer build remains pending until `ISCC.exe` is available on SUMS or its path is provided.