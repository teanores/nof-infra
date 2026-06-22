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
    Write-Host "[platform-oauth] ssh $SshTarget -- $Command"
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

$nofMpSecretCommand = "sudo microk8s kubectl get secret nof-mp-oauth-secrets -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf \`"%s length=%d\n\`" `$k (len `$v)}}{{end}}'"
$nofTtSecretCommand = "sudo microk8s kubectl get secret nof-tt-oauth-secrets -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf \`"%s length=%d\n\`" `$k (len `$v)}}{{end}}'"
$nofHtSecretCommand = "sudo microk8s kubectl get secret nof-ht-oauth-secrets -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf \`"%s length=%d\n\`" `$k (len `$v)}}{{end}}'"
$nofMpEnvCommand = "sudo microk8s kubectl exec -n $Namespace deploy/nof-mp -- sh -c 'for k in NOF_PLATFORM_OAUTH_JWT_SECRET NOF_PLATFORM_OAUTH_CLIENT_SECRET_SHA256_NOF_TT NOF_PLATFORM_OAUTH_CLIENT_SECRET_SHA256_NOF_HT; do printenv `"`${k}`" >/dev/null && echo `"`${k}=SET`" || echo `"`${k}=MISSING`"; done'"
$nofTtEnvCommand = "sudo microk8s kubectl exec -n $Namespace deploy/nof-tt -- sh -c 'for k in NOF_PLATFORM_OAUTH_JWT_SECRET NOF_TT_OAUTH_CLIENT_SECRET; do printenv `"`${k}`" >/dev/null && echo `"`${k}=SET`" || echo `"`${k}=MISSING`"; done'"
$nofHtEnvCommand = "sudo microk8s kubectl exec -n $Namespace deploy/nof-ht -- sh -c 'printenv | grep `"OAUTH`" | sed -E `"s/=.*/=SET/`"'"

$nofMpSecret = Invoke-HblReadOnly $nofMpSecretCommand
$nofTtSecret = Invoke-HblReadOnly $nofTtSecretCommand
$nofHtSecret = Invoke-HblReadOnly $nofHtSecretCommand
$nofMpEnv = Invoke-HblReadOnly $nofMpEnvCommand
$nofTtEnv = Invoke-HblReadOnly $nofTtEnvCommand
$nofHtEnv = Invoke-HblReadOnly $nofHtEnvCommand

if ($PrintCommandsOnly) {
  Write-Host "[platform-oauth] commands printed only; no hbl state was read."
  exit 0
}

$nofMpSecretText = ($nofMpSecret -join "`n")
$nofTtSecretText = ($nofTtSecret -join "`n")
$nofHtSecretText = ($nofHtSecret -join "`n")
$nofMpEnvText = ($nofMpEnv -join "`n")
$nofTtEnvText = ($nofTtEnv -join "`n")
$nofHtEnvText = ($nofHtEnv -join "`n")

Write-Host "[platform-oauth] nof-mp-oauth-secrets keys:"
Write-Host $nofMpSecretText
Write-Host "[platform-oauth] nof-tt-oauth-secrets keys:"
Write-Host $nofTtSecretText
Write-Host "[platform-oauth] nof-ht-oauth-secrets keys:"
Write-Host $nofHtSecretText
Write-Host "[platform-oauth] nof-mp OAuth env presence:"
Write-Host $nofMpEnvText
Write-Host "[platform-oauth] nof-tt OAuth env presence:"
Write-Host $nofTtEnvText
Write-Host "[platform-oauth] nof-ht OAuth env presence:"
Write-Host $nofHtEnvText

Assert-Contains $nofMpSecretText "NOF_PLATFORM_OAUTH_JWT_SECRET length=" "Missing NOF_PLATFORM_OAUTH_JWT_SECRET in nof-mp-oauth-secrets."
Assert-Contains $nofMpSecretText "NOF_PLATFORM_OAUTH_CLIENT_SECRET_SHA256_NOF_TT length=" "Missing nof-tt client hash in nof-mp-oauth-secrets."
Assert-Contains $nofMpSecretText "NOF_PLATFORM_OAUTH_CLIENT_SECRET_SHA256_NOF_HT length=" "Missing nof-ht client hash in nof-mp-oauth-secrets."
Assert-Contains $nofTtSecretText "NOF_PLATFORM_OAUTH_JWT_SECRET length=" "Missing NOF_PLATFORM_OAUTH_JWT_SECRET in nof-tt-oauth-secrets."
Assert-Contains $nofTtSecretText "NOF_TT_OAUTH_CLIENT_SECRET length=" "Missing NOF_TT_OAUTH_CLIENT_SECRET in nof-tt-oauth-secrets."

if ($ExpectLiveConfig) {
  Assert-Contains $nofHtSecretText "NOF_PLATFORM_OAUTH_JWT_SECRET length=" "Missing NOF_PLATFORM_OAUTH_JWT_SECRET in nof-ht-oauth-secrets."
}

Write-Host "[platform-oauth] metadata-only prerequisites: ok"
Write-Host "[platform-oauth] secret values and hashes were not printed; only key presence, encoded lengths and env presence were inspected."
