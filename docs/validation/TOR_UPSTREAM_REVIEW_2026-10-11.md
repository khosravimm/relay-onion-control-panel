# Tor upstream review — 2026-10-11

## Verified runtime and distribution

Local packaged tor.exe --version reports 0.4.9.13, git 3c575400909efe65, matching the earlier Safe-Laptop startup log. Installer uses Expert Bundle 15.0.24. Official download page currently lists daemon stable 0.4.9.14 but Windows Expert Bundle stable 15.0.24 containing 0.4.9.13. Its listed alpha bundle 16.0a13 also contains 0.4.9.13. Thus we use the latest listed official Windows bundle, but not the latest daemon release.

Sources:
- https://download.torproject.org/tor/
- https://dist.torproject.org/torbrowser/
- https://forum.torproject.org/t/security-release-0-4-9-14/22241
- https://gitlab.com/torproject/tor/-/raw/tor-0.4.9.14/ReleaseNotes

## Relevant fixes reviewed

- 0.4.9.14 (2026-10-07), #41420: abandoned circuit timeout measurements can prevent adaptation and cause connectivity failure; fixes first-hop accounting and timeout-history recovery. Not present in our 0.4.9.13.
- 0.4.9.14, #41412: cancelling a circuit before its first hop completes could stop reuse of a working guard channel and abort unrelated directory requests; fixes recovery timing. Not present in our binary.
- 0.4.9.13, #41360/#41365/#41366: record guard failure on failed outgoing connection establishment rather than unrelated circuit/stream/directory/channel failures. Already included.
- 0.4.9.12, #41325: synchronize stream isolation across linked Conflux legs; #41358 prevents incorrect descriptor unusability. Already included.
- 0.4.9.10, #41280: correct guard expiry timing. Already included.
- 0.4.8.9, #40876: limit additional primary guard use under temporary restrictions, including Conflux. Already included; this historical fix is not a reason to disable guards.

Official announcements:
- https://lists.torproject.org/mailman3/hyperkitty/list/tor-announce@lists.torproject.org/thread/DUAL7UXFOHTWB3DV4Y45Q62W36HTAOWA/
- https://lists.torproject.org/mailman3/hyperkitty/list/tor-announce@lists.torproject.org/thread/I5AZQIOUBZRQVF75PRUXKWHLKX7X6WLL/
- https://forum.torproject.org/t/security-release-0-4-9-12/22096
- https://archive.torproject.org/websites/lists.torproject.org/pipermail/tor-announce/2023-November/000297.html

## Assessment and next implementation order

The two latest fixes are plausible matches to the laptop's EXTENDED/GUARD_WAIT/timeouts and its successful temporary guard-specific diagnostic. They do not prove either bug caused this incident. That diagnostic establishes guard selection/channel sensitivity, not necessarily a corrupt profile or purely unreachable guards.

Prioritize testing 0.4.9.14 against the unchanged backed-up laptop profile, before resetting its guard state. Obtain a verified compatible Windows build from official bundle publication or a reproducible build from official tagged source. The source archive is not a Windows executable. Do not relabel the existing 15.0.24 bundle as containing 0.4.9.14, or substitute an unverified third-party executable.

Application follow-up remains warranted: distinguish bootstrap percentage from usable exit-circuit readiness and bounded retry of precheck after Tor recovers; do not treat GUARD_WAIT as BUILT, persist a diagnostic guard, or automatically erase guard state.

No runtime upgrade, laptop configuration changes, or code edits were made by this research task. Direct GitLab Tor-host pages were unavailable; the project mirror's tagged ReleaseNotes and official mailing-list announcements were readable. Direct source archive download failed; no archive was executed or used as a build input. Windows bundle availability is a point-in-time check, not a promise that no newer bundle will appear later.
