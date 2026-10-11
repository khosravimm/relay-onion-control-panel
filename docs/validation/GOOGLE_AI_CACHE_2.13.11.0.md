# Google AI cache and probe priority - 2.13.11.0 PREVIEW

Project machine PC-ICTO-002, 2026-10-11.

Cache schema 2 records relay fingerprint, actual verified US exit IP, Unix UTC last-success timestamp, Flow HTTPS response time including connection/TLS/body, success/failure counts and last pass/fail result. The latency is a 3:1 moving average for the same actual IP; a changed IP resets that latency measurement. Successful records from the last 24 hours are checked before older successes and failed/legacy hints; within each group faster response times are preferred. Entries older than seven days or malformed/future metadata are excluded. Maximum persisted entries: 100. Legacy fingerprint-only hints are migrated and retested. Cache writes use a temporary file and atomic Windows replacement. Every activation starts with an empty active pool and revalidates the cached exits; the cache never opens user listeners by itself. Three-IP readiness, ten-IP stop, US/Flow requirements, periodic health checks and exact OFF restoration are preserved. Tor continues selecting user circuits; this change prioritizes validation order.

The circuit-wait/Conflux fixes from the local 2.13.10.0 candidate are included. Native testing also exposed a preexisting parser issue: Tor's inline circuit-status key/value reply was being treated as a circuit ID; this is normalized and covered by a regression case.

Validation: Win64 build, cache unit checks (freshness, EWMA, round trip, legacy migration, failure demotion), twenty-one mock-control scenarios including cached-denied traffic remaining blocked and fast-first ordering, and real Tor control/restoration test passed.

Native initial run migrated ten legacy hints and reached readiness at 13:32:40. Immediate OFF/ON began with the measured fastest successes (2141, 2437 and 2438 ms), retested them and reopened listeners at 13:33:18. This earlier candidate exposed the inline-response bug; final validation uses the corrected executable below. No laptop access, account sign-in or generation claim. Local runtime cache and evidence are excluded from distribution.

Final executable SHA-256: 56beab3bf1ce7afa553ff7cea0a59ff3dc539ce541826f04f758148f7b1c0565.

Final native candidate was restarted with the existing cache. The first three probes matched the prior fastest entries: 138.197.124.121 (1735 ms), 23.128.248.173 (1813 ms) and 147.90.234.116 (1968 ms). All were freshly validated and user listeners reopened at 13:37:25. See cache-21311-final-before-start.json for the frozen expected order and google-ai-21311-route-control.json for route evidence.

Final native visual acceptance: forced reload rendered the public Flow page including its video/image gallery at 13:39 through the dedicated SOCKS browser. Screenshot: artifacts/visual-evidence/flow_21311.png. Discovery reached ten validated IPs at 13:38:27 and stopped. Fresh final installer install/uninstall passed; installed executable matched the final build. SHA-256 checksum is supplied in release/SHA256SUMS-ROCP-2.13.11.0-PREVIEW.txt. The candidate is local and has not been published.
