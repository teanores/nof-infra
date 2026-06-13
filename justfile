set shell := ["powershell.exe", "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command"]
set quiet := true

default:
  just --list

status:
  git status --short --branch

test:
  .\tests\release-preflight-nof-ht-migration-gate.ps1

check-policy environment="hbl":
  .\scripts\check-desired-state-policy.ps1 -Environment {{environment}}

test-bash-git:
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-sync-allowlist.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-version-policy.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-migration-gate.sh

test-bash-wsl:
  wsl bash -lc "cd /mnt/c/Users/User/Documents/dev/NOF/nof-infra && bash tests/release-builder-version-policy.sh && bash tests/release-builder-migration-gate.sh"

test-all:
  .\tests\release-preflight-nof-ht-migration-gate.ps1
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-sync-allowlist.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-version-policy.sh
  & 'C:\Program Files\Git\bin\bash.exe' tests/release-builder-migration-gate.sh

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
