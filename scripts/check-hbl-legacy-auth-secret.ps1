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
    Write-Host "[legacy-auth-secret] ssh $SshTarget -- $Command"
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

$secretCommand = "sudo microk8s kubectl get secret dragon-forge-secrets -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf \`"%s length=%d\n\`" `$k (len `$v)}}{{end}}'"
$nofMpEnvCommand = "sudo microk8s kubectl exec -n $Namespace deploy/nof-mp -- sh -c 'for k in SECRET_KEY NOF_AUTH_SECRET_KEY SECRET_KEY_PREVIOUS; do printenv `"`${k}`" >/dev/null && echo `"`${k}=SET`" || echo `"`${k}=MISSING`"; done'"
$nofTtEnvCommand = "sudo microk8s kubectl exec -n $Namespace deploy/nof-tt -- sh -c 'printenv SECRET_KEY >/dev/null && echo SECRET_KEY=SET || echo SECRET_KEY=MISSING'"

$secret = Invoke-HblReadOnly $secretCommand
$nofMpEnv = Invoke-HblReadOnly $nofMpEnvCommand
$nofTtEnv = Invoke-HblReadOnly $nofTtEnvCommand

if ($PrintCommandsOnly) {
  Write-Host "[legacy-auth-secret] commands printed only; no hbl state was read."
  exit 0
}

$secretText = ($secret -join "`n")
$nofMpEnvText = ($nofMpEnv -join "`n")
$nofTtEnvText = ($nofTtEnv -join "`n")

Write-Host "[legacy-auth-secret] dragon-forge-secrets keys:"
Write-Host $secretText
Write-Host "[legacy-auth-secret] nof-mp auth env presence:"
Write-Host $nofMpEnvText
Write-Host "[legacy-auth-secret] nof-tt auth env presence:"
Write-Host $nofTtEnvText

Assert-Contains $secretText "SECRET_KEY length=" "Missing SECRET_KEY in dragon-forge-secrets."
Assert-Contains $nofMpEnvText "SECRET_KEY=SET" "nof-mp must expose SECRET_KEY."
Assert-Contains $nofMpEnvText "NOF_AUTH_SECRET_KEY=SET" "nof-mp must expose NOF_AUTH_SECRET_KEY."
Assert-Contains $nofTtEnvText "SECRET_KEY=SET" "nof-tt must expose SECRET_KEY."

if ($ExpectLiveConfig) {
  Assert-Contains $secretText "SECRET_KEY_PREVIOUS length=" "Missing SECRET_KEY_PREVIOUS during approved transition."
  Assert-Contains $nofMpEnvText "SECRET_KEY_PREVIOUS=SET" "nof-mp must expose SECRET_KEY_PREVIOUS during approved transition."
}

Write-Host "[legacy-auth-secret] metadata-only prerequisites: ok"
Write-Host "[legacy-auth-secret] secret values were not printed; only key presence, encoded lengths and env presence were inspected."
