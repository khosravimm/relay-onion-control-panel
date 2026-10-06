# Network Integration TUN Elevation Guard 2.13.3.0

Result: PASS

Change:
- TUN elevation/UAC is allowed only for direct user clicks on the TUN (LAN) button.
- Automatic reapply/recovery paths call NetworkIntegration.Apply with AllowElevation=False.
- Automatic TUN elevation attempts fail closed with a clear message instead of opening repeated UAC prompts.

Rationale:
- Speedtest and other high-traffic/network-change scenarios can trigger reapply/recovery paths.
- Those paths must not repeatedly invoke ShellExecuteEx(runas).
