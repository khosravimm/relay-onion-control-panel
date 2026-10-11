# Google AI circuit readiness fix - 2.13.10.0 PREVIEW

Host PC-ICTO-002; 2026-10-11. No laptop access.

Activation now accepts built, noninternal, exactly three-hop GENERAL, CONFLUX_LINKED and CONFLUX_UNLINKED paths. When no seed path exists, saved configuration is recorded, user listeners and old circuits are closed, US-only strict exit selection is applied and Tor is asked to select/build a normal circuit. Readiness is polled every 250 ms with a 120-second limit and a new build request every 15 seconds. UI shows Connecting... and a detailed elapsed-time tooltip. Cancellation interrupts the wait; OFF restores the exact saved configuration. The three-IP readiness threshold, ten-IP discovery stop and periodic health checks remain unchanged.

Win64 build passed. Eighteen mock-control cases passed, including delayed readiness, timeout, cancellation, rejecting a private controller-only seed, and both Conflux purposes. Actual Tor 0.4.9.13 timeout/restoration test passed.

Native visual test: initial activation opened listeners with three verified actual US IPs at 13:18:45. Immediate OFF then ON at 13:19:05 displayed Connecting..., requested a normal Tor-built circuit and started IP probing at 13:19:07. Readiness returned at 13:19:21 without Unavailable. Dedicated Chrome used SOCKS 127.0.0.1:19050 with remote DNS and QUIC disabled; public Flow rendered after the retry. Route evidence: artifacts/visual-evidence/google-ai-21310-route-control.json, Tor PID 13636. Account sign-in/generation and the laptop are not claimed as tested.

Executable SHA-256: ac8d14407cb8cc937e21d445bc85716a607be6b7b2842ca30e13977e758f9ff6.
