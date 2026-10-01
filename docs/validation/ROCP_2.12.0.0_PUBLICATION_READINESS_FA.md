# آمادگی انتشار عمومی — Relay Onion Control Panel 2.12.0.0

## نتیجه

**انتشار سورس عمومی: PASS**

**Stable binary Release: PASS برای Publication؛ تأیید نهایی پس از دانلود مجدد assetهای GitHub و تطبیق SHA-256 انجام می‌شود.**

## شواهد پاس‌شده

- هویت محصول در source metadata، UI، REST/MCP و installer برابر `Relay Onion Control Panel` است.
- FileVersion/ProductVersion و فیلدهای عددی Delphi برابر `2.12.0.0` هستند.
- مجوز MIT upstream بدون تغییر حفظ شده و `NOTICE.md` منشأ اثر مشتق و عدم وابستگی به The Tor Project را ثبت می‌کند.
- README و مستندات Build/Versioning/Release به انگلیسی و فارسی موجودند.
- Build Win64 و Win32 با RAD Studio / Delphi BDS 37.0: PASS.
- ProductName باینری‌ها: `Relay Onion Control Panel`.
- Machine Interface policy test در Win64 و Win32: PASS.
- package manifest: 73/73 PASS.
- ZIP قابل‌حمل پس از Extract مستقل دوباره verify شد: PASS.
- Tor runtime برابر 0.4.9.13 و hash آن دقیقاً با baseline qualified نسخه 2.11 یکسان است.
- `Data/User` عملیاتی در Release وجود ندارد.
- اسکن متنی artifact برای secret/private key: صفر finding.
- Inno Setup 6.7.3: compile PASS.
- Fresh silent install/uninstall: PASS.
- Migration preservation/cleanup: PASS.
- default REST/MCP listeners روی پورت‌های 19090/19091 در اجرای واقعی خاموش ماندند: PASS.
- REST local read-only برای 2.12 مجدداً qualification شد: PASS.
- MCP local read-only با protocol `2026-07-28` و سه tool دقیق `tcp_version`, `tcp_status`, `tcp_health` مجدداً qualification شد: PASS.
- Non-loopback MCP failure injection با `AllowRemote=0`: fail-closed PASS.

## Artifactهای Frozen

### Portable ZIP

`RelayOnionControlPanel-2.12.0.0-TorExpertBundle-15.0.24-windows-x64-portable-offline.zip`

SHA-256:
`85a6047512811cf629c5799cf6ef8cb1df2c7c52e41e25b73b912f671e966bf7`

### Installer

`RelayOnionControlPanel-2.12.0.0-TorExpertBundle-15.0.24-windows-x64-setup.exe`

SHA-256:
`609edb02bbab537f8b6e02fb2f538261f082549cf2daa60eed6f1375e82b7654`

### Checksum file

`SHA256SUMS-ROCP-2.12.0.0.txt`

SHA-256:
`aff7047941ef3b3eb21a20a49a55307400cd9c051332a4af56d48ed2cafb59cd`

## محدودیت‌های صریح

- executable اصلی و Installer فعلاً Authenticode-signed نیستند.
- Remote REST/MCP خارج از محدوده qualified است.
- Write/control MCP ارائه یا qualified نشده است.
- stdio MCP در GUI host به‌عنوان production-qualified ادعا نمی‌شود.
- recovery مسیر direct Tor در همه شبکه‌ها تضمین نمی‌شود.
- Relay Onion Control Panel مستقل است و مورد تأیید، حمایت یا وابسته به The Tor Project نیست.

## معماری انتشار

برای جلوگیری از عمومی‌شدن releaseهای خصوصی قدیمی و evidenceهای داخلی workstation، repository خصوصی `tor-control-panel-packaging` به‌عنوان lineage/build archive باقی می‌ماند و repository عمومی `relay-onion-control-panel` baseline پاک‌سازی‌شده محصول را نگهداری می‌کند.

## آخرین Gate

Tag موردنظر:
`v2.12.0.0-tor-15.0.24`

Release فقط پس از آپلود سه artifact frozen بالا و دانلود مجدد آن‌ها از GitHub و تطبیق کامل SHA-256 نهایی محسوب می‌شود.
