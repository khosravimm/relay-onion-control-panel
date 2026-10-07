# TUN VPN default-route correction, 2.13.6.0

Date: 2026-10-07. Scope: Windows x64, existing IPv4 TUN integration and sing-box 1.14.2.

## Problem and change

An active VPN default route won Windows route selection while RelayOnion TUN was active. Ordinary requests used the VPN exit; explicit local Tor SOCKS requests used the configured Tor exit.

The generated TUN inbound now sets route_address to 0.0.0.0/1 and 128.0.0.0/1. The two prefixes cover IPv4 and are more specific than default /0 routes, independently of adapter metrics. sing-box auto_route owns their lifecycle. Existing Tor/local SOCKS, upstream interface auto detection and private-network rules are preserved. No user adapter name, gateway or VPN server address is encoded in this correction.

Official field reference: https://sing-box.sagernet.org/configuration/inbound/tun/#route_address

## Evidence

- Delphi Win64 Release build: PASS. Executable FileVersion and ProductVersion: 2.13.6.0.
- NetworkIntegrationRouteConfigTest: PASS for all four Proxy/TUN combinations. Checks valid JSON, inbound selection, both IPv4 halves, route lifecycle ownership, local Tor SOCKS and default Tor routing.
- Each generated fixture passed actual sing-box 1.14.2 config validation.
- Existing NetworkIntegrationReapplyTest: PASS, including repeated reapply, authorization before mutation and explicit stop/restart behavior.
- Build host actual engine test using the generated TUN-only fixture: both /1 routes created, ordinary no-proxy HTTPS request succeeded, engine stop removed both routes.
- Safe-Laptop with VPN active: temporary equivalent /1 routes changed Windows route selection for addresses in both halves from VPN to RelayOnion. Ordinary no-proxy api.ipify.org and explicit local SOCKS requests both returned 23.129.64.173 (exit 0). Temporary routes were removed in finally; subsequent check found zero remaining /1 test routes and the original VPN /0 selected again.

The laptop test validates the routing mechanism on the installed 2.13.5.0 engine; it does not claim that 2.13.6.0 has been installed there. Actual configuration generation and engine route lifecycle were tested separately on the build host.

## Boundaries

This addresses competing IPv4 /0 routes. VPNs that install equal or more-specific routes, or enforce traffic outside the Windows route table, require separate compatibility validation. IPv6 behavior is unchanged and is not newly qualified. Stable publication and installation of this package on Safe-Laptop have not been performed.

## Reproduction

Compile tests/NetworkIntegrationRouteConfigTest.dpr with the same Delphi unit paths as NetworkIntegrationReapplyTest. Run it with an output directory argument, then run the pinned sing-box check -c against each of its four JSON files. Fixture files are synthetic; no user profile is required.