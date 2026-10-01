# Build Instructions

## Requirements

- Windows 10/11 or Windows Server
- Delphi/RAD Studio with VCL Win64 support (Win32 only when that build is required)
- Ararat Synapse sources
- Inno Setup 6 for installer creation

No repository file should depend on a maintainer-specific absolute path. Tool paths are supplied at build time.

## Environment variables

Set these for your workstation:

```powershell
$env:ROCP_RAD_RS_VARS = 'C:\Path\To\Embarcadero\Studio\<version>\bin\rsvars.bat'
$env:ROCP_SYNAPSE     = 'C:\Path\To\Synapse\source'
$env:ROCP_ISCC        = 'C:\Path\To\Inno Setup 6\ISCC.exe'
```

## Delphi Win64 build

From the repository root:

```powershell
$repo = (Get-Location).Path
cmd /d /s /c "call `"$env:ROCP_RAD_RS_VARS`" && cd /d `"$repo\source`" && msbuild TorControlPanel.dproj /t:Build /p:Config=Release /p:Platform=Win64 /p:DCC_UnitSearchPath=`"$env:ROCP_SYNAPSE`" /v:m"
```

Verify the resulting `TorControlPanel.exe` FileVersion/ProductVersion and ProductName before packaging.

## Release package layout

Prepare:

`release\RelayOnionControlPanel-<version>-TorExpertBundle-<tor-bundle>-windows-x64`

The package must contain only distributable application/runtime files. Operational `Data\User`, private bridges, credentials, plaintext API keys and real profiles are prohibited.

## Installer build

For 2.12.0.0:

```powershell
& $env:ROCP_ISCC '.\packaging\inno\RelayOnionControlPanel-2.12.0.0-Tor-15.0.24.iss'
```

The Inno script resolves its release input/output relative to the repository rather than a maintainer workstation path.

## Release qualification

Follow [`VERSIONING_AND_RELEASE.md`](VERSIONING_AND_RELEASE.md) and its Persian counterpart before publishing a stable binary release.
