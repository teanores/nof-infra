param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("nof-mp", "nof-tt", "nof-ht")]
  [string] $Service,

  [Parameter(Mandatory = $true)]
  [string] $Ref,

  [ValidateSet("hbl")]
  [string] $Environment = "hbl",

  [ValidateSet("desired-state", "manual-release-builder")]
  [string] $Mode = "desired-state",

  [string[]] $ApprovedServices = @(),

  [switch] $AllowDirty,
  [switch] $NoReport
)

$ErrorActionPreference = "Stop"

function Fail($Message) {
  Write-Error $Message
  exit 1
}

function Info($Message) {
  Write-Host "[release-window] $Message"
}

function Require-SemverTag($Value) {
  if ($Value -notmatch '^v\d+\.\d+\.\d+([.-][0-9A-Za-z.-]+)?$') {
    Fail "Release ref must be a semver tag such as v0.2.35, got '$Value'."
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $repoRoot

Require-SemverTag $Ref

$statusLines = @(git status --porcelain)
if ($statusLines.Count -gt 0 -and !$AllowDirty) {
  Fail "nof-infra working tree is dirty. Re-run with -AllowDirty only for planning reports that do not deploy."
}

$desiredStatePath = Join-Path $repoRoot "environments\$Environment\desired-state.tsv"
if (!(Test-Path $desiredStatePath)) {
  Fail "Desired-state file not found: $desiredStatePath"
}

$desiredRows = Get-Content $desiredStatePath |
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

$row = $desiredRows | Where-Object { $_.Service -eq $Service } | Select-Object -First 1
if (!$row) {
  Fail "Service '$Service' is missing from $desiredStatePath"
}

if ($row.Ref -ne $Ref) {
  Fail "Desired-state ref mismatch for ${Service}: expected '$Ref', got '$($row.Ref)'. Update desired-state first or prepare a manual-release-builder window explicitly."
}

if ($row.Enabled -notin @("true", "false")) {
  Fail "Desired-state enabled value for ${Service} must be true or false, got '$($row.Enabled)'."
}

$normalizedApproved = @($ApprovedServices | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
if ($normalizedApproved.Count -eq 0) {
  $normalizedApproved = @($Service.ToLowerInvariant())
}
if ($normalizedApproved -notcontains $Service.ToLowerInvariant()) {
  Fail "ApprovedServices must include '$Service'."
}

$enabledRows = @($desiredRows | Where-Object { $_.Enabled -eq "true" })
$unexpectedEnabledRows = @($enabledRows | Where-Object { $normalizedApproved -notcontains $_.Service.ToLowerInvariant() })

$safeForDesiredStateAutomation = $true
$stopReasons = New-Object System.Collections.Generic.List[string]

if ($Mode -eq "desired-state" -and $row.Enabled -ne "true") {
  $safeForDesiredStateAutomation = $false
  $stopReasons.Add("Desired-state automation requires $Service enabled=true.")
}

if ($Mode -eq "desired-state" -and $unexpectedEnabledRows.Count -gt 0) {
  $safeForDesiredStateAutomation = $false
  $unexpected = ($unexpectedEnabledRows | ForEach-Object { "$($_.Service)=$($_.Ref)" }) -join ", "
  $stopReasons.Add("Desired-state contains enabled rows outside the approved service list: $unexpected.")
}

if ($Service -eq "nof-ht" -and $Mode -eq "desired-state") {
  $safeForDesiredStateAutomation = $false
  $stopReasons.Add("nof-ht desired-state automation remains blocked until the release-builder migration gate is fully accepted.")
}

if ($statusLines.Count -gt 0) {
  $stopReasons.Add("Working tree has local changes; report generated with AllowDirty=$($AllowDirty.IsPresent).")
}

$approvedList = ($normalizedApproved -join ",")
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path $repoRoot "reports\release-window-$Environment-$Service-$($Ref.TrimStart('v'))-$timestamp.md"

$modeExplanation = if ($Mode -eq "desired-state") {
  "hbl timer/sync may apply the approved desired-state row; no direct deploy command should be used."
} else {
  "agent/operator would invoke release-builder deploy directly after owner approval; this must be reported as manual release-builder mode."
}

$statusText = if ($Mode -eq "desired-state" -and $safeForDesiredStateAutomation) {
  "READY for desired-state automation, pending explicit owner approval."
} elseif ($Mode -eq "manual-release-builder") {
  "READY for manual release-builder briefing, pending explicit owner approval."
} else {
  "BLOCKED for desired-state automation."
}

$enabledSummary = if ($enabledRows.Count -gt 0) {
  ($enabledRows | ForEach-Object { "- $($_.Service) -> $($_.Ref)" }) -join "`n"
} else {
  "- none"
}

$stopSummary = if ($stopReasons.Count -gt 0) {
  ($stopReasons | ForEach-Object { "- $_" }) -join "`n"
} else {
  "- none"
}

$report = @"
# Release Window Preparation

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss zzz")

## Request

- Service: ``$Service``
- Ref: ``$Ref``
- Environment: ``$Environment``
- Mode: ``$Mode``
- Approved services for this window: ``$approvedList``

## Status

$statusText

## Mode Meaning

$modeExplanation

## Desired-State Row

- ``$($row.Service)`` -> ``$($row.Ref)``, enabled=``$($row.Enabled)``

## Currently Enabled Rows

$enabledSummary

## Stop Reasons / Warnings

$stopSummary

## Owner Briefing Draft

I prepared a release window for ``$Service`` ``$Ref``.

Verified locally:
- desired-state contains ``$Service`` at ``$Ref``;
- release ref is a semver tag;
- approved service allowlist for this window is ``$approvedList``;
- no production, hbl, Kubernetes, Helm, Docker or Caddy commands were run by this preparer.

If you approve, the next production action must use exactly this mode: ``$Mode``.

Stop if:
- any service outside ``$approvedList`` is deployed;
- release-builder evidence references a different tag;
- hbl timer runs without ``NOF_RELEASE_SYNC_REQUIRE_APPROVED_SERVICES=1``;
- any secret value appears in logs or evidence.
"@

if (!$NoReport) {
  New-Item -ItemType Directory -Force -Path (Split-Path $reportPath) | Out-Null
  Set-Content -Path $reportPath -Value $report -Encoding utf8
  Info "report: $reportPath"
}

Info "status: $statusText"
if ($stopReasons.Count -gt 0) {
  Info "stop reasons:"
  $stopReasons | ForEach-Object { Write-Host "  - $_" }
}
Info "no production commands were run"
