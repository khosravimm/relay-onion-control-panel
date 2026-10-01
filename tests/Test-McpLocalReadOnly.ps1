param(
  [string]$BaseUrl = 'http://127.0.0.1:19291/',
  [string]$ProtocolVersion = '2026-07-28',
  [string]$ExpectedProductVersion = ''
)
$ErrorActionPreference = 'Stop'
$temp = Join-Path $env:TEMP ('tcp-mcp-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force $temp | Out-Null
function Invoke-Mcp([string]$Name,[string]$Body,[string[]]$Headers) {
  $in = Join-Path $temp ($Name + '.json')
  $out = Join-Path $temp ($Name + '.out.json')
  [IO.File]::WriteAllText($in,$Body,(New-Object Text.UTF8Encoding($false)))
  $args = @('-sS','-o',$out,'-w','%{http_code}','-X','POST','-H','Content-Type: application/json','-H','Accept: application/json')
  foreach($h in $Headers){ $args += @('-H',$h) }
  $args += @('--data-binary',('@'+$in),$BaseUrl)
  $code = [int](& curl.exe @args)
  $raw = Get-Content $out -Raw
  $json = $null
  try { $json = $raw | ConvertFrom-Json } catch {}
  [pscustomobject]@{name=$Name;http=$code;raw=$raw;json=$json}
}
function Assert-True([bool]$Value,[string]$Message){ if(-not $Value){ throw $Message } }
$meta = '"_meta":{"io.modelcontextprotocol/protocolVersion":"'+$ProtocolVersion+'","io.modelcontextprotocol/clientCapabilities":{},"io.modelcontextprotocol/clientInfo":{"name":"tcp-qualification","version":"1.0"}}'
$pv = 'MCP-Protocol-Version: ' + $ProtocolVersion
$r = @()
$r += Invoke-Mcp 'discover' ('{"jsonrpc":"2.0","id":1,"method":"server/discover","params":{'+$meta+'}}') @($pv,'Mcp-Method: server/discover')
$r += Invoke-Mcp 'tools-list' ('{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{'+$meta+'}}') @($pv,'Mcp-Method: tools/list')
$tools = @('tcp_version','tcp_status','tcp_health')
for($i=0;$i -lt $tools.Count;$i++){
  $tool=$tools[$i]
  $r += Invoke-Mcp ('call-'+$tool) ('{"jsonrpc":"2.0","id":'+(3+$i)+',"method":"tools/call","params":{"name":"'+$tool+'","arguments":{},'+$meta+'}}') @($pv,'Mcp-Method: tools/call',('Mcp-Name: '+$tool))
}
$r += Invoke-Mcp 'negative-no-method-header' ('{"jsonrpc":"2.0","id":6,"method":"tools/list","params":{'+$meta+'}}') @($pv)
$r += Invoke-Mcp 'negative-call-no-name' ('{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"tcp_version","arguments":{},'+$meta+'}}') @($pv,'Mcp-Method: tools/call')
$r += Invoke-Mcp 'negative-no-meta' '{"jsonrpc":"2.0","id":8,"method":"server/discover","params":{}}' @($pv,'Mcp-Method: server/discover')

$discover=$r|Where-Object name -eq 'discover'
Assert-True ($discover.http -eq 200 -and $null -ne $discover.json.result) 'server/discover did not return a successful result'
Assert-True (@($discover.json.result.supportedVersions) -contains $ProtocolVersion) 'server/discover did not advertise the target protocol version'
$list=$r|Where-Object name -eq 'tools-list'
Assert-True ($list.http -eq 200 -and $null -ne $list.json.result) 'tools/list did not return a successful result'
$names=@($list.json.result.tools|ForEach-Object {$_.name}|Sort-Object)
$expected=@($tools|Sort-Object)
Assert-True (($names -join ',') -eq ($expected -join ',')) ('unexpected tool set: '+($names -join ','))
Assert-True (@($list.json.result.tools|Where-Object {-not $_.annotations.readOnlyHint}).Count -eq 0) 'a listed tool is not marked read-only'
foreach($tool in $tools){$x=$r|Where-Object name -eq ('call-'+$tool);Assert-True ($x.http -eq 200 -and $null -ne $x.json.result) ($tool+' call failed')}
if($ExpectedProductVersion){$v=($r|Where-Object name -eq 'call-tcp_version').json.result.content[0].text|ConvertFrom-Json;Assert-True ($v.version -eq $ExpectedProductVersion) ('version mismatch: '+$v.version)}
$n1=$r|Where-Object name -eq 'negative-no-method-header';Assert-True ($n1.http -eq 400 -and $n1.json.error.code -eq -32020) 'missing Mcp-Method did not fail closed'
$n2=$r|Where-Object name -eq 'negative-call-no-name';Assert-True ($n2.http -eq 400 -and $n2.json.error.code -eq -32020) 'missing Mcp-Name did not fail closed'
$n3=$r|Where-Object name -eq 'negative-no-meta';Assert-True ($n3.http -eq 400 -and $n3.json.error.code -eq -32602) 'missing _meta did not fail closed'
$summary=[ordered]@{status='PASS';base_url=$BaseUrl;protocol_version=$ProtocolVersion;tool_names=$names;tool_count=$names.Count;write_like_count=@($names|Where-Object {$_ -match 'add|set|delete|remove|change|start|stop|restart|write|update|create'}).Count;results=@($r|ForEach-Object {[ordered]@{name=$_.name;http=$_.http;has_result=($null -ne $_.json.result);error_code=$(if($null -ne $_.json.error){$_.json.error.code}else{$null})}})}
$summary|ConvertTo-Json -Depth 8
Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
