# Relay Onion Control Panel 2.13.12.1 — test preview

Complete Windows x64 application package with independently built Tor 0.4.9.14. Includes the Google AI cache, background precheck, three-IP readiness threshold, ten-IP discovery cap and status lamp from the 2.13.12.0 preview, plus pending-Tor recovery diagnostics in the current source.

Tor is built from verified upstream sources; OpenSSL 3.5.8, Libevent 2.1.13 and zlib 1.3.2 are statically linked. This is not an official Tor Expert Bundle release. Pluggable transports remain from Expert Bundle 15.0.24; sing-box and other application resources remain included. GeoIP files are from Tor 0.4.9.14.

Use the installer for a normal installation, or extract the portable ZIP and run TorControlPanel.exe. Back up the current application and user profile before upgrading. User exit caches, bridge settings, credentials and operational Tor state are excluded from the package.

Build and automated control checks cover the new Tor runtime. Laptop bootstrap recovery and visual Flow access with this combined package remain open; this preview does not claim that the intermittent laptop connection problem is fixed. Existing visual qualification of earlier packages does not qualify this package.

Both binary packages are unsigned. Full Tor source/build/test provenance is included under docs. Test-only Windows socket fixture adaptations and original upstream test failures are disclosed in BUILD_REPORT.md.
