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
    Write-Host "[edge-audit-token] ssh $SshTarget -- $Command"
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

$secretCommand = "sudo microk8s kubectl get secret nof-mp-security-audit -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf \`"%s length=%d\n\`" `$k (len `$v)}}{{end}}'"
$envCommand = "sudo microk8s kubectl exec -n $Namespace deploy/nof-mp -- sh -c 'printenv | grep `"^NOF_SECURITY_AUDIT_INGEST_TOKEN=`" >/dev/null && echo NOF_SECURITY_AUDIT_INGEST_TOKEN=SET || echo NOF_SECURITY_AUDIT_INGEST_TOKEN=MISSING'"

$secret = Invoke-HblReadOnly $secretCommand
$env = Invoke-HblReadOnly $envCommand

if ($PrintCommandsOnly) {
  Write-Host "[edge-audit-token] commands printed only; no hbl state was read."
  exit 0
}

$secretText = ($secret -join "`n")
$envText = ($env -join "`n")

Write-Host "[edge-audit-token] nof-mp-security-audit keys:"
Write-Host $secretText
Write-Host "[edge-audit-token] nof-mp pod env presence:"
Write-Host $envText

Assert-Contains $secretText "edge-ingest-token length=" "Missing edge-ingest-token in nof-mp-security-audit."

if ($ExpectLiveConfig) {
  Assert-Contains $envText "NOF_SECURITY_AUDIT_INGEST_TOKEN=SET" "nof-mp pod must expose NOF_SECURITY_AUDIT_INGEST_TOKEN after approved deploy."
} elseif (!$envText.Contains("NOF_SECURITY_AUDIT_INGEST_TOKEN=SET")) {
  Write-Host "[edge-audit-token] nof-mp pod does not expose NOF_SECURITY_AUDIT_INGEST_TOKEN yet; this is expected before the approved deploy/restart."
}

Write-Host "[edge-audit-token] metadata-only prerequisites: ok"
Write-Host "[edge-audit-token] secret values were not printed; only key presence and encoded lengths were inspected."
