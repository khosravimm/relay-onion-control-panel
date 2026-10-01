# Versioning and Release Policy

## Version format

Relay Onion Control Panel uses `MAJOR.MINOR.PATCH.BUILD`. This is not claimed to be strict Semantic Versioning; it follows the existing Windows/Delphi FileVersion/ProductVersion lineage.

- **MAJOR** — incompatible product/runtime architecture change or generation reset.
- **MINOR** — substantial capability, public product-identity change, or materially expanded qualified behavior.
- **PATCH** — backward-compatible defect or narrowly scoped functional correction that merits a product release.
- **BUILD** — packaging/rebuild-only revision when source behavior is unchanged; it still requires reproducible evidence.

The established project history uses a product-version bump for substantial changes rather than an `R<n>` suffix. The 2.7 through 2.11 history follows that rule. The public rebrand is therefore **2.12.0.0**. The corresponding historical owner decision remains preserved in the private lineage archive.

## Historical releases

Published historical tags, releases, hashes and validation reports are immutable evidence. Renaming the product does not rewrite them.

## Release tags

When a release is qualified against a specific Tor Expert Bundle version, use:

`v<PRODUCT_VERSION>-tor-<TOR_EXPERT_BUNDLE_VERSION>`

Example: `v2.12.0.0-tor-15.0.24`.

The `tor-...` suffix describes the dependency version, not the product brand.

## Required artifacts

A stable binary GitHub Release must include, when applicable:

1. portable/offline ZIP;
2. Windows installer;
3. `SHA256SUMS-ROCP-<version>.txt` for all binary assets;
4. release notes with scope, verified capabilities, known limitations and open gates.

Operational `Data/User`, private bridges, credentials, plaintext API keys and real user profiles are prohibited from release assets.

## Release gates

Before a stable publication:

- the source tree is committed and clean;
- product name/version agree across source metadata, UI title, REST/MCP identity, installer and docs;
- Win64 build passes; Win32 is required only if claimed;
- package manifest and hashes are generated and verified;
- fresh install/uninstall passes for installer releases;
- migration preservation is tested when migration behavior is claimed;
- secret/private-data scan passes;
- applicable third-party licenses/notices are present;
- all unqualified functions and open gates are explicitly listed.

## Publication integrity

After GitHub publication, retrieve release metadata/assets and compare remote SHA-256 values with frozen local evidence. Publication is PASS only after the comparison succeeds.

## Pre-release

A build that has not passed all applicable stable-release gates must be marked GitHub **Pre-release** and must not be represented as stable. A version number or tag alone is not qualification evidence.
