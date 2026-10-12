# Relay Onion Control Panel 2.13.12.3 — release evidence

- Windows x64 Delphi Release compilation: PASS (2026-10-12).
- Installer build (Inno Setup 6): PASS.
- FileVersion / ProductVersion: 2.13.12.3.
- Package manifest: 100 files validated, zero mismatches.
- SHA256 binary: 4e6656e996bb628cf78907aaebbc12fb282dc57d68e5fbe58e04e740a9189033.
- SHA256 installer: 63AA91468E5129C5A29EF1C246A8B13424A2DAC521B599217E42B0014C9C2A71.
- Flow UI status mapping: grey off, amber activating, blue scanning, cyan ready-off, green active (only after user listener ready), red error, orange precheck retry.
- Safe-Laptop prior build 2.13.12.2: Tor SOCKS successful, Google Flow HTTP 200 through restricted US pool; toggle off restored normal configuration. New 2.13.12.3 requires a fresh device-level acceptance test.
- NetworkIntegrationProxySyncTest and NetworkIntegrationReapplyTest: PASS. RouteConfigTest and TunLifecycleTest are fixture-driven; invoked without fixtures and returned usage errors, not feature test outcomes.
- File not digitally signed. Previous 2.13.12.1 detection submitted for Microsoft review as ce33f63d-c89d-459f-8581-88f5a14b3681. New binary detection status not independently confirmed on Safe-Laptop.
- Security: preserve Defender protection, do not create exclusions without independent vetting.
