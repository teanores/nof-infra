$ErrorActionPreference = "Stop"

$caddyPath = Join-Path $PSScriptRoot "..\environments\hbl\edge\vps-caddy\Caddyfile.target"
$caddyfile = Get-Content $caddyPath -Raw

if ($caddyfile -notmatch '\(nof_hsts\)\s*\{\s*header\s+Strict-Transport-Security\s+"max-age=31536000"\s*\}') {
  throw "Caddy target must define the shared nof_hsts snippet with a one-year max-age."
}

if ($caddyfile -match "includeSubDomains") {
  throw "Caddy HSTS policy must not include subdomains until each public subdomain is explicitly audited."
}

$canonicalHosts = @(
  "forgath.ru, www.forgath.ru",
  "task-tracker.forgath.ru",
  "habit-tracker.forgath.ru"
)

foreach ($hostname in $canonicalHosts) {
  $escapedHost = [regex]::Escape($hostname)
  $pattern = "(?s)$escapedHost\s*\{.*?import nof_hsts.*?\}"
  if ($caddyfile -notmatch $pattern) {
    throw "$hostname must import the nof_hsts snippet."
  }
}

$legacyBlockMatch = [regex]::Match($caddyfile, '(?s)http://forge-tasks\.forgath\.ru\s*\{(?<block>.*?)^\}', [System.Text.RegularExpressions.RegexOptions]::Multiline)
if (-not $legacyBlockMatch.Success) {
  throw "Legacy forge-tasks.forgath.ru must be explicitly disabled with an HTTP-only 410 response."
}

$legacyBlock = $legacyBlockMatch.Groups["block"].Value

if ($legacyBlock -notmatch 'respond "Legacy Task Tracker hostname is disabled\. Use https://task-tracker\.forgath\.ru/" 410') {
  throw "Legacy forge-tasks.forgath.ru must be explicitly disabled with an HTTP-only 410 response."
}

if ($caddyfile -match '(?m)^forge-tasks\.forgath\.ru\s*\{') {
  throw "Legacy forge-tasks.forgath.ru must not be configured as an HTTPS site."
}

if ($legacyBlock -match 'reverse_proxy') {
  throw "Legacy forge-tasks.forgath.ru must not proxy to any upstream."
}
