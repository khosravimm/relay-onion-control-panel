# Release Package Qualification — Relay Onion Control Panel 2.12.0.0

## Result

**PASS — qualified for stable binary GitHub Release**, with the explicit limitations listed below.

## Scope

Relay Onion Control Panel 2.12.0.0, derived from `abysshint/tor-control-panel`, packaged with Tor Expert Bundle 15.0.24 / Tor 0.4.9.13.

## Build qualification

- RAD Studio / Delphi 13.2, BDS 37.0.
- Win64 Release build: PASS.
  - FileVersion/ProductVersion: `2.12.0.0`
  - ProductName: `Relay Onion Control Panel`
  - SHA-256: `b85cfc8e48a871a23a18c21094c1fc8f0c7ca23eb68302cbb36f24735fce371e`
- Win32 optional Release build: PASS.
  - FileVersion: `2.12.0.0`
  - SHA-256: `331b5c78ee6e05ce6756a6902930a9d8944b89f0b5086829ae2be2aa49e2132a`
- Machine Interface policy test: PASS on Win64 and Win32.

## Package controls

- Package manifest: 73 entries, 0 bad hashes.
- Portable ZIP expanded and independently re-verified: PASS, 73/73.
- Operational `Data/User` excluded.
- Template `Data/User.template` included.
- Obsolete `snowflake-client.exe` and `webtunnel-client.exe` absent.
- Tor runtime: `0.4.9.13`.
- Tor runtime SHA-256: `90bbdcafd586feea608a5e9b7d3959f4ee194f7770755cfde8fab240e9773ad1`, identical to the qualified 2.11 runtime baseline.
- Artifact text secret/private-key scan: 0 findings.

## Installer qualification

Inno Setup 6.7.3 compile: PASS.

Fresh silent install/uninstall:
- install exit: 0
- installed product version: `2.12.0.0`
- product name: `Relay Onion Control Panel`
- Tor version: `0.4.9.13`
- `DescriptorMode=0`
- REST/MCP listener count on default ports 19090/19091 during a real application run: 0
- uninstall exit: 0

Migration install/uninstall:
- install exit: 0
- pre-existing settings marker preserved: PASS
- pre-existing `DescriptorMode=1` preserved: PASS
- obsolete snowflake client removed: PASS
- obsolete webtunnel client removed: PASS
- uninstall exit: 0

## REST requalification

Using an isolated qualification profile and loopback test port:
- local REST listener: PASS
- `GET /api/v1/version`: product `Relay Onion Control Panel`, version `2.12.0.0`
- `GET /api/v1/status`: PASS
- `GET /api/v1/health`: PASS
- `POST /api/v1/status`: HTTP 405 fail-closed

Result: PASS for the previously qualified local read-only REST scope.

## MCP requalification

Using an isolated qualification profile and loopback test port:
- MCP protocol `2026-07-28`: PASS
- exact tool set: `tcp_version`, `tcp_status`, `tcp_health`
- tool count: 3
- write-like tool count: 0
- all positive discover/list/call requests: HTTP 200
- missing `Mcp-Method`: HTTP 400 / `-32020`
- missing `Mcp-Name`: HTTP 400 / `-32020`
- missing required `_meta`: HTTP 400 / `-32602`
- `tcp_version` reports `2.12.0.0`
- non-loopback failure injection (`0.0.0.0`, `AllowRemote=0`): process stays alive, listener count 0

Result: PASS for the previously qualified local read-only MCP scope.

## Frozen release assets

Portable ZIP:
- `RelayOnionControlPanel-2.12.0.0-TorExpertBundle-15.0.24-windows-x64-portable-offline.zip`
- SHA-256: `85a6047512811cf629c5799cf6ef8cb1df2c7c52e41e25b73b912f671e966bf7`

Installer:
- `RelayOnionControlPanel-2.12.0.0-TorExpertBundle-15.0.24-windows-x64-setup.exe`
- SHA-256: `609edb02bbab537f8b6e02fb2f538261f082549cf2daa60eed6f1375e82b7654`

Checksum file:
- `SHA256SUMS-ROCP-2.12.0.0.txt`
- SHA-256: `aff7047941ef3b3eb21a20a49a55307400cd9c051332a4af56d48ed2cafb59cd`

## Explicit limitations

- Main executable and installer are currently **not Authenticode signed**.
- Remote REST/MCP remains outside the qualified scope.
- State-changing/write MCP tools are not provided or qualified.
- GUI-host stdio MCP is not claimed as production-qualified.
- Direct Tor route recovery is not guaranteed for every network; existing Descriptor Mode and bridge/fallback claim boundaries remain.
- Relay Onion Control Panel is independent and is not endorsed, sponsored by, or affiliated with The Tor Project.

## Publication gate

Stable release publication is authorized only after the three frozen assets above are uploaded under tag `v2.12.0.0-tor-15.0.24` and the downloaded GitHub assets are re-hashed against these frozen values.
