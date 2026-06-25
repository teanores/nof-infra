$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$workflow = Join-Path $repoRoot ".github\workflows\release-builder.yml"
$decision = Join-Path $repoRoot "docs\decisions\cicd-standard-2026-06-11.md"
$runbook = Join-Path $repoRoot "docs\runbooks\github-runner-release-builder.md"

if (!(Test-Path $workflow)) {
  throw "Workflow file not found: $workflow"
}

$text = Get-Content $workflow -Raw
$decisionText = Get-Content $decision -Raw
$runbookText = Get-Content $runbook -Raw

$required = @(
  "workflow_dispatch:",
  "execute_deploy:",
  "nof_ht_migration_gate_approved:",
  "runs-on: [self-hosted, linux, nof-infra]",
  "environment: hbl-production",
  "/opt/nof-release-builder/nof-release-builder.sh deploy",
  "Release ref must be a semver tag",
  "approval_id is required",
  "nof-ht deploy through nof-infra runner is blocked until migration gate approval is explicit.",
  "permissions:",
  "contents: read",
  'group: nof-release-builder-hbl-${{ inputs.service }}'
)

foreach ($needle in $required) {
  if (!$text.Contains($needle)) {
    throw "Workflow policy missing required marker: $needle"
  }
}

if ($text -match "(?m)^\s+push:") {
  throw "Production release workflow must not run on push."
}

if ($text -match "(?m)^\s+release:") {
  throw "nof-infra production release workflow must not run directly on release events; service repositories dispatch approved requests."
}

if ($text -match "(?m)^\s+pull_request:") {
  throw "Production release workflow must not run on pull_request."
}

if ($text -match "runs-on:\s*\[self-hosted,\s*linux,\s*nof-ht\]") {
  throw "Workflow must not use product-specific nof-ht runner label."
}

if ($text -match "(?m)^\s*group:\s*nof-release-builder-hbl\s*$") {
  throw "Workflow concurrency group must be scoped per service, not globally per hbl."
}

$manualFallbackMarkers = @(
  "Manual release-builder mode is a nof-infra-agent-only fallback.",
  "Product agents must not run direct SSH deploys themselves",
  "Use this fallback only when the owner has explicitly approved manual/emergency mode",
  "standard owner-owned service release trigger or nof-infra GitHub runner path cannot perform the change",
  'owner-facing briefing names the deploy mode as `manual release-builder`'
)

foreach ($needle in $manualFallbackMarkers) {
  if (!$decisionText.Contains($needle) -and !$runbookText.Contains($needle)) {
    throw "Manual fallback standard missing required marker: $needle"
  }
}

Write-Host "github runner workflow policy: ok"
