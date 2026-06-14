param(
  [string]$SshTarget = "nofadminhbl@192.168.1.51",
  [string]$Namespace = "nof-apps",
  [switch]$PrintCommandsOnly
)

$ErrorActionPreference = "Stop"

function Invoke-HblReadOnly {
  param([string]$Command)

  if ($PrintCommandsOnly) {
    Write-Host "[hbl-bot-prereqs] ssh $SshTarget -- $Command"
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

$sentinelSecretCommand = "sudo microk8s kubectl get secret nof-ht-secrets -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf ""%s length=%d\n"" `$k (len `$v)}}{{end}}'"
$habitSecretCommand = "sudo microk8s kubectl get secret nof-ht-habit-bot-secrets -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf ""%s length=%d\n"" `$k (len `$v)}}{{end}}'"
$configCommand = "sudo microk8s kubectl get configmap nof-ht-config -n $Namespace -o go-template='{{range `$k,`$v := .data}}{{printf ""%s=%s\n"" `$k `$v}}{{end}}'"

$sentinelSecret = Invoke-HblReadOnly $sentinelSecretCommand
$habitSecret = Invoke-HblReadOnly $habitSecretCommand
$config = Invoke-HblReadOnly $configCommand

if ($PrintCommandsOnly) {
  Write-Host "[hbl-bot-prereqs] commands printed only; no hbl state was read."
  exit 0
}

$sentinelText = ($sentinelSecret -join "`n")
$habitText = ($habitSecret -join "`n")
$configText = ($config -join "`n")

Assert-Contains $sentinelText "TELEGRAM_NOF_SENTINEL_BOT_TOKEN length=" "Missing TELEGRAM_NOF_SENTINEL_BOT_TOKEN in nof-ht-secrets."
Assert-Contains $sentinelText "TELEGRAM_NOF_SENTINEL_BOT_WEBHOOK_SECRET length=" "Missing TELEGRAM_NOF_SENTINEL_BOT_WEBHOOK_SECRET in nof-ht-secrets."
Assert-Contains $habitText "TELEGRAM_HABIT_BOT_TOKEN length=" "Missing TELEGRAM_HABIT_BOT_TOKEN in nof-ht-habit-bot-secrets."
Assert-Contains $habitText "TELEGRAM_HABIT_BOT_WEBHOOK_SECRET length=" "Missing TELEGRAM_HABIT_BOT_WEBHOOK_SECRET in nof-ht-habit-bot-secrets."
Assert-Contains $configText "NEXT_PUBLIC_TELEGRAM_HABIT_BOT_USERNAME=naragothal_bot" "nof-ht ConfigMap must point product bot username to naragothal_bot."
Assert-Contains $configText "NEXT_PUBLIC_TELEGRAM_BOT_USERNAME=nof_sentinel_bot" "nof-ht ConfigMap must point linking/sentinel username to nof_sentinel_bot."

Write-Host "[hbl-bot-prereqs] nof-ht bot prerequisites: ok"
Write-Host "[hbl-bot-prereqs] secret values were not printed; only key presence and encoded lengths were inspected."
