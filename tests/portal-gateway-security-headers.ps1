$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "..\environments\hbl\edge\portal-gateway-configmap.target.yaml"
$config = Get-Content $configPath -Raw

$taskTrackerServerPattern = '(?s)server\s*\{.*?server_name task-tracker\.forgath\.ru;(?<server>.*?)^\s*\}'
$match = [regex]::Match($config, $taskTrackerServerPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
if (-not $match.Success) {
  throw "task-tracker.forgath.ru server block is missing in portal-gateway target config."
}

$serverBlock = $match.Groups["server"].Value

if ($serverBlock -notmatch "add_header\s+Content-Security-Policy\s+") {
  throw "task-tracker.forgath.ru must emit enforced Content-Security-Policy."
}

if ($serverBlock -match "add_header\s+Content-Security-Policy-Report-Only\s+") {
  throw "task-tracker.forgath.ru must not emit Content-Security-Policy-Report-Only."
}

if ($serverBlock -notmatch "proxy_hide_header\s+Content-Security-Policy-Report-Only;") {
  throw "task-tracker.forgath.ru must hide upstream Content-Security-Policy-Report-Only."
}

if ($serverBlock -notmatch "frame-ancestors 'self'") {
  throw "task-tracker.forgath.ru CSP must keep frame-ancestors restricted to self."
}
