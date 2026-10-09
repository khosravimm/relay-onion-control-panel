# RD-3 Flow profile + existing Proxy — 3.0.0.6 test candidate

Date: 2026-10-09. Owner scope: app-owned Flow profile, existing Tor runtime, existing system Proxy, NO browser or extension runtime.

## Changes
- Flow no longer refuses to start when the app is currently in Proxy/TUN mode. It records application-owned Proxy/TUN and SOCKS state and previous ExitNodes, then switches to existing program proxy. No second Tor process is started by the Flow button.
- Relay selection loads `[Routers] ExitNodes` from the dedicated Flow.ini and uses `{us}` only for a cold profile; selected valid exits are stored by earlier HTTP-200 discovery code in this Flow profile.
- On Flow Off, previous ExitNodes and saved application mode flags/SOCKS preference are restored. TUN elevation remains owner-confirmed and cannot be silently repeated.
- Proxy and TUN lamps are hidden as active while Flow owns the proxy mode. Chrome and Bypasser are NOT launched.

## Evidence and limitations
- Delphi Win64 app build PASS; 100 state-machine tests PASS; proxy/TUN exclusivity PASS; profile selection PASS; 100 empty-profile lifecycle iterations PASS.
- **This is a test candidate, not an accepted functional release.** No interactive live Flow on/off with system Proxy/TUN and no HTTP-200 verification in the new shared-Tor path have yet been executed. The former dedicated HTTP probe is not called by this UI path. Flow Ready currently means app Proxy active, NOT Google Flow verified.
- TUN restoration may require explicit elevation approval. A failed handoff and crash restore require further work. The old `LaunchFlowAction` code still exists but is no longer called.
