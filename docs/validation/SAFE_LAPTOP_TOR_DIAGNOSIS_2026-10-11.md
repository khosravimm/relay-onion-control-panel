# Safe-Laptop Tor connection diagnosis

User explicitly authorized Safe-Laptop access for this investigation, overriding the earlier laptop exclusion for this request. Host identity verified SAFE-LAPTOP. Running app: D:\Tor CP-2\TorControlPanel.exe, version shown by user 2.13.12.0; Tor 0.4.9.13. Profile: C:\Users\mahdi\AppData\Roaming\Tcp\User.

Observed bootstrap 100% with no usable general exit circuits; circuits repeatedly EXTENDED or GUARD_WAIT. Flow log timed out its initial seed wait at 14:31:19, before any new Flow scan. Runtime DisableNetwork=0, __LeaveStreamsUnattached=0, SOCKS 127.0.0.1:9050; ExitNodes={de}, StrictNodes=1. Several previous entry guards down/unusable; reachable smino appeared in GUARD_WAIT paths.

Bounded experiments, preserving originals in finally blocks:
- ConfluxEnabled=0 for 25 seconds: no usable circuit and Tor HTTPS probe timeout; restored auto.
- Clear EntryNodes for 25 seconds: GUARD_WAIT remained and probe timeout; restored complete original country list.
- Temporarily EntryNodes=$9C0952E6E80F51A2D37F2D3053B7B2D5E186EBB9 (reachable Tor-selected smino): multiple GENERAL/CONFLUX BUILT circuits and successful check.torproject.org/api/ip response IsTor=true, IP=185.220.101.97. Restored original list.
- After restoration: original settings verified, remaining BUILT=2/EXTENDED=11/GUARD_WAIT=1; fresh SOCKS HTTPS request timed out. Recovery not durable.

Conclusion: evidence isolates a guard selection/reachability problem in the current Tor session/profile. Germany-only exits were retained even during the successful test, so that exit restriction is not by itself sufficient to explain failure. Exact network cause of preferred guard failures remains unproven. Google AI seed timeout is a downstream symptom. No permanent configuration/file changes were applied. A safe follow-up should back up profile guard state and implement deliberate guard recovery plus distinguish bootstrap completion from usable circuit readiness. Do not automatically accept GUARD_WAIT as usable or persist a single diagnostic guard as a global product default.

Safe-Laptop Windows snapshot and PowerShell proxy tools returned Tool not found. run_command worked. No visual Flow success or full application fix is claimed on the laptop. Local unrelated lamp/precheck edits remain intact.

## Follow-up tests and precheck correction

Backup of on-disk state, torrc, flow-exits.ini and tor.exe created at D:\Tor-diagnostics\before-timeout-test-20261011-145339. This is a four-file snapshot, not a full live-profile backup.

Temporary LearnCircuitBuildTimeout=0 / CircuitBuildTimeout=60: no usable circuit after 35 seconds; SOCKS HTTPS connect timed out after eight seconds. Original LearnCircuitBuildTimeout=1 / CircuitBuildTimeout=0 restored. This bounded result does not exclude success after longer waiting.

Repeating the diagnostic entry guard override created multiple BUILT circuits and returned IsTor=true, IP=185.220.100.242. After restoring the original EntryNodes list, fresh HTTPS traffic timed out again. Temporary use of the same entry guard with three cached Google AI exit fingerprints returned IsTor=true, IP=23.128.248.173. A separate Chrome profile was launched with SOCKS localhost:9050 and the Flow URL. Computer Use stopped because it could not confidently determine the browser URL. The user subsequently confirmed successful browser opening; independent visual Flow-page evidence is still absent. All EntryNodes, ExitNodes={de}, and timeout settings were restored and queried successfully.

An additional two-second DisableNetwork cycle, followed by SIGNAL ACTIVE and an automatic circuit request, left circuits in GUARD_WAIT after 25 seconds; fresh SOCKS HTTPS timed out. DisableNetwork=0 restored. No persistent guard override, state deletion, or configuration save performed.

Local code correction: automatic preflight now remains pending beyond the two-minute explicit-activation timeout, slows automatic circuit requests to once per minute after that interval, and resumes validation once Tor returns a usable BUILT circuit. Promotion after a long background wait starts a fresh bounded activation deadline. GUARD_WAIT is diagnosed as waiting for entry guard selection and never accepted as usable. UI shows Waiting for Tor with the existing blinking amber lamp. Normal listeners and guard policy are preserved. Cancellation remains supported. This fixes premature termination of precheck, not Tor's underlying guard selection failure.

Validation: Win64 application and harness builds passed; 29 mock-control scenarios passed, including delayed GUARD_WAIT-to-BUILT readiness and late activation; real Tor 0.4.9.13 control test passed pending preflight and exact configuration restoration. Follow-up assertions reject probe construction before Tor marks the delayed circuit BUILT. Local executable SHA-256: f3fe6fabb089aebcadaae829348cbe637b6a107e015d11e4440f440fe04b2f36. This updated executable has not been deployed to the laptop or published.

Tor 0.4.9.14 remains untested: official Windows Expert Bundle 15.0.24 still contains 0.4.9.13, and no official Windows 0.4.9.14 binary was available in the upstream distribution listing inspected on 2026-10-11. Earlier source acquisition / cross-build prerequisites were unavailable. Do not claim the upstream fixes or this preflight change eliminate recurrence.
