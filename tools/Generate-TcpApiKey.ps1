param(
  [string]$SettingsPath = ".\Data\User\settings.ini",
  [int]$Bytes = 32,
  [switch]$ShowPlainTextKey
)
$ErrorActionPreference = 'Stop'
if ($Bytes -lt 16) { throw 'API key must be at least 16 random bytes.' }
if (!(Test-Path $SettingsPath)) { throw "Settings file not found: $SettingsPath" }
function Convert-ToBase64Url([byte[]]$BytesValue) {
  [Convert]::ToBase64String($BytesValue).TrimEnd('=').Replace('+','-').Replace('/','_')
}
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$keyBytes = New-Object byte[] $Bytes
$rng.GetBytes($keyBytes)
$key = Convert-ToBase64Url $keyBytes
$sha = [System.Security.Cryptography.SHA256]::Create()
$hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($key))
$hashHex = -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
$keyId = 'tcp_' + (Get-Date -Format 'yyyyMMddHHmmss')
$created = (Get-Date).ToString('o')
$content = Get-Content $SettingsPath -Raw -Encoding UTF8
if ($content -notmatch '(?m)^\[Api\]') { $content += "`r`n[Api]`r`n" }
function Set-IniValue([string]$Text,[string]$Section,[string]$Name,[string]$Value) {
  $sectionPattern = "(?ms)^\[$([regex]::Escape($Section))\].*?(?=^\[|\z)"
  $m = [regex]::Match($Text,$sectionPattern)
  if(!$m.Success){ return $Text.TrimEnd() + "`r`n[$Section]`r`n$Name=$Value`r`n" }
  $block = $m.Value
  if($block -match "(?m)^$([regex]::Escape($Name))=") {
    $block2 = [regex]::Replace($block,"(?m)^$([regex]::Escape($Name))=.*$","$Name=$Value")
  } else {
    $block2 = $block.TrimEnd() + "`r`n$Name=$Value`r`n"
  }
  return $Text.Remove($m.Index,$m.Length).Insert($m.Index,$block2)
}
$content = Set-IniValue $content 'Api' 'KeyId' $keyId
$content = Set-IniValue $content 'Api' 'KeyHash' $hashHex
$content = Set-IniValue $content 'Api' 'KeyCreatedAt' $created
$content = Set-IniValue $content 'Api' 'RequireKeyForRemote' '1'
$content = Set-IniValue $content 'Api' 'RequireKeyForLoopback' '0'
Set-Content $SettingsPath -Value $content -Encoding UTF8
Write-Host "API key generated."
Write-Host "KeyId: $keyId"
Write-Host "KeyHash: $hashHex"
Write-Host "SettingsPath: $SettingsPath"
Write-Host "Loopback policy: 127.0.0.1 does not require a key by default."
Write-Host "Remote policy: non-loopback access requires a key."
if($ShowPlainTextKey){
  Write-Host "PlainTextKey: $key"
} else {
  Write-Host "PlainTextKey: hidden. Re-run with -ShowPlainTextKey only at creation time if you need to copy it."
}
