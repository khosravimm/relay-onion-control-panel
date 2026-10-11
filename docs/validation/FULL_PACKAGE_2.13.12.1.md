# Complete Tor 0.4.9.14 package — 2.13.12.1 preview

Win64 application built with Delphi 37.0. FileVersion is 2.13.12.1. Packaged Tor matches independently verified SHA-256 57d9f947e5e8f14cb141144b0ca81a5b3c582dd6237716802a86219423a88cfe. GeoIP resources match the verified Tor 0.4.9.14 archive. Transports remain from Expert Bundle 15.0.24. Optional sing-box included; outdated optional Win32 application excluded.

Cache unit and all 29 mock-control scenarios passed. The promotion test now accepts either normal automatic stream attachment before restriction or fail-closed rejection during activation; it continues to reject attachment to private probe circuits. This resolves a race in the test expectation without changing runtime behavior.

Real-control tests using the packaged Tor 0.4.9.14 passed: private listener isolation syntax, exact configuration restoration, bounded activation timeout and ongoing precheck while Tor has no built usable circuit. These offline tests do not qualify live connectivity.

The Tor standalone build report discloses 186/190 original upstream selected tests and 190/190 after Windows-only fixture adaptations. No production Tor source patch.

Visual Flow success and recovery of the laptop's intermittent GUARD_WAIT problem remain open. This is a prerelease; earlier 2.13.12.0 visual observations do not qualify this combined package.
