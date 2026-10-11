# Network mode controls — UI update for 2.13.9.0 PREVIEW

Date: 2026-10-11. Host: PC-ICTO-002.

Proxy, TUN and Flow US now use the same native TButton class as the original Start control. They form one row of three equal 90 x 35 logical-pixel buttons with two-pixel gaps, parent font and native theme rendering. The custom colored bitmap lamps, hidden decorative shapes and active bold font are removed. Names stay fixed; separate centered labels below the buttons display Off, On, Starting, Stopping or Error. Flow displays compact IP counts and scan progress, with the full status and explanation in its tooltip. The TUN tooltip retains the LAN-preservation description.

Build succeeds. Native visual checks passed in the 600-pixel compact window and the 800-pixel expanded Settings window; the new row does not overlap existing circuit controls, toolbar or the original scanner area. Off, Proxy On/Off, Flow unavailable and Flow checking progress were observed. Proxy was returned to Off after an accidental click during a user window move. The initial Flow stream router disconnected and correctly blocked traffic; OFF restored previous runtime settings, and a fresh activation restarted discovery. The networking engine and click handlers are unchanged in this UI task.

Earlier UI candidate executable SHA-256: 65A7BD2797F5971B8BE45BF9534CBED973231F5BDDBB21A1B47374D85563B9F8.
Earlier unchanged FlowExitFilter.pas SHA-256: 3F1FFCDE2A4C10D19460C41F3E6F654C555003F48368E00E621C0F37B4EDA63E.

Local screenshots: artifacts/visual-evidence/mode_ui_compact.png and mode_ui_expanded.png. These are excluded from the distribution. Original network acceptance evidence is recorded separately in FLOW_EXIT_FILTER_2.13.9.0.md and is tied to its earlier build hash. Fresh live checking of the UI candidate passed after retry: five distinct IPs opened user listeners at 10:35:59; eight were active by 10:37. Forced network reload rendered the public Flow page through the isolated SOCKS browser. The app showed US exit 23.128.248.170 and the complete compact status 8 IPs | 18/1017. Both compact and expanded layouts were captured with Flow active, without label clipping or control overlap. Tor route evidence is saved in mode-ui-route-control.json; Tor PID was 21072. Proxy and TUN remained Off.

Final local screenshots: mode_ui_compact_live.png, mode_ui_expanded_live.png and mode_ui_flow_page.png under artifacts/visual-evidence.

## Subsequent requested behavior change

The visible button is now Google AI. Readiness requires three distinct verified US IPs. Discovery permanently stops for this activation when the pool first reaches ten distinct valid IPs; periodic revalidation of pool members continues. If revalidation reduces the pool below three, traffic is blocked as before. The acceptance target remains Google Flow. Twelve mock-control cases passed, including readiness at exactly three and a cap case with eleven eligible candidates proving only ten probes occur. Earlier five-IP visual evidence above is historical.

Current executable SHA-256: 6ac2df27c66818080995ed7f91e86ac010eaadda2f0bc1589518ebf2aca3e15b.
Live readiness occurred at 10:42:22 with three different actual US IPs: 23.129.64.162, 158.173.216.73 and 104.167.242.118. Discovery continued afterward. Forced reload of the isolated SOCKS Chrome browser rendered the public Flow page at 10:42; compact and expanded native Google AI controls were visually inspected. Proxy and TUN are Off. Tor PID: 23248. Current evidence: google_ai_flow_page.png, google_ai_compact.png, google_ai_expanded.png and google-ai-three-route-control.json in artifacts/visual-evidence. The ten-IP stop was verified by the mock-control cap test, not claimed as a live ten-IP observation.

Live ten-IP stop was subsequently observed at 10:44:58. Discovery stopped at candidate 33/1017; later probes were only health revalidation of existing members, and the UI displayed 10 IPs | done at 10:48.
