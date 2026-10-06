# Network Integration TUN Restore UAC Qualification - 2.13.2.0

- Version: 2.13.2.0
- Change: TUN is not automatically restored after scanner/ping suspension, preventing repeated Windows elevation prompts.
- Proxy mode: automatic restore remains enabled.
- TUN mode: scanner suspension disables TUN; user must explicitly click TUN (LAN) to re-enable it.
- Build: PASS
- Installer: pending in release build step