# Network Integration TUN Disabled - 2.13.4.0

Decision: TUN (LAN) is temporarily disabled due to elevation/runtime stability issues.

Controls:
- UI button remains visible but disabled.
- Stored TunEnabled preference is ignored and saved as false while the feature gate is disabled.
- Runtime Apply path enforces TunEnabled=false.
- Proxy mode remains available.

Build: pending in release pipeline.
