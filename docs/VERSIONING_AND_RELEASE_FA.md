# سیاست نسخه‌بندی و Release

## قالب نسخه

Relay Onion Control Panel از قالب `MAJOR.MINOR.PATCH.BUILD` استفاده می‌کند. این قالب «Semantic Versioning خالص» ادعا نمی‌شود؛ هدف، سازگاری با FileVersion/ProductVersion ویندوز، Delphi و تاریخچه موجود است.

- **MAJOR**: تغییر ناسازگار معماری محصول/Runtime یا شروع نسل جدید.
- **MINOR**: قابلیت مهم، تغییر هویت عمومی محصول، یا گسترش معنادار رفتارهای qualified.
- **PATCH**: اصلاح backward-compatible یک defect یا تغییر محدود که نیازمند Release محصول است.
- **BUILD**: rebuild یا تغییر صرفاً بسته‌بندی بدون تغییر رفتار سورس؛ این حالت نیز باید evidence قابل بازتولید داشته باشد.

تصمیم مالک `DEC-TCP-005` مقرر کرده بود تغییر عمده با افزایش نسخه محصول منتشر شود و از suffixهایی مانند `R4` برای تغییر عمده استفاده نشود. تاریخچه 2.7 تا 2.11 همین الگو را دارد؛ بنابراین rebrand عمومی با نسخه **2.12.0.0** منتشر می‌شود.

## نسخه‌های تاریخی

Tag، Release، hash و گزارش اعتبارسنجی منتشرشده evidence تاریخی هستند و پس از تغییر نام محصول بازنویسی نمی‌شوند.

## Tag انتشار

وقتی نسخه با یک Tor Expert Bundle مشخص qualification شده باشد:

`v<PRODUCT_VERSION>-tor-<TOR_EXPERT_BUNDLE_VERSION>`

نمونه: `v2.12.0.0-tor-15.0.24`

پسوند `tor-...` نسخه dependency را بیان می‌کند و نام برند محصول نیست.

## Artifactهای الزامی

برای Stable GitHub Release باینری، در صورت کاربرد حداقل باید وجود داشته باشد:

1. ZIP قابل‌حمل/offline؛
2. Installer ویندوز؛
3. `SHA256SUMS-ROCP-<version>.txt` برای همه artifactهای باینری؛
4. Release Notes شامل scope، قابلیت‌های verified، محدودیت‌های شناخته‌شده و gateهای باز.

وجود `Data/User` عملیاتی، bridge خصوصی، credential، API key خام یا profile واقعی کاربر در artifact انتشار ممنوع است.

## Gateهای Release

پیش از Stable publication:

- source tree commit شده و clean باشد؛
- نام/نسخه در metadata سورس، UI، REST/MCP، Installer و مستندات یکسان باشد؛
- Build Win64 PASS شود؛ Win32 فقط در صورت claim الزامی است؛
- manifest و hash بسته تولید و verify شود؛
- fresh install/uninstall برای Installer PASS شود؛
- اگر migration جزو claim است، preservation/migration test انجام شود؛
- secret/private-data scan PASS شود؛
- license/notice اجزای ثالث موجود باشد؛
- قابلیت‌های unqualified و gateهای باز صریحاً ثبت شوند.

## صحت Publication

پس از انتشار GitHub، metadata و assetها دوباره دریافت می‌شوند و SHA-256 نسخه remote با evidence محلی frozen مقایسه می‌شود. فقط پس از تطابق، Publication برابر PASS است.

## Pre-release

Buildی که همه gateهای لازم برای Stable را پاس نکرده باید در GitHub با وضعیت **Pre-release** منتشر شود و نباید Stable معرفی شود. شماره نسخه یا tag به‌تنهایی evidence qualification نیست.
