# Google AI status lamp

The native Google AI button contains a DPI-scaled circular image beside the G. The existing 500 ms UI timer alternates amber and grey for pending states 1 and 4; ready state 5 and active state 2 show steady green. Off and unavailable states show grey. The separate status label and detailed tooltip remain authoritative: Ready (Off) means precheck readiness, not an enabled restriction or configured browser proxy.

Win64 Release build and git diff whitespace check passed. Local native visual review confirmed the caption fits, the off lamp is grey, and the pending lamp alternates grey/amber without moving the caption. Live readiness and activation both showed steady green: Ready (Off), then 10 IPs | done with a US flag.

This UI follow-up changes the locally built executable after the earlier 2.13.12 installer validation. The existing installer and its checksums remain the earlier precheck candidate; they have not been replaced or published by this UI task.

A fresh isolated Chrome profile using SOCKS 127.0.0.1:19060 visually opened https://flow.google.com/about through the active pool. Public Flow landing content rendered on this computer; login and generation were not exercised.
