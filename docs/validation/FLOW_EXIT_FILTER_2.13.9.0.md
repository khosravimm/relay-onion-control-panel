# Flow US exit filter — 2.13.9.0 PREVIEW

Date: 2026-10-11. Host: PC-ICTO-002. Final-build browser visual gate: PASS at 10:23-10:24 local time.

## Baseline and behavior

Baseline: v2.13.8 commit 96eac73e12884cd8b8af24084180e089a8152132; branch codex/flow-exit-filter-2.13.8. Source changes remain uncommitted and are identified by SOURCE-STATE.txt in the package.

Connect Tor, wait for a built three-hop public circuit, then enable Flow US. Activation captures exit selection, strictness, listeners, DisableNetwork and stream-attachment settings; closes old circuits and user listeners; and checks cached candidates first. Every candidate needs current consensus, Exit/Running/Valid flags, no BadExit, US GeoIP and a fresh HTTPS check. Cache entries are hints, never proof.

Private controller circuits preserve the guard and middle from a Tor-built public circuit. Paths reject duplicate relays, common IPv4 /16 or advertised IPv6 /32, declared families and common family IDs. Missing microdescriptors reject a candidate. A dedicated SessionGroup attaches private HTTP CONNECT probes only to their candidate circuit. User streams use automatic Tor selection under the strict validated pool. Quoted SOCKS usernames cannot spoof routing metadata. Router failure blocks user traffic.

The actual HTTPS egress check requires IsTor and a US IP. The canonical Flow URL is https://flow.google.com/. Acceptance requires HTTP 200, expected Flow markers, no recognized denial, and two private stream attachments. TLS certificate validation remains enabled; redirects are rejected.

After five distinct actual valid IPs, original user listeners reopen immediately. Remaining discovery continues on private circuits in the same Tor process. Healthy user circuits survive background probes. Automatic GENERAL/CONFLUX circuits outside the validated pool, including unfinished paths, are closed before reopening. The active pool is capped at ten members; additional successes are cached for future sessions. Members are rechecked after five minutes. Fewer than five valid members closes user listeners before changing the exit pool. Scan exhaustion below five leaves traffic blocked.

OFF restores captured runtime settings exactly. Failed restoration or a pending recovery marker requires stopping and restarting Tor. Normal torrc remains unchanged; ON is session-scoped. Application reload/routing commands are guarded while enabled. Compact width is increased to display the Flow control and progress.

This controls traffic using this application's Tor. Public-page success is time-specific and does not establish account eligibility or content generation.

## Verification

Release Win64 build succeeds with RAD Studio 37.0 and Synapse; existing missing EnvOptions.proj warning remains.

The pool suite passes: five-IP threshold, actual-IP deduplication, background discovery, private/user routing and quoted-field spoof rejection, healthy user circuit preservation, invalid member removal, router-disconnection blocking, family rejection, wrong circuit rejection, cancellation, CONNECT denial, expired consensus and exact restoration.

Actual Tor 0.4.9.13 accepts SessionGroup and stream attachment settings. Missing seed circuit fails before mutation with settings unchanged. Earlier live build reached five IPs at 10:08:20 and continued discovery. Earlier one-IP preview rendered Flow at 09:31–09:33; this is historical evidence only.

Network acceptance candidate before the UI refresh, SHA-256: 558C54572E3293B9EF38C0BDCBACC51B01E192DD5F006A7ADD5B05BB76D047A9.
The final candidate reached five distinct validated US IPs at 10:22:40, 97 seconds after activation. They were 138.197.124.121, 23.129.64.162, 158.173.216.73, 23.191.200.73 and 23.129.64.169. Discovery added two more at 10:22:46 and 10:22:57. Isolated Chrome used explicit SOCKS 127.0.0.1:19050 with remote DNS and QUIC disabled. A forced network reload rendered the actual public Flow /about page, heading, imagery and Create with Google Flow button. A fresh browser IP check reported IsTor=true and 104.167.242.118, a validated US pool member. The app showed the same IP, Flow US ON, seven valid IPs and scan 13/1017. Control snapshots at 10:23:15 and 10:23:56 confirmed StrictNodes=1, the validated fingerprint pool, open SOCKS, and the same Tor PID 3196 while private candidate scans continued. Controller probes no longer change the displayed user exit; CIRC optional fields are parsed by name. Evidence stays local in ignored artifacts/visual-evidence; profiles and private screenshots are excluded from distribution.

Login and content generation are not tested. HTML classification may need updates when Google changes its page.

## Protocol references

[Tor control commands](https://spec.torproject.org/control-spec/commands.html), [Tor path constraints](https://spec.torproject.org/path-spec/path-selection-constraints.html), [Tor automatic path selection scope](https://spec.torproject.org/path-spec/general-operation.html), [Google Flow](https://flow.google.com/).


Local final-build evidence: five_flow_page.png, five_tor_ip.png, five_flow_on.png, five-route-control.json, five-browser-command.json and five-scan-log.txt under artifacts/visual-evidence. Screenshots of unrelated browsers are not acceptance evidence.

The subsequent UI-only refresh and its live browser verification are documented in NETWORK_MODE_UI_2.13.9.0.md (packaged as NETWORK-MODE-UI-VALIDATION.md).

## Current requested thresholds

The current candidate opens user listeners after three distinct valid US IPs and stops discovery after ten successful distinct IPs, retaining periodic health checks. Button caption: Google AI; access validation target: Google Flow. Earlier five-IP evidence is historical. See NETWORK_MODE_UI_2.13.9.0.md for current validation.
