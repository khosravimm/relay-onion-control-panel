# Relay Onion Control Panel

[English](README.md)

**Relay Onion Control Panel** یک نرم‌افزار مستقل برای Windows است که رابط گرافیکی مدیریت، پیکربندی و پایش اجرای Tor™ Expert Bundle را فراهم می‌کند. این پروژه یک **اثر مشتق‌شده** از پروژه متن‌باز [Tor Control Panel](https://github.com/abysshint/tor-control-panel) متعلق به `abysshint` و مشارکت‌کنندگان آن است.

> **اعلام استقلال:** این پروژه مورد تأیید، حمایت، اسپانسر یا وابسته به The Tor Project نیست. Tor علامت تجاری The Tor Project است. استفاده از نام Tor و Tor Expert Bundle در این مخزن صرفاً برای توصیف سازگاری و حوزه عملکرد نرم‌افزار است.

## منشأ و مجوز

- پروژه بالادست: `abysshint/tor-control-panel`
- baseline ثبت‌شده: commit `7bdb82747c20ebddff5cb6fa006626e3fac94cd4`
- مجوز بالادست: MIT
- حق مؤلف بالادست: `Copyright (c) 2020-2025, abysshint & contributors`
- نگهدارنده تغییرات Relay Onion Control Panel: **Mohammad Mahdi Khosravi**

متن اصلی مجوز MIT بدون تغییر در [`LICENSE`](LICENSE) و [`LICENSE-UPSTREAM-TCP`](LICENSE-UPSTREAM-TCP) حفظ شده است. جزئیات انتساب اثر مشتق در [`NOTICE.md`](NOTICE.md) آمده است.

## نسخه جاری

اولین خط Release عمومی با هویت **Relay Onion Control Panel** نسخه **2.12.0.0** است. Stable binary Release این نسخه Build، بسته‌بندی، نصب/مهاجرت، REST/MCP و کنترل صحت artifact را با موفقیت qualification کرده است. گزارش کامل در [`docs/validation/RELEASE_PACKAGE_2.12.0.0_FA.md`](docs/validation/RELEASE_PACKAGE_2.12.0.0_FA.md) ثبت شده است.

نام فایل اجرایی فعلاً برای سازگاری عقب‌رو `TorControlPanel.exe` باقی می‌ماند. باقی ماندن این نام فایل به معنی وابستگی یا تأیید The Tor Project نیست.

نسخه جاری برای Tor Expert Bundle **15.0.24** و Tor runtime **0.4.9.13** بسته‌بندی/اعتبارسنجی می‌شود.

## قابلیت‌های افزوده‌شده در این شاخه

در مقایسه با baseline ثبت‌شده پروژه اصلی، از جمله این قابلیت‌ها اضافه شده‌اند:

- نمایش نسخه برنامه در عنوان پنجره؛
- زیرساخت Machine Interface؛
- REST API محلی و فقط‌خواندنی؛
- MCP محلی و فقط‌خواندنی؛
- سیاست API Key و تولید کلید؛
- انتخاب Descriptor Retrieval Mode توسط کاربر؛
- کنترل‌های بسته‌بندی، مهاجرت و اعتبارسنجی برای Tor Expert Bundle جدید.

جزئیات تغییرات در [`source/Changelog.txt`](source/Changelog.txt) و شواهد هر نسخه در [`docs/validation/`](docs/validation/) ثبت شده‌اند.

## مرزهای امنیتی

وجود کد یا تنظیم به‌تنهایی به معنی qualification نیست. قابلیت‌های Machine Interface فقط در محدوده‌ای معتبرند که در Release مربوطه صریحاً آزمون و ثبت شده باشند. Remote REST/MCP و ابزارهای MCP تغییردهنده وضعیت، تا زمانی که Release جدید صریحاً آن‌ها را qualified اعلام نکرده باشد، نباید عملیاتی/معتبر فرض شوند.

داده عملیاتی کاربران، cache/state، bridge خصوصی، credential، API key خام و profile واقعی نباید در repository یا Release قرار گیرند.

## ساخت

نیازمندی‌ها:

- Windows 10/11 یا Windows Server
- Delphi/RAD Studio سازگار با VCL Win32/Win64
- Ararat Synapse
- Inno Setup 6 برای Installer

راهنمای ساخت: [`docs/BUILD_INSTRUCTIONS.md`](docs/BUILD_INSTRUCTIONS.md)

## نسخه‌بندی و Release

پروژه از قالب چهارقسمتی `MAJOR.MINOR.PATCH.BUILD` استفاده می‌کند تا با Windows/Delphi و تاریخچه فعلی سازگار بماند. قواعد دقیق افزایش نسخه، tag، qualification، hash، artifact و publication در این اسناد آمده است:

- [`docs/VERSIONING_AND_RELEASE_FA.md`](docs/VERSIONING_AND_RELEASE_FA.md)
- [`docs/VERSIONING_AND_RELEASE.md`](docs/VERSIONING_AND_RELEASE.md)

## اسناد تاریخی

اسناد قدیمی که نام **Tor Control Panel** یا نام قبلی repository را دارند عمداً بازنویسی نمی‌شوند؛ آن‌ها evidence نسخه‌های پیش از rebrand در 2.12.0.0 هستند.

## مجوز

MIT — به [`LICENSE`](LICENSE) مراجعه کنید.
