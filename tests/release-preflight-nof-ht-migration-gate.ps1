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

  & $script `
    -Service nof-ht `
    -ExpectedRef v1.33.51 `
    -Environment $fixtureEnv `
    -ExpectedEnabled true

  $deployment = Join-Path $repoRoot "helm\nof-ht\templates\deployment.yaml"
  $originalDeployment = Get-Content $deployment -Raw
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  try {
    $brokenDeployment = $originalDeployment -replace "            - secretRef:\r?\n                name: nof-ht-habit-bot-secrets\r?\n", ""
    [System.IO.File]::WriteAllText($deployment, $brokenDeployment, $utf8NoBom)

    $failedWithoutHabitBotSecret = $false
    try {
      & $script `
        -Service nof-ht `
        -ExpectedRef v1.33.51 `
        -Environment $fixtureEnv `
        -ExpectedEnabled true
    } catch {
      $failedWithoutHabitBotSecret = $_.Exception.Message -like "*nof-ht-habit-bot-secrets*" -or $_.ToString() -like "*nof-ht-habit-bot-secrets*"
    }

    if (!$failedWithoutHabitBotSecret) {
      throw "Expected nof-ht preflight to fail when nof-ht-habit-bot-secrets wiring is missing"
    }
  } finally {
    [System.IO.File]::WriteAllText($deployment, $originalDeployment, $utf8NoBom)
  }

  $values = Join-Path $repoRoot "helm\nof-ht\values.yaml"
  $originalValues = Get-Content $values -Raw
  try {
    $legacyValues = $originalValues -replace 'telegramHabitBotUsername: "naragothal_bot"', 'telegramHabitBotUsername: "test_elf_nof_bot"'
    if ($legacyValues -eq $originalValues) {
      throw "Test setup failed: naragothal_bot marker was not found in nof-ht values.yaml"
    }
    [System.IO.File]::WriteAllText($values, $legacyValues, $utf8NoBom)

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
      $legacyBotOutput = & powershell.exe `
        -NoLogo `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $script `
        -Service nof-ht `
        -ExpectedRef v1.33.51 `
        -Environment $fixtureEnv `
        -ExpectedEnabled true 2>&1
      $failedWithLegacyBot = $LASTEXITCODE -ne 0
    } finally {
      $ErrorActionPreference = $previousErrorActionPreference
    }

    if (!$failedWithLegacyBot) {
      throw "Expected nof-ht preflight to fail when legacy test_elf_nof_bot is used as shared public NOF bot username"
    }
  } finally {
    [System.IO.File]::WriteAllText($values, $originalValues, $utf8NoBom)
  }

  Write-Host "release-preflight nof-ht release-builder gate: ok"
} finally {
  Remove-Item Env:\NOF_RELEASE_PREFLIGHT_ALLOW_DIRTY_FOR_TESTS -ErrorAction SilentlyContinue
  if (Test-Path $fixtureRoot) {
    Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
  }
}
