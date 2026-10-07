
## Browser regression and Windows proxy synchronization (2026-10-07)

The earlier successful IP checks did not establish browser compatibility. A later Chrome request failed with ERR_PROXY_CONNECTION_FAILED while the TUN engine and split routes remained active.

On the affected system, the top-level Windows Internet Settings reported ProxyEnable=0 and an empty ProxyServer, but DefaultConnectionSettings still had the manual-proxy flag set and pointed to 127.0.0.1:2080. TUN-only mode does not listen on that port. Updating only registry values and calling SETTINGS_CHANGED/REFRESH had not synchronized the native connection settings.

The source now uses INTERNET_OPTION_PER_CONNECTION_OPTION to synchronize the default connection's manual-proxy flag, server and bypass list before notifying clients. Existing PAC and autodetection flags remain intact. Restoration keeps its saved-state file until synchronization succeeds. This change has no machine-specific adapter, VPN, address or extension rules.

Validation:
- Release Win64 build passed.
- Native NetworkIntegrationProxySyncTest passed: enable, restore, PAC/autodetection preservation and snapshot cleanup.
- Existing route configuration and reapply tests passed.
- Real TUN lifecycle test passed all three cycles after rerunning it in a background process; no test TUN remains running on the build host.
- The affected laptop was repaired using the native Windows API. With TUN active, Chrome loaded Example Domain and a newly opened Wikipedia page. Fresh HTTPS requests returned HTTP 200. TUN stayed on the same engine process during verification.

The installed and published 2.13.7.0 binaries do not include this source change. The local repair restores current connectivity, but does not certify that the old package can safely repeat all proxy-mode transitions. A new package must include this change before that claim is made. No browser extension configuration was changed.