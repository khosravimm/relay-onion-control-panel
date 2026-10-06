param(
    [string]$Version = '1.14.2',
    [string]$Destination = ''
)

$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($Destination)) {
    $Destination = Join-Path $repo 'release\RelayOnionControlPanel-2.12.0.0-TorExpertBundle-15.0.24-windows-x64\optional\sing-box'
}

$known = @{
    '1.14.2' = @{
        Url = 'https://github.com/SagerNet/sing-box/releases/download/v1.14.2/sing-box-1.14.2-windows-amd64.zip'
        Sha256 = 'C2D8BFFF918755808781DFDEEB8581B6C91EB3A243D9A7B55483CFC0C0684D32'
    }
}

if (-not $known.ContainsKey($Version)) {
    throw "Unqualified sing-box version: $Version"
}

$meta = $known[$Version]
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("rocp-sing-box-" + [guid]::NewGuid().ToString('N'))
$zip = Join-Path $tempRoot 'sing-box.zip'
$extract = Join-Path $tempRoot 'extract'

try {
    New-Item -ItemType Directory -Force $tempRoot, $extract, $Destination | Out-Null
    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    if ($curl) {
        & $curl.Source --fail --location --connect-timeout 30 --max-time 300 --retry 3 --retry-delay 2 --output $zip $meta.Url
        if ($LASTEXITCODE -ne 0) {
            throw "curl.exe failed to download sing-box archive (exit code $LASTEXITCODE)"
        }
    }
    else {
        Invoke-WebRequest -UseBasicParsing $meta.Url -OutFile $zip -TimeoutSec 300
    }

    $actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToUpperInvariant()
    if ($actual -ne $meta.Sha256) {
        throw "sing-box archive SHA-256 mismatch. Expected $($meta.Sha256), got $actual"
    }

    Expand-Archive -Path $zip -DestinationPath $extract -Force
    $root = Get-ChildItem $extract -Directory | Select-Object -First 1
    if (-not $root) { throw 'Unexpected sing-box archive layout' }

    $exe = Join-Path $root.FullName 'sing-box.exe'
    $license = Join-Path $root.FullName 'LICENSE'
    if (-not (Test-Path $exe)) { throw 'sing-box.exe not found in archive' }
    if (-not (Test-Path $license)) { throw 'sing-box LICENSE not found in archive' }

    Copy-Item $exe (Join-Path $Destination 'sing-box.exe') -Force
    Copy-Item $license (Join-Path $Destination 'LICENSE') -Force
    @(
        "sing-box version: $Version"
        "archive SHA-256: $($meta.Sha256)"
        "upstream: https://github.com/SagerNet/sing-box"
        "license: GPL-3.0-or-later (see LICENSE)"
    ) | Set-Content -Encoding UTF8 (Join-Path $Destination 'VERSION.txt')

    & (Join-Path $Destination 'sing-box.exe') version
}
finally {
    Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
