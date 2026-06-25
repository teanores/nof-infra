param(
  [ValidateSet("hbl")]
  [string] $Environment = "hbl"
)

$ErrorActionPreference = "Stop"

function Fail($Message) {
  Write-Error $Message
  exit 1
}

function Info($Message) {
  Write-Host "[desired-state-policy] $Message"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$desiredStatePath = Join-Path $repoRoot "environments\$Environment\desired-state.tsv"
if (!(Test-Path $desiredStatePath)) {
  Fail "Desired-state file not found: $desiredStatePath"
}

$rows = Get-Content $desiredStatePath |
  Where-Object { $_ -and -not $_.StartsWith("#") } |
  ForEach-Object {
    $parts = $_ -split "`t"
    if ($parts.Count -ne 3) {
      Fail "Invalid desired-state row: $_"
    }
    [pscustomobject]@{
      Service = $parts[0]
      Ref = $parts[1]
      Enabled = $parts[2]
    }
  }

$knownServices = @("nof-mp", "nof-tt", "nof-ht")
$seen = @{}
foreach ($row in $rows) {
  if ($knownServices -notcontains $row.Service) {
    Fail "Unknown service key in desired-state: $($row.Service)"
  }
  if ($seen.ContainsKey($row.Service)) {
    Fail "Duplicate service row in desired-state: $($row.Service)"
  }
  $seen[$row.Service] = $true
  if ($row.Ref -notmatch '^v\d+\.\d+\.\d+([.-][0-9A-Za-z.-]+)?$') {
    Fail "Service $($row.Service) must use a semver tag ref, got '$($row.Ref)'."
  }
  if ($row.Enabled -notin @("true", "false")) {
    Fail "Service $($row.Service) enabled must be true or false, got '$($row.Enabled)'."
  }
}

foreach ($service in $knownServices) {
  if (!$seen.ContainsKey($service)) {
    Fail "Missing service row in desired-state: $service"
  }
}

$enabledRows = @($rows | Where-Object { $_.Enabled -eq "true" })
if ($enabledRows.Count -gt 1) {
  $enabled = ($enabledRows | ForEach-Object { "$($_.Service)=$($_.Ref)" }) -join ", "
  Fail "Routine desired-state policy allows at most one enabled service row by default. Enabled rows: $enabled"
}

Info "desired-state policy ok for $Environment"
