$ErrorActionPreference = "Stop"

$configPath = Join-Path $PSScriptRoot "..\environments\hbl\edge\portal-gateway-configmap.target.yaml"
$config = Get-Content $configPath -Raw

$platformServerPattern = '(?s)server\s*\{.*?server_name forgath\.ru www\.forgath\.ru _;(?<server>.*?)^\s*\}'
$match = [regex]::Match($config, $platformServerPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
if (-not $match.Success) {
  throw "forgath.ru platform server block is missing in portal-gateway target config."
}

$serverBlock = $match.Groups["server"].Value

if ($serverBlock -notmatch "add_header\s+Content-Security-Policy\s+") {
  throw "forgath.ru must emit enforced Content-Security-Policy."
}

if ($serverBlock -match "add_header\s+Content-Security-Policy-Report-Only\s+") {
  throw "forgath.ru must not emit Content-Security-Policy-Report-Only."
}

if ($serverBlock -notmatch "frame-ancestors 'self'") {
  throw "forgath.ru CSP must keep frame-ancestors restricted to self."
}

$expectedFormAction = "form-action 'self' https://task-tracker.forgath.ru https://habit-tracker.forgath.ru"
if ($serverBlock -notmatch [regex]::Escape($expectedFormAction)) {
  throw "forgath.ru CSP form-action must allow first-party product OAuth callback origins."
}

$taskTrackerServerPattern = '(?s)server\s*\{.*?server_name task-tracker\.forgath\.ru;(?<server>.*?)^\s*\}'
$taskTrackerMatch = [regex]::Match($config, $taskTrackerServerPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
if (-not $taskTrackerMatch.Success) {
  throw "task-tracker.forgath.ru server block is missing in portal-gateway target config."
}

$taskTrackerServerBlock = $taskTrackerMatch.Groups["server"].Value
if ($taskTrackerServerBlock -notmatch "frame-ancestors 'self'") {
  throw "task-tracker.forgath.ru CSP must keep frame-ancestors restricted to self."
}
