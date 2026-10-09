# RD-3 — نقشه راه الزام‌آور Relay Onion Control Panel v3.0.0

**Document ID:** RD-3  
**Title:** Final Flow Mission Roadmap  
**Status:** ACTIVE / CANONICAL / APPLICABLE — development and acceptance baseline  
**Effective date:** 2026-10-09  
**Owner decision:** 2026-10-09 — «این نقشه راه را با عنوان RD-3 در این پروژه ثبت کن و آن را ملاک عمل قرار بده»  
**Baseline:** v2.13.8.0 (Git baseline `96eac73`)  
**Development repository (SUMS):** `E:\Projects\third-party\relay-onion-control-panel-tunfix`  
**Scope:** All Relay Onion Control Panel 3.0.0 work units, implementation, testing, UI/UX and release acceptance.  
**Change authority:** Owner approval; future changes require a versioned RD-3 revision and documented impact assessment.

> **حکم اجرایی:** هدف نسخه 3.0.0 دسترسی عملیاتی و قابل اتکا به Google Flow با انتخاب حالت Flow توسط کاربر است؛ نه فقط ساخت دکمه، نصاب یا دریافت HTTP 200. هیچ خروجی فاقد شواهد کامل نمی‌تواند «نسخه نهایی» نامیده شود. نسخه 3.0.0.4 صرفاً PREVIEW و در پذیرش نهایی **مردود** است.

## 1. معماری محصول و اصول غیرقابل مذاکره

`Operator UI (Delphi VCL, fa-IR RTL / en-US LTR / extensible BCP-47) → exclusive Mode Controller (Off, Flow, TUN, Proxy) → Flow Profile Manager → dynamic Relay Discovery → Exit Pool / Health / Circuit & Failover → Routing Policy → Chrome Session Manager / AI Flow Bypasser → operational authenticated Google Flow`

1. **موتور بومی:** منطق Flow در Delphi اجرا شود؛ PowerShell در مسیر عملیاتی Flow ممنوع است. Tor موتور انتقال است؛ ارتباط با ControlPort و اعتبارسنجی از طریق اجزای بومی انجام شود.
2. **انحصار حالت‌ها:** فقط یکی از Flow/TUN/Proxy روشن باشد. هر تغییر حالت دارای پیش‌شرط، Profile Load/Unload، Transition، Commit/Abort، Rollback منابع متعلق به برنامه و بازیابی پروفایل پس از Crash باشد. خاموش‌کردن Flow نباید سایر مسیرهای شبکه را مختل کند.
3. **بدون IP ثابت:** هر بار فعال‌سازی، IPها از `RoutersDic` و در صورت نیاز `network-cache`، `cached-microdesc-consensus` و Tor ControlPort کشف و اعتبارسنجی شوند. هیچ IP یا Fingerprint فعال در کد hardcode نشود.
4. **خروجی آمریکا:** تنها Relayهای us با Exit/Running/Valid و بدون BadExit؛ IP باید با Fingerprint و Consensus جاری تطبیق داشته باشد. اطلاعات منقضی هرگز مجوز اتصال نباشد.
5. **تفکیک سطوح سلامت:** `Tor bootstrap`، `circuit established`، `HTTP 200`، `authenticated Flow dashboard` و `actual Flow operation` وضعیت‌های متفاوت هستند. HTTP 200 صرفاً HTTP-ready است.
6. **Flow مستقل از TUN:** مسیر SOCKS5 اختصاصی Flow و سیاست‌های Google-only یا All Proxy، بدون تغییر غیرضروری system proxy، TUN یا Tor اصلی.
7. **مرورگر و افزونه:** Chrome اختصاصی و نشست قابل استفاده Google به همراه مکانیزم اثبات‌شده AI Flow Bypasser. گزینه انتقال مکانیزم به داخل برنامه فقط بررسی تحقیقاتی است؛ Release نباید به حل HTTPS MITM وابسته شود.
8. **برابری UI و کد:** پذیرش ظاهر، قابلیت کلیک، چراغ وضعیت و رفتار واقعی کنترل‌ها الزامی و هم‌ارزش پذیرش Backend است.
9. **چندزبانه واقعی:** فارسی پیش‌فرض کاملاً RTL و انگلیسی کاملاً LTR؛ کلیدهای معنایی، BCP-47، fallback انگلیسی، زبان‌های آینده بدون تغییر منطق، همراه با سازگاری `Translations.ini`.
10. **کنترل‌های ایمنی:** fail-closed، ثبت شواهد محلی، جلوگیری از تغییر مسیر ناخواسته یا نشت، عدم دست‌کاری منابع، نشست‌ها یا تنظیمات خارج از برنامه، و عدم افزودن telemetry/egress خارجی خارج از ترافیک لازم برای مأموریت.

## 2. جریان دقیق کشف و اعتبارسنجی Exit

1. **Source acquisition:** خواندن فهرست جاری `RoutersDic`؛ در صورت عدم بارگذاری یا ناکافی‌بودن، خواندن کش داخلی برنامه و Consensus معتبر؛ بررسی timestamp/expiry و به‌روزرسانی در صورت نیاز.
2. **Candidate filtering:** تطبیق IP/کش کشور `us`، Fingerprint، Exit + Running + Valid، حذف BadExit؛ حذف تکراری‌ها؛ ثبت source timestamp.
3. **Dynamic prioritization:** نتایج سلامت گذشته فقط برای مرتب‌سازی؛ هر خروجی پیش از استفاده باید دوباره اعتبارسنجی شود.
4. **Circuit validation:** تخصیص Tor client اختصاصی، انتخاب Fingerprint واقعی، کنترل Bootstrap/Circuit و سپس HTTPS زنده از همان خروجی. Timeout، خطاهای TLS، HTTP 403/429 و failureها ثبت شوند.
5. **Validated Exit Pool:** داده‌های هر مورد شامل `Fingerprint, IPv4, CountryCode, ConsensusTimestamp, LastCheckedAt, HTTPStatus, LatencyMs, HealthState, FailureReason, ExpiresAt, EvidenceID` باشد.
6. **Selection:** انتخاب فقط از خروجی‌های واقعاً تأییدشده و معتبر؛ قفل مسیر نشست Flow به همان Relay؛ اعلام `ready` در UI صرفاً با ذکر سطح سلامت اثبات‌شده.
7. **Monitoring + Failover:** پایش دوره‌ای Exit فعال؛ در قطع/ردشدن دسترسی، کاندیدای دیگری با آزمون تازه انتخاب شود و وضعیت UI، لاگ، Chrome و Circuit هماهنگ تغییر کنند؛ Retry و زمان انتظار سقف داشته باشند.
8. **Fail-closed:** اگر خروجی معتبر وجود ندارد، عدم اعلام موفقیت، آزادسازی منابع و نمایش علت به کاربر؛ کش موفقیت قدیمی مجوز bypass نیست.

## 3. Work stages / acceptance gates

| Stage | Priority | Deliverables | Mandatory acceptance |
|---|---|---|---|
| **RD3-S0 — Baseline & requirements** | P0 | تطبیق v2.13.8 با تغییرات جاری، Requirement Registry، dependency map، gap report، version traceability | سورس مرجع و الزامات/شواهد مشخص و بدون تعارض |
| **RD3-S1 — Transactional Mode Controller** | P0 | Off/Connecting/Ready/Failed/Stopping/Recovering؛ exclusivity؛ profile load/unload, owned-resource rollback and profile crash recovery | ده‌ها انتقال/لغو/شکست اجباری با آزادسازی منابع متعلق به برنامه و بدون پردازش سرگردان |
| **RD3-S2 — Dynamic Exit Health Engine** | P0 | discovery، fingerprint binding، TTL، health queue، evidence، periodic monitoring، post-ready failover | بدون IP ثابت؛ شکست خروجی فعال با جایگزینی معتبر یا توقف امن |
| **RD3-S3 — Flow Profile & Routing** | P0 | dedicated Tor/SOCKS/ControlPort/DataDirectory، Google-only و All Proxy، DNS domain policy | کار بدون TUN؛ عدم تغییر ترافیک و پروفایل‌های خارج از Flow |
| **RD3-S4 — Chrome & Bypasser Integration** | P0 | Chrome managed profile، نشست Google، آماده‌سازی/کنترل Bypasser و تشخیص وضعیت | داشبورد احرازشده واقعی بدون تنظیم دستی مکرر افزونه |
| **RD3-S5 — Operational UI/UX** | P0 | سه کنترل/آیکون مورد تأیید، چراغ و وضعیت قابل دید، خروجی فعال، پیشرفت، خطا، route policy | آزمون واقعی کلیک، اندازه پنجره/DPI، screenshot و عدم هم‌پوشانی |
| **RD3-S6 — Complete Localization** | P0 | fa-IR RTL، en-US LTR، BCP-47، fallback، persistence، ترجمه کل UI و reports | پوشش تمام فرم‌ها، تاریخ/اعداد/جهت؛ بارگذاری زبان ثالث |
| **RD3-S7 — End-to-end Acceptance** | P0 | نصب، Google login، پروژه‌های Flow، عملیات واقعی، failure injection، recovery و no-leak | همه ATهای اجباری پاس با Evidence |
| **RD3-S8 — Release/Audit** | P0 | reproducible Win64 build، Installer، manifest/hash، upgrade test، source commit و release | تطبیق Commit/Source/Binary و تأیید مالک |

**اصل تقدم:** S0 و S1 پایه ایمنی‌اند؛ S2–S4 مسیر عملیاتی را می‌سازند؛ S5 و S6 باید **هم‌زمان در چرخه توسعه** پیش بروند و پس از S4 به آینده موکول نشوند. S7 و S8 بدون قبولی تمام مراحل پیشین بسته نمی‌شوند.

## 4. Mandatory acceptance scenarios

| ID | Test / expected evidence |
|---|---|
| AT-01 | Flow از Off → داشبورد احرازشده و قابل استفاده |
| AT-02 | Flow در حضور Proxy/TUN → Unload/Load پروفایل‌های برنامه یا رد ایمن بدون دست‌کاری منابع خارج از برنامه |
| AT-03 | Exit با HTTP 403 → کنارگذاری و اعتبارسنجی کاندیدای بعدی |
| AT-04 | Consensus/کش منقضی → refresh و عدم انتخاب نامعتبر |
| AT-05 | خرابی Exit فعال پس از Ready → failover یا توقف امن |
| AT-06 | نبود Exit معتبر → خطای روشن، پاک‌سازی و عدم نشت |
| AT-07 | Google-only policy → فقط دامنه‌ها و DNS تعریف‌شده در پراکسی |
| AT-08 | All Proxy policy → همه ترافیک پروفایل تحت پوشش |
| AT-09 | Chrome + Bypasser → وضعیت نصب/فعال‌بودن و عملکرد واقعی |
| AT-10 | نشست Google → مشاهده داشبورد/پروژه‌های کاربر |
| AT-11 | Flow Off → Unload منابع Flow و بازگشت به وضعیت پروفایل برنامه |
| AT-12 | Crash/restart → بازیابی پروفایل برنامه بدون Tor/child متعلق به Flow سرگردان |
| AT-13 | فارسی/انگلیسی → پوشش کامل و RTL/LTR |
| AT-14 | زبان ثالث → بسته جدید و fallback صحیح |
| AT-15 | UI/DPI → کلیک مؤثر، چراغ درست، عدم هم‌پوشانی |
| AT-16 | نصب و ارتقا → حفظ داده‌ها و راه‌اندازی واقعی |
| AT-17 | Source/binary provenance → version, hash, matching commit |

## 5. Verification levels and decision rules

- **Build succeeded ≠ functionality accepted.** Build صرفاً Compile Gate است.
- **HTTP 200 ≠ authenticated Flow.** تنها شواهد مرورگر احرازشده و انجام عملیات واقعی Gate سطح Flow را پاس می‌کنند.
- **Preview ≠ release.** هر فایل نصب آزمایشی با برچسب دقیق `PREVIEW / NOT ACCEPTED` منتشر شود.
- **UI acceptance mandatory.** هر نقص کلیک، چیدمان، چراغ، RTL یا رابط کاربری، Gate مربوط را رد می‌کند.
- **Fail-closed mandatory.** هیچ ابزار جایگزین یا IP hardcode موقت نمی‌تواند Gate را دور بزند.
- **Owner assigned scope only.** افزودن مأموریت خارج از RD-3 بدون تأیید مالک ممنوع است.
- **Traceability:** هر Work Unit باید به RD3-Sx، یک یا چند AT-xx، فایل تغییرکرده، شواهد و نتیجه Gate وصل باشد. چرخه توسعه: `Requirement → Implementation → Build → Automated Test → Visual/UI Test → Evidence → Acceptance Gate → Release`.

## 6. Evidence-backed status at adoption

| Capability | Status | Evidence/limitation |
|---|---|---|
| Native Delphi controller | PARTIAL | source `FlowNativeV3.pas` compiled and tested, but integrated laptop UI not accepted |
| Dynamic exit discovery | PARTIAL | 1,015 US candidates dynamically identified in SUMS test; staleness management incomplete |
| Startup failover | PARTIAL | simulated live sequence 403/403/403→200 on fourth selected exit; post-ready failover missing |
| Dedicated Tor/Proxy | PARTIAL | independent Tor, SOCKS and HTTP CONNECT tested; full lifecycle/rollback incomplete |
| Chrome + Bypasser | NOT ACCEPTED | earlier independent A/B evidence exists; current build integration unverified |
| Google-only routing | NOT IMPLEMENTED | native current Chrome route proxies entire dedicated profile |
| Transactional switching | NOT IMPLEMENTED | currently refuses change when other mode enabled |
| UI/UX | REJECTED | owner screenshot of 3.0.0.4 and ineffective Flow button |
| Localization | PARTIAL | semantic unit and initial fa/en packs; UI-wide RTL/LTR not integrated |
| Installer | PREVIEW ONLY | 3.0.0.4 installer compiled and verified; operational end-to-end not accepted |

## 7. Document governance

- **Canonical identifier:** RD-3. Filename: `docs/RD-3.md`.
- **Change control:** هر تغییر در scope، معیار پذیرش، توالی وابستگی یا وضعیت Gate باید در نسخه بعدی RD-3 ثبت، با شواهد مرتبط توجیه و به تأیید مالک برسد.
- **Priority:** این سند ملاک اجرای نسخه 3.0.0 است. در صورت تعارض با TODO، فایل‌های Preview، شرح Commit یا توضیح چت، **RD-3 مبنای برنامه‌ریزی و پذیرش** است؛ تعارض باید ثبت و برای تصمیم مالک مطرح شود؛ RD-3 به‌صورت خاموش بازنویسی نشود.
- **Source release rule:** GitHub tag حاوی باینری بدون سورس متناظر و Commit قابل بازسازی، Gate RD3-S8 را پاس نمی‌کند.
- **Closure rule:** بسته‌شدن مأموریت نیازمند همه AT-01..AT-17، شواهد آزمون، ممیزی Release و تأیید صریح مالک است.

## RD-3 revision 1 — Owner scope clarification (2026-10-09)

**Binding owner decision:** Flow uses an application-owned profile loaded/unloaded by Relay Onion Control Panel. **Windows system snapshot, OS route/proxy/VPN restoration or management of third-party processes are OUT OF SCOPE for Flow.** S1 snapshots, rollback and crash recovery, where used, mean only **Flow profile state and application-owned resources**. The Flow profile must not alter unrelated Windows network settings. AT-02, AT-11 and AT-12 are evaluated at the application/profile ownership boundary. Existing ordinary TUN/Proxy capabilities are separate application modes; no Flow requirement authorizes external system mutation.
