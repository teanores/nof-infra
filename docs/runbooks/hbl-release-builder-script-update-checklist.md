# hbl Release-Builder Script Update Checklist

Status: draft, requires owner approval before use.
Date: 2026-06-11.
Owner: nof-infra / nof-main.

## Purpose

Install the nof-infra release-builder script on hbl after it has been reviewed and pushed to `nof-infra/main`.

This checklist is needed before nof-ht can be tested through the canonical release-builder path.

## Strict Boundary

Do not run this checklist without explicit owner approval in the current conversation.

This checklist updates the hbl release-builder script only. It must not:

- enable nof-ht desired-state;
- run `sync`;
- run `deploy`;
- run a Kubernetes Job;
- run Helm;
- change secrets;
- restart application deployments.

## Preconditions

- nof-infra `main` contains the approved release-builder script.
- `environments/hbl/desired-state.tsv` still keeps `nof-ht` disabled.
- Local tests passed:
  - `tests/release-builder-version-policy.sh`;
  - `tests/release-builder-migration-gate.sh`;
  - `tests/release-preflight-nof-ht-migration-gate.ps1`.
- Owner approved hbl script update.

## Read-Only Discovery

Run first:

```bash
hostname
whoami
ls -l /opt/nof-release-builder/nof-release-builder.sh
/opt/nof-release-builder/nof-release-builder.sh list
systemctl status nof-release-builder-sync.timer --no-pager
systemctl status nof-release-builder-sync.service --no-pager
```

Expected:

- user is the approved hbl admin account;
- script exists;
- list returns `nof-mp`, `nof-tt`, `nof-ht`;
- timer/service state is understood before any file replacement.

## Backup

Create a timestamped backup:

```bash
ts="$(date -u +%Y%m%dT%H%M%SZ)"
sudo cp /opt/nof-release-builder/nof-release-builder.sh "/opt/nof-release-builder/nof-release-builder.sh.backup-$ts"
sudo chmod 700 "/opt/nof-release-builder/nof-release-builder.sh.backup-$ts"
```

Record the backup path in evidence.

## Install

Copy the reviewed script from the local nof-infra checkout or from a clean checkout of `nof-infra/main`.

Required properties:

- owner/root permissions preserved as appropriate for hbl;
- executable bit set so the approved hbl admin account can run read-only verification and the systemd unit can execute the script;
- no secret values copied;
- only `nof-release-builder.sh` is replaced.

Example target command after file is staged on hbl:

```bash
sudo install -m 755 nof-release-builder.sh /opt/nof-release-builder/nof-release-builder.sh
```

## Post-Install Verification

Run:

```bash
/opt/nof-release-builder/nof-release-builder.sh list
NOF_RELEASE_BUILDER_SOURCE_ONLY=1 bash -n /opt/nof-release-builder/nof-release-builder.sh
grep -n "MIGRATION_MODE=\"job\"" /opt/nof-release-builder/nof-release-builder.sh
grep -n "db:migrate:release" /opt/nof-release-builder/nof-release-builder.sh
```

Expected:

- `list` returns `nof-mp`, `nof-tt`, `nof-ht`;
- bash syntax check passes;
- nof-ht migration mode and command are present;
- no deploy/sync command has been run.

## Evidence

Record:

- owner approval text;
- nof-infra commit used;
- backup path;
- script install timestamp;
- `list` output;
- syntax check result;
- confirmation that no deploy/sync/Helm/Kubernetes Job ran.

Do not record:

- GitHub token;
- database URLs;
- Kubernetes secret values;
- private keys.

## Rollback

If list/syntax check fails after install:

```bash
sudo cp "<backup-path>" /opt/nof-release-builder/nof-release-builder.sh
sudo chmod 755 /opt/nof-release-builder/nof-release-builder.sh
/opt/nof-release-builder/nof-release-builder.sh list
```

Stop after rollback and do not run deploy.

## Next Step After Successful Install

Wait for:

- nof-ht final migration compatibility ACK/evidence;
- owner approval for controlled nof-ht release-builder UAT window.

Then use `nof-ht-release-builder-controlled-uat-window.md`.
