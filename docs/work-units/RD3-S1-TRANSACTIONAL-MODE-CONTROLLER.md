# RD3-S1 — Transactional mode controller progress

**Authority:** [RD-3](../RD-3.md) · **Date:** 2026-10-09  
**Status:** IN PROGRESS / NOT ACCEPTED  
**Requirement:** REQ-001, REQ-012 · **Acceptance:** AT-02, AT-11, AT-12

## Changes applied

- Created `source/RD3ModeController.pas`: explicit Off/Flow/TUN/Proxy mode states; phases; guarded transition; transaction tokens; verified Commit; Rollback and conservative crash-recovery placeholder.
- Created standalone executable test `tools/RD3ModeControllerTests.dpr` and repeatable build script `tools/Build-RD3ModeTests.cmd`.
- Wired the transaction controller into the Delphi Flow button entry point (`source/Main.pas`): BeginTransition before starting the Flow engine, Commit after the engine reports HTTP-ready, Rollback on startup failure or user cancellation. Stops continue to shut down only the dedicated Flow engine.
- Build of the full Delphi Win64 Release application succeeded after integration.

## Actual evidence

- Standalone test command: `cmd /d /c tools\Build-RD3ModeTests.cmd`, then `tools\RD3ModeControllerTests.exe`.
- Output: `PASS: RD3-S1; 100 transitions; overlap, rollback, wrong token and crash fail-closed`; exit code 0.
- Main application Win64 Release build succeeded, RAD Studio 37.0.
- Tests are **state-machine unit tests**, not live operating-system network transition tests.

## Gaps blocking S1 acceptance

1. Proxy and TUN toggle handlers still directly mutate legacy flags and call `ApplyNetworkIntegrationDesired`; these handlers have **not** yet been migrated to the shared transactional controller.
2. The state machine currently has no persistent, hash-verified snapshot of the actual Windows proxy, routes, TUN and owner-managed processes; successful unit rollback only restores logical state.
3. Mode switching Flow←Proxy/TUN currently refuses to proceed until the operator has manually stopped conflicting modes. Transactional automatic mode transition has not been implemented.
4. Crash recovery deliberately fails closed and requires an external reconciliation adapter; no verified external restore exists yet.
5. Tests AT-02, AT-11 and AT-12 require real lab-machine failure injection, leak checks and UI acceptance before completion.
6. The Flow engine status `ready` means HTTP 200 only. It is not evidence of authenticated Google Flow functionality (RD3-S4 / AT-01,10).

## Next authorized tasks

- Build network-state snapshot adapter with explicit owner-controlled rollback scope.
- Refactor Proxy and TUN activation through central coordinator, preserving Safe-Laptop connectivity.
- Test 100 real mode transitions + forced failure scenarios in an isolated environment; generate screenshot/click and packet-route evidence.
- Do **not** publish an accepted installer until the relevant RD-3 gates pass.

## Iteration 2 — privileged boundary guard (2026-10-09)

- `source/NetworkIntegration.pas`: `Apply` now rejects `SystemProxyEnabled=True` and `TunEnabled=True` before constructing configuration, stopping processes, or changing Windows registry/routes. This closes a bypass route where external callers could ignore UI exclusivity.
- `tools/RD3NetworkExclusivityTests.dpr` / `tools/Build-RD3NetworkExclusivityTests.cmd`: compiled Win64 test against the actual manager. **PASS**: simultaneous Proxy/TUN rejected, manager remained inactive, test exit 0; isolated temp test directory only. No live TUN activation.
- Full Delphi Win64 Release application build: **PASS**. `RD3ModeControllerTests.exe` 100 transition state-machine test: **PASS**.
- Still unaccepted: switching Proxy/TUN through transactional Begin/Commit/Rollback; persistent OS/network snapshot, restoration, TUN behavior and click/visual validation.

## Iteration 3 — Proxy/TUN UI transaction integration (2026-10-09)

- Main.pas Proxy/TUN button callbacks now call `FRD3Mode.BeginTransition` before mutating legacy flags, refuse a second click while a transition is pending, and retain a transaction token and target.
- `UpdateNetworkIntegrationControls` now commits pending Proxy/TUN transactions **only** after the `TNetworkIntegrationManager` reports the requested active mode, or reports both inactive for Off. An adapter error rolls back the **logical** transaction token, not yet the underlying Windows settings.
- Application Win64 Release build: PASS. 100 unit transition cycles: PASS. Real manager simultaneous Proxy+TUN rejection: PASS. No live Windows TUN was started by these tests.
- **Unresolved high priority:** persistent OS/network snapshot; actual rollback of failed adapter state; startup reconciliation from existing active TUN/Proxy; pending-transition watchdog / timeout; unexpected crash recovery; TUN/Proxy real transition tests; UI click and DPI acceptance. Since legacy flags can be saved before successful application, the mode coordinator is still **NOT ACCEPTED**.
- No installer or GitHub release has been produced from these changes.

## Binding owner scope correction (2026-10-09)
The owner explicitly rejected Windows-wide snapshots and restoration as unnecessary. Flow must use a dedicated application-managed profile with Load / Activate / Unload and recovery confined to its own processes, data and connections. Previous OS snapshot/route/VPN rollback tasks are cancelled. S1 acceptance now assesses owned-resource cleanup, profile switching, isolation and crash recovery. No Flow profile operation may modify third-party network settings.


## Iteration 4 — Flow-owned profile lifecycle (2026-10-09)

**Scope restricted by owner:** Flow resources inside Relay Onion Control Panel only. No Windows-wide snapshot/route/VPN or third-party process management.

- `source/FlowNativeV3.pas`: dedicated Tor child is tracked by its **own process handle**, rather than reopening a PID that might have been recycled. Stop uses the owned handle; an already finished worker can be released on a subsequent Start. Empty candidate list fails closed without starting Tor.
- `tools/RD3FlowLifecycleTests.dpr`: 100 repeated empty-profile load-reject/unload cycles: **PASS**, no child process created. Main Win64 build: **PASS**; RD3 state machine 100-transition tests: **PASS**.
- These tests exercise failure lifecycle and management logic, not Chrome/Google login, extension operation, successful repeated live Tor cycling or UI acceptance. S1/S4/S5 are still open.
