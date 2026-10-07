# TUN startup and repeated notifications, 2.13.7.0

Date: 2026-10-07. Windows x64, sing-box 1.14.2.

## Observed failure

Safe-Laptop was running 2.13.6.0. Its generated split IPv4 routes were correct, but sing-box exited approximately 15 seconds after launch with: configure tun interface: The system cannot find the file specified. The Windows device setup log showed repeated invalid-device-node removal attempts for the old fixed interface identity. A synthetic config using a fresh interface name started successfully on the same machine; ordinary no-proxy HTTPS then returned a Tor exit IP.

The controller considered the process active after only 700 ms. When it subsequently exited, Tor CIRC CLOSED events called ApplyNetworkIntegrationDesired repeatedly. Each automatic restart was denied by the explicit-elevation guard and showed the same notification again.

## Correction

- A fresh RelayOnion-prefixed identity is generated per explicit engine startup. Identical reapply preserves the existing identity and process. No unrelated Windows adapter or driver is removed.
- TUN startup waits up to 20 seconds for the named adapter to be operational and both IPv4 /1 routes to appear on that adapter, using Windows IP Helper APIs. A running process alone does not establish readiness.
- A failed TUN is not retried by automatic circuit events; its first failure remains visible. A direct user click on the error-state TUN button initiates a new attempt.
- sing-box warnings/errors are written to network/sing-box-runtime.log; startup errors include the exit code or readiness timeout.
- Version metadata and installer definition: 2.13.7.0.

## Validation before publication

- Win64 Release build: PASS.
- All four generated configurations accepted by the pinned sing-box 1.14.2: PASS.
- Fake-manager regression: explicit startup/restart, new interface identity, unchanged reapply, denial before mutation and stop: PASS.
- Native manager lifecycle test against real sing-box: three starts with distinct identities, 20 unchanged automatic reapplies per start, and explicit stop: PASS. Each start passed native adapter/route readiness. No engine or RelayOnion routes remained after completion.
- Safe-Laptop diagnostic: the old name reproduced the delayed fatal error; a fresh name ran successfully and ordinary no-proxy traffic exited through Tor. The diagnostic engine was stopped afterward.

The full 2.13.7.0 GUI package was not yet installed on Safe-Laptop at the time of this report. This is a test candidate; existing IPv6 and VPN compatibility boundaries from 2.13.6.0 apply.
## Safe-Laptop installed GUI validation (after publication)

The published 2.13.7.0 installer was downloaded and its SHA-256 compared with the frozen asset using .NET SHA256. Configuration files were backed up locally and their hashes verified. Installation into the existing directory returned exit 0 and required no Windows restart; FileVersion/ProductVersion are 2.13.7.0.

Tor reached 100% bootstrap. An explicit UI TUN click started sing-box PID 4512 and created RelayOnion-1BFF546F with both IPv4 /1 routes. The UI showed TUN active and United States. Ordinary no-proxy HTTPS and explicit local Tor SOCKS requests both returned 147.90.234.63, exit 0. Windows selected this TUN for destinations in both IPv4 halves.

At 13:51:20 local time, more than 100 seconds after startup, the same engine PID and routes remained active. The integration log showed unchanged reapply preserving PID 4512; no automatic-elevation denial appeared in this test interval. The runtime warning/error log was empty. This verifies the installed GUI with the current VPN; it is not a claim of compatibility with every VPN. TUN was left running after validation.