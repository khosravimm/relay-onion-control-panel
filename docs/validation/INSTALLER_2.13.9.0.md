# 2.13.9.0 installer validation

2026-10-11, project machine PC-ICTO-002. Inno Setup 6 produced the Windows x64 installer using the existing product AppId and distribution layout. No laptop was used.

Fresh current-user install to artifacts/installer-2.13.9-fresh: exit 0; registered version 2.13.9.0; installed executable SHA-256 6ac2df27c66818080995ed7f91e86ac010eaadda2f0bc1589518ebf2aca3e15b matched the visually tested build. Installed program was launched natively with an isolated InstallCheck profile; Google AI / Proxy / TUN labels rendered correctly. No Tor connection or system network change was initiated in this fresh profile.

Normal UI exit followed by fresh uninstall: exit 0; application executable and test HKCU registration removed. Existing machine-wide 3.0.0.0 installation remained registered at its original path. Upgrade/migration and account sign-in/content generation are not claimed. Installer is unsigned.

Build/install/uninstall logs are local ignored artifacts. Portable manifest, checksums and published remote asset hashes are verified separately. Publication uses a pre-release tag based on the committed v2.13.8.0-derived branch.
