$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$fixtureEnv = "test-nof-ht-gate"
$fixtureRoot = Join-Path $repoRoot "environments\$fixtureEnv"
$fixtureDesiredState = Join-Path $fixtureRoot "desired-state.tsv"
$sourceEnv = Join-Path $repoRoot "environments\hbl"

if (Test-Path $fixtureRoot) {
  Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
Copy-Item -Recurse -LiteralPath (Join-Path $sourceEnv "edge") -Destination (Join-Path $fixtureRoot "edge")
@(
  "# service`tgit-ref`tenabled",
  "nof-mp`t v0.2.17`tfalse".Replace("`t ", "`t"),
  "nof-tt`t v0.2.5`tfalse".Replace("`t ", "`t"),
  "nof-ht`t v1.33.51`ttrue".Replace("`t ", "`t")
) | Set-Content -LiteralPath $fixtureDesiredState -Encoding utf8

try {
  $env:NOF_RELEASE_PREFLIGHT_ALLOW_DIRTY_FOR_TESTS = "1"
  $script = Join-Path $repoRoot "scripts\release-preflight.ps1"

  $failedWithoutGate = $false
  try {
    & $script -Service nof-ht -ExpectedRef v1.33.51 -Environment $fixtureEnv -ExpectedEnabled true
  } catch {
    $failedWithoutGate = $_.Exception.Message -like "*NofHtMigrationGateApproved*" -or $_.ToString() -like "*NofHtMigrationGateApproved*"
  }

  if (!$failedWithoutGate) {
    throw "Expected nof-ht preflight to fail without -NofHtMigrationGateApproved"
  }

  & $script `
    -Service nof-ht `
    -ExpectedRef v1.33.51 `
    -Environment $fixtureEnv `
    -ExpectedEnabled true `
    -NofHtMigrationGateApproved `
    -NofHtMigrationEvidence "test-evidence"

  Write-Host "release-preflight nof-ht migration gate: ok"
} finally {
  Remove-Item Env:\NOF_RELEASE_PREFLIGHT_ALLOW_DIRTY_FOR_TESTS -ErrorAction SilentlyContinue
  if (Test-Path $fixtureRoot) {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }
}
