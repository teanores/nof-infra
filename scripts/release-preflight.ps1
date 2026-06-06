param(
  [string] $Service = "nof-tt",
  [string] $ExpectedRef = "v0.2.0",
  [string] $Environment = "hbl"
)

$ErrorActionPreference = "Stop"

function Fail($Message) {
  Write-Error $Message
  exit 1
}

function Info($Message) {
  Write-Host "[release-preflight] $Message"
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

$status = git status --porcelain
if ($status) {
  Fail "nof-infra working tree is not clean. Commit or stash local changes before release preflight."
}

$desiredStatePath = Join-Path $repoRoot "environments\$Environment\desired-state.tsv"
if (!(Test-Path $desiredStatePath)) {
  Fail "Desired-state file not found: $desiredStatePath"
}

$desiredRows = Get-Content $desiredStatePath |
  Where-Object { $_ -and -not $_.StartsWith("#") } |
  ForEach-Object {
    $parts = $_ -split "`t"
    [pscustomobject]@{
      Service = $parts[0]
      Ref = $parts[1]
      Enabled = $parts[2]
    }
  }

$row = $desiredRows | Where-Object { $_.Service -eq $Service } | Select-Object -First 1
if (!$row) {
  Fail "Service '$Service' is missing from $desiredStatePath"
}
if ($row.Ref -ne $ExpectedRef) {
  Fail "Desired-state ref mismatch for ${Service}: expected '$ExpectedRef', got '$($row.Ref)'"
}
if ($row.Enabled -ne "false") {
  Fail "Expected $Service enabled=false before owner-approved production deploy, got '$($row.Enabled)'"
}

$edgeRoot = Join-Path $repoRoot "environments\$Environment\edge"
if (!(Test-Path $edgeRoot)) {
  Fail "Edge target directory not found: $edgeRoot"
}

$edgeText = Get-ChildItem -Path $edgeRoot -Recurse -File | ForEach-Object { Get-Content $_.FullName }
$forbiddenLiveNames = @(
  "forge-tasks.forgath.ru",
  "proxy_pass http://forge-tasks",
  "server_name forge-tasks.forgath.ru"
)
foreach ($name in $forbiddenLiveNames) {
  if ($edgeText -match [regex]::Escape($name)) {
    Fail "Forbidden legacy live edge target found: $name"
  }
}

$secretMarkers = @("PASSWORD=", "TOKEN=", "SECRET=", "PRIVATE KEY", "BEGIN OPENSSH")
foreach ($marker in $secretMarkers) {
  if ($edgeText -match [regex]::Escape($marker)) {
    Fail "Secret-looking marker found in edge target files: $marker"
  }
}

Info "desired-state: $Service -> $ExpectedRef enabled=$($row.Enabled)"
Info "edge targets: no forbidden legacy live hostnames or secret-looking markers found"
Info "preflight completed locally; no hbl/VPS/production commands were run"
