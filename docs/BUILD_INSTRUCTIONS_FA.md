# راهنمای Build

## پیش‌نیازها

- Windows 10/11 یا Windows Server
- Delphi/RAD Studio دارای VCL و پشتیبانی Win64
- سورس Ararat Synapse
- Inno Setup 6 برای ساخت Installer

هیچ فایل repository نباید به مسیر مطلق و اختصاصی کامپیوتر maintainer وابسته باشد. مسیر ابزارها در زمان Build با متغیر محیطی تعیین می‌شود.

## متغیرهای محیطی

نمونه:

```powershell
$env:ROCP_RAD_RS_VARS = 'C:\Path\To\Embarcadero\Studio\<version>\bin\rsvars.bat'
$env:ROCP_SYNAPSE     = 'C:\Path\To\Synapse\source'
$env:ROCP_ISCC        = 'C:\Path\To\Inno Setup 6\ISCC.exe'
```

## Build نسخه Win64

از ریشه repository:

```powershell
$repo = (Get-Location).Path
cmd /d /s /c "call `"$env:ROCP_RAD_RS_VARS`" && cd /d `"$repo\source`" && msbuild TorControlPanel.dproj /t:Build /p:Config=Release /p:Platform=Win64 /p:DCC_UnitSearchPath=`"$env:ROCP_SYNAPSE`" /v:m"
```

پس از Build، `FileVersion`، `ProductVersion` و `ProductName` فایل `TorControlPanel.exe` باید با Release موردنظر تطابق داشته باشد.

## ساخت بسته Release

ساختار ورودی بسته برای نسخه‌های جدید:

`release\RelayOnionControlPanel-<version>-TorExpertBundle-<tor-bundle>-windows-x64`

قرار دادن `Data\User` عملیاتی، bridge خصوصی، credential، API key خام یا profile واقعی در بسته ممنوع است.

## ساخت Installer

برای نسخه 2.12.0.0:

```powershell
& $env:ROCP_ISCC '.\packaging\inno\RelayOnionControlPanel-2.12.0.0-Tor-15.0.24.iss'
```

مسیرهای ورودی و خروجی Inno script نسبت به repository محاسبه می‌شوند و به مسیر شخصی توسعه‌دهنده وابسته نیستند.

## Qualification

قبل از Stable Release، همه Gateهای سند [`VERSIONING_AND_RELEASE_FA.md`](VERSIONING_AND_RELEASE_FA.md) باید پاس شوند.
