param(
  [string] $ExpectedNofTtRef = "v0.2.5",
  [string] $Environment = "hbl",
  [ValidateSet("any", "true", "false")]
  [string] $ExpectedNofTtEnabled = "true",
  [switch] $SkipBuilds
)

$ErrorActionPreference = "Stop"

function Info($Message) {
  Write-Host "[release-readiness] $Message"
}

function Fail($Message) {
  Write-Error $Message
  exit 1
}

function RunStep($Title, $Command, $WorkingDirectory) {
  Info $Title
  Push-Location $WorkingDirectory
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -Command $Command
    if ($LASTEXITCODE -ne 0) {
      Fail "$Title failed with exit code $LASTEXITCODE"
    }
  } finally {
    Pop-Location
  }
}

function GitValue($Repo, $GitArgs) {
  $output = & git -C $Repo @GitArgs
  if ($LASTEXITCODE -ne 0) {
    Fail "git $($GitArgs -join ' ') failed in $Repo"
  }
  return ($output -join "`n").Trim()
}

function AssertCleanRepo($Name, $Repo) {
  $status = GitValue $Repo @("status", "--porcelain")
  if ($status) {
    Fail "$Name working tree is not clean"
  }
}

function AssertSyncedRepo($Name, $Repo) {
  $upstream = GitValue $Repo @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
  $counts = GitValue $Repo @("rev-list", "--left-right", "--count", "$upstream...HEAD")
  $parts = $counts -split "\s+"
  $behind = [int]$parts[0]
  $ahead = [int]$parts[1]

  if ($behind -ne 0 -or $ahead -ne 0) {
    Fail "$Name is not synchronized with $upstream (behind=$behind ahead=$ahead)"
  }
}

function RepoSummary($Name, $Repo) {
  [pscustomobject]@{
    Name = $Name
    Branch = GitValue $Repo @("branch", "--show-current")
    Head = GitValue $Repo @("rev-parse", "--short", "HEAD")
    Upstream = GitValue $Repo @("rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{u}")
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$nofRoot = Resolve-Path (Join-Path $repoRoot "..")
$nofMp = Join-Path $nofRoot "nof-mp"
$nofTt = Join-Path $nofRoot "nof-tt"
$nofInfra = $repoRoot.Path

AssertCleanRepo "nof-mp" $nofMp
AssertCleanRepo "nof-tt" $nofTt
AssertCleanRepo "nof-infra" $nofInfra
AssertSyncedRepo "nof-mp" $nofMp
AssertSyncedRepo "nof-tt" $nofTt
AssertSyncedRepo "nof-infra" $nofInfra

$summaries = @(
  (RepoSummary "nof-mp" $nofMp),
  (RepoSummary "nof-tt" $nofTt),
  (RepoSummary "nof-infra" $nofInfra)
)

if (!$SkipBuilds) {
  RunStep "nof-mp check" "npm run check" $nofMp
  RunStep "nof-mp build" "npm run build" $nofMp
  RunStep "nof-tt check" "npm run check" $nofTt
  RunStep "nof-tt build" "npm run build" $nofTt
} else {
  Info "build/check steps skipped by request"
}

RunStep "nof-infra release preflight" ".\scripts\release-preflight.ps1 -Service nof-tt -ExpectedRef $ExpectedNofTtRef -Environment $Environment -ExpectedEnabled $ExpectedNofTtEnabled" $nofInfra

$reportDir = Join-Path $repoRoot "reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path $reportDir "local-release-readiness-$timestamp.md"

$lines = @(
  "# Local Release Readiness - $timestamp",
  "",
  "Status: passed.",
  "Environment: $Environment.",
  "Expected nof-tt ref: $ExpectedNofTtRef.",
  "Expected nof-tt enabled state: $ExpectedNofTtEnabled.",
  "Production actions: none.",
  "Secret values: not read or printed.",
  "",
  "## Repositories",
  "",
  "| Repository | Branch | HEAD | Upstream |",
  "|---|---|---|---|"
)

foreach ($summary in $summaries) {
  $lines += "| $($summary.Name) | $($summary.Branch) | $($summary.Head) | $($summary.Upstream) |"
}

$lines += @(
  "",
  "## Checks",
  "",
  "- Working trees clean before checks.",
  "- Repositories synchronized with their upstream branches before checks.",
  "- nof-mp check/build: $(if ($SkipBuilds) { "skipped" } else { "passed" })",
  "- nof-tt check/build: $(if ($SkipBuilds) { "skipped" } else { "passed" })",
  "- nof-infra release preflight: passed.",
  "",
  "## Remaining Gates",
  "",
  "- Production deploy requires explicit owner approval in the current conversation.",
  "- Owner UAT is required before release acceptance.",
  "- hbl/VPS live diff and smoke checks are not covered by this local report."
)

Set-Content -Path $reportPath -Value $lines -Encoding utf8
Info "report written: $reportPath"
