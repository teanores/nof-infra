param(
  [string] $Service = "nof-tt",
  [string] $ExpectedRef = "v0.2.5",
  [string] $Environment = "hbl",
  [ValidateSet("any", "true", "false")]
  [string] $ExpectedEnabled = "any",
  [string[]] $ApprovedServices = @(),
  [switch] $ApprovedProductionDeploy,
  [switch] $ScopedDeployOnly,
  [switch] $NofHtMigrationGateApproved,
  [string] $NofHtMigrationEvidence = ""
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
if ($status -and $env:NOF_RELEASE_PREFLIGHT_ALLOW_DIRTY_FOR_TESTS -ne "1") {
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
if ($row.Enabled -notin @("true", "false")) {
  Fail "Desired-state enabled value for ${Service} must be 'true' or 'false', got '$($row.Enabled)'"
}
if ($ExpectedEnabled -ne "any" -and $row.Enabled -ne $ExpectedEnabled) {
  Fail "Desired-state enabled mismatch for ${Service}: expected '$ExpectedEnabled', got '$($row.Enabled)'"
}
if ($Service -eq "nof-ht" -and $row.Enabled -eq "true") {
  if (!$NofHtMigrationGateApproved) {
    Fail "nof-ht enabled=true requires -NofHtMigrationGateApproved. nof-ht must not be release-builder deployed until the migration Job gate and nof-ht db:migrate:release evidence are accepted."
  }
  if (!$NofHtMigrationEvidence.Trim()) {
    Fail "nof-ht enabled=true requires -NofHtMigrationEvidence with tracker/wiki/commit evidence for migration readiness."
  }
}
if ($ApprovedProductionDeploy -and $row.Enabled -ne "true") {
  Fail "Expected $Service enabled=true for owner-approved production deploy, got '$($row.Enabled)'"
}
if ($ApprovedProductionDeploy) {
  if ($ApprovedServices.Count -eq 0) {
    Fail "Approved production deploy mode requires -ApprovedServices to prevent accidental broad desired-state sync."
  }
  $normalizedApprovedServices = $ApprovedServices | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ }
  if ($normalizedApprovedServices -notcontains $Service.ToLowerInvariant()) {
    Fail "Service '$Service' is not listed in -ApprovedServices."
  }

  if (!$ScopedDeployOnly) {
    $unexpectedEnabledRows = $desiredRows |
      Where-Object { $_.Enabled -eq "true" -and ($normalizedApprovedServices -notcontains $_.Service.ToLowerInvariant()) }

    if ($unexpectedEnabledRows) {
      $unexpected = ($unexpectedEnabledRows | ForEach-Object { "$($_.Service)=$($_.Ref)" }) -join ", "
      Fail "Desired-state has enabled rows outside approved services: $unexpected"
    }
  } else {
    Info "scoped deploy mode: existing enabled desired-state rows outside $Service are not treated as approval for broad sync"
  }
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

$liveInfraRoots = @(
  (Join-Path $repoRoot "helm"),
  (Join-Path $repoRoot "release-builder"),
  (Join-Path $repoRoot "environments\$Environment")
) | Where-Object { Test-Path $_ }

$liveInfraText = $liveInfraRoots |
  ForEach-Object { Get-ChildItem -Path $_ -Recurse -File } |
  ForEach-Object { Get-Content $_.FullName }

$forbiddenLegacyRuntimeNames = @(
  "FORGE_TASKS_DATABASE_URL",
  "FORGE_TASKS_DB_SCHEMA",
  "FORGE_TASKS_MCP_TOKEN_SECRET",
  "localhost:32000/forge-tasks",
  "RELEASE_NAME=`"forge-tasks`"",
  "SERVICE_NAME=`"forge-tasks`"",
  "name: forge-tasks",
  "app.kubernetes.io/name: forge-tasks"
)
foreach ($name in $forbiddenLegacyRuntimeNames) {
  if ($liveInfraText -match [regex]::Escape($name)) {
    Fail "Forbidden legacy live infra identifier found: $name"
  }
}

if ($Service -eq "nof-ht") {
  $nofHtConfigMap = Join-Path $repoRoot "helm\nof-ht\templates\configmap.yaml"
  $nofHtDeployment = Join-Path $repoRoot "helm\nof-ht\templates\deployment.yaml"
  $nofHtValues = Join-Path $repoRoot "helm\nof-ht\values.yaml"
  $nofHtRunbook = Join-Path $repoRoot "docs\runbooks\hbl-release-builder-migration.md"

  foreach ($requiredFile in @($nofHtConfigMap, $nofHtDeployment, $nofHtValues, $nofHtRunbook)) {
    if (!(Test-Path $requiredFile)) {
      Fail "nof-ht habit-bot preflight file is missing: $requiredFile"
    }
  }

  $nofHtHabitBotMarkers = @(
    [pscustomobject]@{ Path = $nofHtConfigMap; Marker = "NEXT_PUBLIC_TELEGRAM_HABIT_BOT_USERNAME" },
    [pscustomobject]@{ Path = $nofHtValues; Marker = "telegramHabitBotUsername" },
    [pscustomobject]@{ Path = $nofHtDeployment; Marker = "nof-ht-habit-bot-secrets" },
    [pscustomobject]@{ Path = $nofHtRunbook; Marker = "TELEGRAM_HABIT_BOT_TOKEN" },
    [pscustomobject]@{ Path = $nofHtRunbook; Marker = "TELEGRAM_HABIT_BOT_WEBHOOK_SECRET" }
  )

  foreach ($requirement in $nofHtHabitBotMarkers) {
    $fileText = Get-Content $requirement.Path -Raw
    if (!$fileText.Contains($requirement.Marker)) {
      Fail "nof-ht habit-bot preflight marker is missing: $($requirement.Marker)"
    }
  }

  Info "nof-ht habit-bot chart wiring is present; live cluster secret existence still requires release-window verification"
}

Info "desired-state: $Service -> $ExpectedRef enabled=$($row.Enabled)"
if (!$ApprovedProductionDeploy) {
  Info "production deploy approval flag was not set; this was a local guard only"
}
Info "edge targets: no forbidden legacy live hostnames or secret-looking markers found"
Info "live infra targets: no forbidden legacy runtime identifiers found"
Info "preflight completed locally; no hbl/VPS/production commands were run"
