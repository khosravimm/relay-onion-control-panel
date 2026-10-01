# صلاحیت Release — Relay Onion Control Panel 2.12.0.0

## نتیجه

**PASS — برای Stable Binary GitHub Release واجد شرایط است**، با محدودیت‌های صریحی که در انتهای سند آمده‌اند.

## محدوده

Relay Onion Control Panel 2.12.0.0، مشتق از `abysshint/tor-control-panel`، همراه با Tor Expert Bundle 15.0.24 و Tor 0.4.9.13.

## Build

- RAD Studio / Delphi 13.2، BDS 37.0.
- Build Win64 Release: PASS.
  - FileVersion/ProductVersion: `2.12.0.0`
  - ProductName: `Relay Onion Control Panel`
  - SHA-256: `b85cfc8e48a871a23a18c21094c1fc8f0c7ca23eb68302cbb36f24735fce371e`
- Build اختیاری Win32 Release: PASS.
  - FileVersion: `2.12.0.0`
  - SHA-256: `331b5c78ee6e05ce6756a6902930a9d8944b89f0b5086829ae2be2aa49e2132a`
- تست سیاست Machine Interface روی Win64 و Win32: PASS.

## کنترل بسته

- Manifest بسته: 73 رکورد، 0 hash نامعتبر.
- ZIP قابل‌حمل در مسیر مستقل Extract و دوباره verify شد: PASS، 73/73.
- `Data/User` عملیاتی داخل بسته نیست.
- `Data/User.template` وجود دارد.
- `snowflake-client.exe` و `webtunnel-client.exe` منسوخ در بسته نیستند.
- Tor runtime: `0.4.9.13`.
- SHA-256 فایل Tor: `90bbdcafd586feea608a5e9b7d3959f4ee194f7770755cfde8fab240e9773ad1` و دقیقاً با baseline qualified نسخه 2.11 برابر است.
- اسکن متنی artifact برای secret/private key: صفر finding.

## Qualification نصب

Installer با Inno Setup 6.7.3 با موفقیت ساخته شد.

Fresh silent install/uninstall:
- install exit: 0
- نسخه نصب‌شده: `2.12.0.0`
- ProductName: `Relay Onion Control Panel`
- Tor: `0.4.9.13`
- `DescriptorMode=0`
- در اجرای واقعی برنامه، تعداد listenerهای REST/MCP روی پورت‌های پیش‌فرض 19090/19091 برابر 0 بود.
- uninstall exit: 0

Migration install/uninstall:
- install exit: 0
- marker تنظیمات قبلی حفظ شد: PASS
- `DescriptorMode=1` قبلی حفظ شد: PASS
- snowflake قدیمی حذف شد: PASS
- webtunnel قدیمی حذف شد: PASS
- uninstall exit: 0

## REST

با profile ایزوله و پورت آزمایشی loopback:
- listener محلی REST: PASS
- `GET /api/v1/version`: محصول `Relay Onion Control Panel`، نسخه `2.12.0.0`
- `GET /api/v1/status`: PASS
- `GET /api/v1/health`: PASS
- `POST /api/v1/status`: HTTP 405 و fail-closed

نتیجه: محدوده local read-only REST مجدداً برای 2.12 PASS شد.

## MCP

با profile ایزوله و پورت آزمایشی loopback:
- MCP protocol `2026-07-28`: PASS
- tool set دقیق: `tcp_version`, `tcp_status`, `tcp_health`
- تعداد tool: 3
- write-like tool: صفر
- discover/list/callهای مثبت: HTTP 200
- بدون `Mcp-Method`: HTTP 400 / `-32020`
- بدون `Mcp-Name`: HTTP 400 / `-32020`
- بدون `_meta`: HTTP 400 / `-32602`
- `tcp_version`: نسخه `2.12.0.0`
- failure injection غیر-loopback با `0.0.0.0` و `AllowRemote=0`: process زنده ماند و listener ایجاد نشد.

نتیجه: محدوده local read-only MCP مجدداً برای 2.12 PASS شد.

## Artifactهای Frozen

ZIP:
`RelayOnionControlPanel-2.12.0.0-TorExpertBundle-15.0.24-windows-x64-portable-offline.zip`

SHA-256:
`85a6047512811cf629c5799cf6ef8cb1df2c7c52e41e25b73b912f671e966bf7`

Installer:
`RelayOnionControlPanel-2.12.0.0-TorExpertBundle-15.0.24-windows-x64-setup.exe`

SHA-256:
`609edb02bbab537f8b6e02fb2f538261f082549cf2daa60eed6f1375e82b7654`

Checksum file:
`SHA256SUMS-ROCP-2.12.0.0.txt`

SHA-256:
`aff7047941ef3b3eb21a20a49a55307400cd9c051332a4af56d48ed2cafb59cd`

## محدودیت‌های صریح

- executable اصلی و Installer فعلاً Authenticode-signed نیستند.
- Remote REST/MCP خارج از محدوده qualified است.
- MCP تغییردهنده وضعیت/نوشتنی ارائه یا qualified نشده است.
- stdio MCP در GUI host به‌عنوان production-qualified ادعا نمی‌شود.
- بازیابی مسیر مستقیم Tor برای تمام شبکه‌ها تضمین نمی‌شود و مرزهای قبلی Descriptor Mode/bridge/fallback معتبرند.
- Relay Onion Control Panel پروژه‌ای مستقل است و مورد تأیید، حمایت یا وابسته به The Tor Project نیست.

## تأیید Publication

**PASS.** Stable GitHub Release با tag `v2.12.0.0-tor-15.0.24` منتشر شد:

https://github.com/khosravimm/relay-onion-control-panel/releases/tag/v2.12.0.0-tor-15.0.24

هر سه asset از خود GitHub در یک مسیر verification تمیز دوباره دانلود شدند و SHA-256 هر سه دقیقاً با مقادیر frozen محلی تطابق داشت. Release نه Draft است و نه Pre-release.
