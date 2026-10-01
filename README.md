# Relay Onion Control Panel

[فارسی / Persian](README.fa.md)

**Relay Onion Control Panel** is an independent Windows GUI for configuring, managing, and monitoring a Tor™ Expert Bundle runtime. It is a derivative of the open-source [Tor Control Panel](https://github.com/abysshint/tor-control-panel) project maintained by `abysshint` and its contributors.

> **Independent project:** Relay Onion Control Panel is not endorsed, sponsored by, or affiliated with The Tor Project. Tor is a trademark of The Tor Project. References to Tor and Tor Expert Bundle are descriptive references to software/network compatibility.

## Project lineage and licensing

- Upstream project: `abysshint/tor-control-panel`
- Recorded upstream baseline: commit `7bdb82747c20ebddff5cb6fa006626e3fac94cd4`
- Upstream license: MIT
- Upstream copyright: `Copyright (c) 2020-2025, abysshint & contributors`
- Relay Onion Control Panel modifications: maintained by **Mohammad Mahdi Khosravi**

The upstream MIT license is preserved verbatim in [`LICENSE`](LICENSE) and [`LICENSE-UPSTREAM-TCP`](LICENSE-UPSTREAM-TCP). See [`NOTICE.md`](NOTICE.md) for derivative-work attribution.

## Current release line

The first public source line under the Relay Onion Control Panel identity is **2.12.0.0**. A stable binary 2.12 release remains gated on a fresh build and release qualification; source publication does not imply binary qualification. The executable filename remains `TorControlPanel.exe` for backward compatibility; this filename does not imply affiliation with The Tor Project.

The current Windows release continues to use Tor Expert Bundle **15.0.24** with Tor runtime **0.4.9.13**, subject to the individual licenses shipped with those components.

## Added capabilities in this derivative

Compared with the recorded upstream baseline, this repository includes, among other changes:

- visible application version in the main window title;
- Machine Interface foundation and settings;
- local read-only REST endpoints;
- local read-only MCP runtime and tools;
- API-key policy and generated-key handling;
- operator-selectable descriptor retrieval mode;
- packaging/migration and verification controls for current Tor Expert Bundle layouts.

See [`source/Changelog.txt`](source/Changelog.txt) and [`docs/validation/`](docs/validation/) for release-specific evidence and claim boundaries.

## Security model and current boundaries

Current machine interfaces are intentionally restricted. Historical release evidence documents the exact qualified scope. Remote REST/MCP and state-changing MCP tools must not be assumed to be qualified unless a later release explicitly says so.

Operational user data, cache/state, private bridge lists, credentials, API-key plaintext, and live profiles are not intended to be committed or bundled.

## Build

Requirements:

- Windows 10/11 or Windows Server
- Delphi/RAD Studio compatible with VCL Win32/Win64
- Ararat Synapse sources
- Inno Setup 6 for installer generation

See [`docs/BUILD_INSTRUCTIONS.md`](docs/BUILD_INSTRUCTIONS.md).

## Versioning and releases

This project uses a four-component product version (`MAJOR.MINOR.PATCH.BUILD`) to remain compatible with the existing Windows/Delphi version metadata and project history. Release rules, tag conventions, qualification gates, hashes, and artifact requirements are documented in:

- [`docs/VERSIONING_AND_RELEASE.md`](docs/VERSIONING_AND_RELEASE.md)
- [`docs/VERSIONING_AND_RELEASE_FA.md`](docs/VERSIONING_AND_RELEASE_FA.md)

## Historical material

Documents and release evidence referring to **Tor Control Panel** or the old repository name are retained as immutable historical evidence. They describe releases produced before the 2.12.0.0 public rebrand and are not rewritten retroactively.

## License

MIT. See [`LICENSE`](LICENSE).
