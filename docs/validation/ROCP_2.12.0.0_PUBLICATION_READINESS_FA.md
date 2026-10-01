# آمادگی انتشار عمومی — Relay Onion Control Panel 2.12.0.0

## نتیجه

**انتشار سورس عمومی: PASS با محدودیت مشخص**  
**Stable binary Release: BLOCKED تا Build/Qualification جدید**

## شواهد پاس‌شده

- هویت محصول در source metadata، عنوان برنامه، REST/MCP و installer جدید به `Relay Onion Control Panel` تغییر کرده است.
- FileVersion/ProductVersion سورس برابر `2.12.0.0` است.
- مجوز MIT upstream بدون تغییر در `LICENSE` و `LICENSE-UPSTREAM-TCP` حفظ شده است.
- `NOTICE.md` منشأ اثر مشتق و عدم وابستگی به The Tor Project را ثبت می‌کند.
- README انگلیسی و فارسی و سیاست نسخه‌بندی/Release انگلیسی و فارسی افزوده شده‌اند.
- `TorControlPanel.exe` و شناسه‌های `tcp_*` فعلاً برای backward compatibility حفظ شده‌اند.
- XML پروژه Delphi parse شده و diff check خطای whitespace ندارد.
- Gitleaks 8.30.1 روی current tree و کل 24 commit archive اجرا شد؛ تنها finding اولیه یک SHA-256 مربوط به credential تستی بدون plaintext بود که با allowlist محدود به همان evidence/الگو مستند شد. اسکن با config نهایی PASS است.

## Blocker باینری

RAD Studio/Delphi، Synapse و Inno Setup موردنیاز برای Build 2.12 روی Safe-Laptop در دسترس نیستند. بنابراین در این مرحله هیچ ادعای Build PASS، installer qualification یا Stable binary release برای 2.12 مطرح نمی‌شود.

## تصمیم انتشار

برای جلوگیری از عمومی‌شدن ناخواسته releaseهای خصوصی قدیمی با نام قبلی و evidenceهای داخلی workstation، repository خصوصی `tor-control-panel-packaging` به‌عنوان archive/evidence lineage باقی می‌ماند و repository عمومی جدید `relay-onion-control-panel` از یک baseline پاک‌سازی‌شده ایجاد می‌شود.

## اقدام بعدی برای Stable Release

1. Build Win64 با toolchain مستند؛
2. کنترل metadata باینری 2.12؛
3. ساخت portable package و installer؛
4. manifest/SHA-256؛
5. fresh install/uninstall؛
6. migration test در صورت claim؛
7. secret/private-data scan artifactها؛
8. ایجاد tag/release و verify hash پس از upload.
