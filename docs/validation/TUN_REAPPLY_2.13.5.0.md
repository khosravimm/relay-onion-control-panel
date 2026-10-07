# Local TUN reapply repair — 2.13.5.0 (2026-10-07)

Owner request: repair TUN disconnects observed on PC-ICTO-002 with 2.13.3.0.
Baseline: v2.13.3.0. Isolated worktree branch fix/tun-reapply-2.13.5.
No public release or stable qualification is claimed.

## Evidence and change
Application log at %APPDATA%\Tcp\User\network\network-integration.log recorded automatic elevation blocks after successful config checks at 11:17:54 and 11:23:03. Apply stopped the running process before evaluating AllowElevation.
The patch stores the successfully applied config in memory. A running engine with identical config and matching mode is retained. Requests needing TUN elevation are rejected before stopping the engine, writing config or changing system proxy. Off and explicit changes retain their existing semantics. Dead engines cannot pass the no-op check.
Protected virtual runtime operations provide a fake process seam for regression tests without altering routes, proxy or UAC.

## Verification
- Win64 Release build: PASS. Existing EnvOptions.proj missing warning; no compiler error.
- Compiled Delphi regression test using the actual Apply implementation and fake runtime: PASS (E1).
- Cases: initial automatic start denied; explicit start; 20 identical automatic reapplies without stop/start/config check; changed config denied preserving live runtime and file; explicit change restarts once; off stops; dead runtime remains subject to approval.
- Inno Setup compile: PASS.
- Installation: PASS, installer log reports success without reboot.
- Installed FileVersion/ProductVersion: 2.13.5.0; installed executable SHA matches build.
- Desktop inspection: title Relay Onion Control Panel v2.13.5.0; TUN (LAN) button exposed as clickable.
- Real TUN operation under load and Speedtest stability have NOT been qualified. The exact automatic caller is not established by current logs.

## Local artifacts and rollback
Build and installer logs reside at the worktree root. Installer resides under release\installer\output. Runtime log remains in the user's AppData directory.
Installer SHA256: C56AEAB694B73D5477283FA1B2C50EF5A48D3FB7D325E83524860051D64573C4.
Rollback installer: original public-release worktree release\installer\output\RelayOnionControlPanel-2.13.3.0-TorExpertBundle-15.0.24-windows-x64-setup.exe.
Original executable and settings snapshot reside in local artifacts\rollback-20261007; do not commit these private operational files.