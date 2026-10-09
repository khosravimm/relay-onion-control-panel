# RD3-S0 — Requirement Registry and Gap Baseline

**Authority:** [RD-3](../RD-3.md) · **Date:** 2026-10-09  
**Baseline:** 2.13.8.0 / commit `96eac73` · **Working tree:** 3.0.0.4 preview changes, not release-accepted.  
**Status:** OPEN — evidence-backed inventory, not S0 acceptance.

| Requirement | RD-3 stage | Acceptance | Current evidence | Gap / work unit |
|---|---|---|---|---|
| REQ-001 exclusive Off/Flow/TUN/Proxy | S1 | AT-02,11,12 | `Main.pas` click guards | centralized transactional controller and rollback absent |
| REQ-002 Flow native Delphi runtime | S3 | AT-01,06 | `FlowNativeV3.pas` / SUMS harness | integration smoke on installed laptop pending |
| REQ-003 fresh US relay discovery | S2 | AT-03,04 | `RoutersDic` and `FlowCatalogV3.pas` | enforce freshness and fingerprint/country validation |
| REQ-004 exit health / failover | S2 | AT-03,05,06 | SUMS startup failover 403,403,403 → 200 | post-ready monitoring, TTL, reproducibility |
| REQ-005 dedicated isolated Tor process | S3 | AT-06,11,12 | dedicated SOCKS/control ports in `FlowNativeV3.pas` | process ownership, liveness, cleanup crash |
| REQ-006 Google-only / all-proxy routing | S3 | AT-07,08 | old script prototype only | native policy selector and tested DNS domain coverage |
| REQ-007 Chrome session integration | S4 | AT-01,10 | isolated launch in `Main.pas` | actual authenticated session continuity |
| REQ-008 AI Flow Bypasser | S4 | AT-09,10 | historic isolated A/B test; not v3 integrated | managed extension lifecycle + real check |
| REQ-009 3 mode button UI | S5 | AT-15 | current preview UI reported rejected | visual redesign, DPI and click test |
| REQ-010 localization BCP-47 | S6 | AT-13,14 | `LocalizationV3.pas` and 2 packs | wiring all controls, direction and persistence |
| REQ-011 install, upgrade, provenance | S7-S8 | AT-16,17 | installer 3.0.0.4 / manifest | matching source commit, install migration E2E |
| REQ-012 privacy and no-leak | S1,S3,S7 | AT-02,06,11,12 | helper avoids global TUN mutation | negative testing and rollback evidence |

## Dependency and delivery gates

`S0 → S1 → S2 → S3 → S4 → S7 → S8`. S5 and S6 run in parallel with S1-S4; all gates required before S8 acceptance. Every work unit must record changed paths, AT evidence, outstanding defects, and owner decision.

## Current blockers

- Existing button callbacks mutate booleans and apply network changes directly: no durable transactional coordinator.
- Native Flow reports HTTP-ready, not authenticated Flow-ready.
- Browser Bypasser integration and UI localization not yet demonstrably operational.
- Git tag published for preview binaries is not yet backed by matching source commit (RD3-S8 fails).
