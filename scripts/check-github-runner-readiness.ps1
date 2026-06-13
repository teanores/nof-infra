param(
  [switch]$DocumentationOnly
)

$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$workflow = Join-Path $repoRoot ".github\workflows\release-builder.yml"
$runbook = Join-Path $repoRoot "docs\runbooks\github-runner-release-builder.md"

function Require-FileContains {
  param(
    [string]$Path,
    [string]$Needle
  )

  if (!(Test-Path $Path)) {
    throw "Required file not found: $Path"
  }

  $text = Get-Content $Path -Raw
  if (!$text.Contains($Needle)) {
    throw ("Missing required marker in {0}: {1}" -f $Path, $Needle)
  }
}

Require-FileContains $workflow "workflow_dispatch:"
Require-FileContains $workflow "runs-on: [self-hosted, linux, nof-infra]"
Require-FileContains $workflow "environment: hbl-production"
Require-FileContains $workflow "/opt/nof-release-builder/nof-release-builder.sh deploy"
Require-FileContains $workflow "nof_ht_migration_gate_approved:"
Require-FileContains $runbook "hbl-production"
Require-FileContains $runbook "Do not paste that token into chat, Wiki, tracker or git."
Require-FileContains $runbook "Do not reconfigure the existing product-specific nof-ht runner."
Require-FileContains $runbook "actions.runner.teanores-nof-infra.hbl-runner.service"

if ($DocumentationOnly) {
  Write-Host "github runner readiness: documentation/workflow gates ok"
  Write-Host "github runner readiness: production runner registration not checked"
  exit 0
}

Write-Host "github runner readiness: BLOCKED"
Write-Host "Reason: production runner registration requires a short-lived GitHub runner registration token."
Write-Host "Next: register a separate hbl runner for teanores/nof-infra with labels self-hosted, linux, nof-infra, then re-run production verification."
exit 2
