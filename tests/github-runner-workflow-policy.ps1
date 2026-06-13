$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$workflow = Join-Path $repoRoot ".github\workflows\release-builder.yml"

if (!(Test-Path $workflow)) {
  throw "Workflow file not found: $workflow"
}

$text = Get-Content $workflow -Raw

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
  "contents: read"
)

foreach ($needle in $required) {
  if (!$text.Contains($needle)) {
    throw "Workflow policy missing required marker: $needle"
  }
}

if ($text -match "(?m)^\s+push:") {
  throw "Production release workflow must not run on push."
}

if ($text -match "(?m)^\s+pull_request:") {
  throw "Production release workflow must not run on pull_request."
}

if ($text -match "runs-on:\s*\[self-hosted,\s*linux,\s*nof-ht\]") {
  throw "Workflow must not use product-specific nof-ht runner label."
}

Write-Host "github runner workflow policy: ok"
