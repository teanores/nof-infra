set shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
set quiet := true

default:
  just --list

status:
  git status --short --branch

test:
  .\tests\release-preflight-nof-ht-migration-gate.ps1
  .\tests\portal-gateway-security-headers.ps1
  .\tests\caddy-hsts-policy.ps1
  .\tests\github-runner-workflow-policy.ps1
  .\scripts\check-github-runner-readiness.ps1 -DocumentationOnly
  .\scripts\check-hbl-nof-ht-bot-prereqs.ps1 -PrintCommandsOnly
  .\scripts\check-hbl-edge-audit-token-prereqs.ps1 -PrintCommandsOnly
  .\scripts\check-hbl-postgres-secret-split-prereqs.ps1 -PrintCommandsOnly

check-policy environment="hbl":
  .\scripts\check-desired-state-policy.ps1 -Environment {{environment}}

check-runner-workflow:
  .\scripts\check-github-runner-readiness.ps1 -DocumentationOnly

check-runner-production:
  .\scripts\check-github-runner-readiness.ps1

check-ht-bot-prereqs-dry-run:
  .\scripts\check-hbl-nof-ht-bot-prereqs.ps1 -PrintCommandsOnly

check-ht-bot-prereqs:
  .\scripts\check-hbl-nof-ht-bot-prereqs.ps1

check-ht-bot-live:
  .\scripts\check-hbl-nof-ht-bot-prereqs.ps1 -ExpectLiveConfig

check-edge-audit-token-dry-run:
  .\scripts\check-hbl-edge-audit-token-prereqs.ps1 -PrintCommandsOnly

check-edge-audit-token:
  .\scripts\check-hbl-edge-audit-token-prereqs.ps1

check-edge-audit-token-live:
  .\scripts\check-hbl-edge-audit-token-prereqs.ps1 -ExpectLiveConfig

check-postgres-secret-split-dry-run:
  .\scripts\check-hbl-postgres-secret-split-prereqs.ps1 -PrintCommandsOnly

check-postgres-secret-split:
  .\scripts\check-hbl-postgres-secret-split-prereqs.ps1

check-postgres-secret-split-live:
  .\scripts\check-hbl-postgres-secret-split-prereqs.ps1 -ExpectLiveConfig

test-bash-git:
  & 'C:\Program Files\Git\bin\bash.exe' -n scripts/hbl-install-nof-infra-github-runner.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-sync-allowlist.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-version-policy.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-migration-gate.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-manual-guardrails.sh

test-bash-wsl:
  wsl bash -lc "cd /mnt/c/Users/User/Documents/dev/NOF/nof-infra && bash -n scripts/hbl-install-nof-infra-github-runner.sh && bash tests/release-builder-version-policy.sh && bash tests/release-builder-migration-gate.sh"

test-all:
  .\tests\release-preflight-nof-ht-migration-gate.ps1
  .\tests\portal-gateway-security-headers.ps1
  .\tests\caddy-hsts-policy.ps1
  .\tests\github-runner-workflow-policy.ps1
  .\scripts\check-github-runner-readiness.ps1 -DocumentationOnly
  .\scripts\check-hbl-nof-ht-bot-prereqs.ps1 -PrintCommandsOnly
  .\scripts\check-hbl-edge-audit-token-prereqs.ps1 -PrintCommandsOnly
  .\scripts\check-hbl-postgres-secret-split-prereqs.ps1 -PrintCommandsOnly
  & 'C:\Program Files\Git\bin\bash.exe' -n scripts/hbl-install-nof-infra-github-runner.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-sync-allowlist.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-version-policy.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-migration-gate.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-manual-guardrails.sh

preflight service ref environment="hbl":
  .\scripts\release-preflight.ps1 -Service {{service}} -ExpectedRef {{ref}} -Environment {{environment}}

prepare-release service ref mode="desired-state" environment="hbl":
  .\scripts\prepare-release-window.ps1 -Service {{service}} -Ref {{ref}} -Mode {{mode}} -Environment {{environment}}

prepare-release-dirty service ref mode="desired-state" environment="hbl":
  .\scripts\prepare-release-window.ps1 -Service {{service}} -Ref {{ref}} -Mode {{mode}} -Environment {{environment}} -AllowDirty

readiness nof_mp_ref nof_tt_ref nof_ht_ref environment="hbl":
  .\scripts\local-release-readiness.ps1 -ExpectedNofMpRef {{nof_mp_ref}} -ExpectedNofTtRef {{nof_tt_ref}} -ExpectedNofHtRef {{nof_ht_ref}} -Environment {{environment}}

hbl-list:
  ssh nofadminhbl@192.168.1.51 "/opt/nof-release-builder/nof-release-builder.sh list"

deploy-approved service ref:
  if ($env:NOF_OWNER_APPROVED_DEPLOY -ne '1') { Write-Error 'Refusing deploy: set NOF_OWNER_APPROVED_DEPLOY=1 only after explicit current-chat owner approval.'; exit 1 }
  ssh nofadminhbl@192.168.1.51 "/opt/nof-release-builder/nof-release-builder.sh deploy {{service}} {{ref}}"
