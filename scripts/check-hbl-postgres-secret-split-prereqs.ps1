param(
  [string]$SshTarget = "nofadminhbl@192.168.1.51",
  [string]$Namespace = "nof-apps",
  [switch]$ExpectLiveConfig,
  [switch]$PrintCommandsOnly
)

$ErrorActionPreference = "Stop"

function Invoke-HblReadOnly {
  param([string]$Command)

  if ($PrintCommandsOnly) {
    Write-Host "[postgres-secret-split] ssh $SshTarget -- $Command"
    return ""
  }

  ssh $SshTarget $Command
}

function Assert-Contains {
  param(
    [string]$Text,
    [string]$Needle,
    [string]$Message
  )

  if (!$Text.Contains($Needle)) {
    throw $Message
  }
}

$sharedSecretCommand = "sudo microk8s kubectl get secret postgres-secret -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf \`"%s length=%d\n\`" `$k (len `$v)}}{{end}}'"
$nofMpSecretCommand = "sudo microk8s kubectl get secret nof-mp-postgres-secret -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf \`"%s length=%d\n\`" `$k (len `$v)}}{{end}}'"
$nofTtSecretCommand = "sudo microk8s kubectl get secret nof-tt-postgres-secret -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf \`"%s length=%d\n\`" `$k (len `$v)}}{{end}}'"
$nofMpEnvCommand = "sudo microk8s kubectl exec -n $Namespace deploy/nof-mp -- sh -c 'for k in DB_USER DB_PASS DB_NAME; do printenv `"`${k}`" >/dev/null && echo `"`${k}=SET`" || echo `"`${k}=MISSING`"; done'"
$nofTtEnvCommand = "sudo microk8s kubectl exec -n $Namespace deploy/nof-tt -- sh -c 'for k in DB_USER DB_PASS DB_NAME; do printenv `"`${k}`" >/dev/null && echo `"`${k}=SET`" || echo `"`${k}=MISSING`"; done'"
$roleCommand = "sudo microk8s kubectl exec -n $Namespace statefulset/postgres -- psql -U postgres -d postgres -Atc `"select rolname from pg_roles where rolname in ('nof_mp_runtime','nof_tt_runtime') order by rolname;`""

$sharedSecret = Invoke-HblReadOnly $sharedSecretCommand
$nofMpSecret = Invoke-HblReadOnly $nofMpSecretCommand
$nofTtSecret = Invoke-HblReadOnly $nofTtSecretCommand
$nofMpEnv = Invoke-HblReadOnly $nofMpEnvCommand
$nofTtEnv = Invoke-HblReadOnly $nofTtEnvCommand
$roles = Invoke-HblReadOnly $roleCommand

if ($PrintCommandsOnly) {
  Write-Host "[postgres-secret-split] commands printed only; no hbl state was read."
  exit 0
}

$sharedSecretText = ($sharedSecret -join "`n")
$nofMpSecretText = ($nofMpSecret -join "`n")
$nofTtSecretText = ($nofTtSecret -join "`n")
$nofMpEnvText = ($nofMpEnv -join "`n")
$nofTtEnvText = ($nofTtEnv -join "`n")
$roleText = ($roles -join "`n")

Write-Host "[postgres-secret-split] postgres-secret keys:"
Write-Host $sharedSecretText
Write-Host "[postgres-secret-split] nof-mp-postgres-secret keys:"
Write-Host $nofMpSecretText
Write-Host "[postgres-secret-split] nof-tt-postgres-secret keys:"
Write-Host $nofTtSecretText
Write-Host "[postgres-secret-split] nof-mp DB env presence:"
Write-Host $nofMpEnvText
Write-Host "[postgres-secret-split] nof-tt DB env presence:"
Write-Host $nofTtEnvText
Write-Host "[postgres-secret-split] target role names:"
Write-Host $roleText

Assert-Contains $sharedSecretText "postgres-user length=" "Missing postgres-user in shared postgres-secret."
Assert-Contains $sharedSecretText "postgres-password length=" "Missing postgres-password in shared postgres-secret."
Assert-Contains $sharedSecretText "postgres-db length=" "Missing postgres-db in shared postgres-secret."

if ($ExpectLiveConfig) {
  Assert-Contains $nofMpSecretText "postgres-user length=" "Missing postgres-user in nof-mp-postgres-secret."
  Assert-Contains $nofMpSecretText "postgres-password length=" "Missing postgres-password in nof-mp-postgres-secret."
  Assert-Contains $nofMpSecretText "postgres-db length=" "Missing postgres-db in nof-mp-postgres-secret."
  Assert-Contains $nofTtSecretText "postgres-user length=" "Missing postgres-user in nof-tt-postgres-secret."
  Assert-Contains $nofTtSecretText "postgres-password length=" "Missing postgres-password in nof-tt-postgres-secret."
  Assert-Contains $nofTtSecretText "postgres-db length=" "Missing postgres-db in nof-tt-postgres-secret."
}

Write-Host "[postgres-secret-split] metadata-only prerequisites: ok"
Write-Host "[postgres-secret-split] secret values were not printed; only key presence, encoded lengths and role names were inspected."
