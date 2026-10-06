# Relay Onion Control Panel 2.13.1.0 — Scanner Network Integration Suspend

## Scope
When node reachability checks, ping measurement, or scanner runs start, Proxy/TUN network integration is temporarily suspended so scanner traffic uses direct host networking. After scanner completion, the previous mode is restored.

## Behaviour
- If Proxy was active before scan: disable during scan, restore Proxy after scan.
- If TUN (LAN) was active before scan: disable during scan, restore TUN (LAN) after scan.
- If both were off: no action.
- If the operator changes Proxy/TUN while scan is running: automatic restore is skipped to avoid overwriting operator intent.

## Build Evidence
- Delphi Win64 build: PASS
- Version metadata target: 2.13.1.0