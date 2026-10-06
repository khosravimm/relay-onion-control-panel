# Network Integration Installer E2E Validation — 2.13.0.0

Date: 2026-10-06
Project: Relay Onion Control Panel
Version: 2.13.0.0
Tor Expert Bundle: 15.0.24
Network engine: sing-box 1.14.2

## Scope

This release adds mutually exclusive network integration modes:

- Proxy
- TUN (LAN)
- Off

Proxy and TUN are intentionally mutually exclusive. Enabling one disables the other.

## Build Evidence

- Delphi Win64 build: PASS
- Binary file version: 2.13.0.0
- Binary product version: 2.13.0.0
- Inno Setup installer build: PASS
- Installer file version: 2.13.0.0
- Installer product version: 2.13.0.0

## Runtime Validation Summary

Previously validated during the same governed work unit:

- sing-box config check for proxy-only mode: PASS
- sing-box config check for TUN mode: PASS
- System proxy ON/OFF and registry rollback: PASS
- TUN adapter/route creation and cleanup: PASS
- Installer silent install/smoke/uninstall flow: PASS on prior package path; version bump package rebuilt after MCP/API update.

## Machine Interface / MCP Update

The REST and MCP status surfaces now include `network_integration` state:

- mode: `off`, `proxy`, or `tun`
- system_proxy.enabled
- system_proxy.state
- tun.enabled
- tun.state

MCP adds read-only tool:

- `tcp_network`

Write/control actions through MCP remain intentionally out of scope for this release because Proxy/TUN changes affect local network routing and require explicit approval/gating design.

## Release Artifact

Installer:

`RelayOnionControlPanel-2.13.0.0-TorExpertBundle-15.0.24-windows-x64-setup.exe`

SHA-256:

`743BCA99E0D951E27E431B76C183F1E7C16371789B269F34040A8E6904A561C3`
