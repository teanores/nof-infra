# hbl Release Builder Migration

Status: draft.
Purpose: move hbl release control from legacy `nof-platform-hybrid` to `nof-infra`.

## Current hbl State

Read-only discovery on 2026-06-05 found:

- systemd service: `nof-release-builder-sync.service`
- timer: `nof-release-builder-sync.timer`, every 5 minutes
- service command: `/opt/nof-release-builder/nof-release-builder.sh sync main`
- default control repo in script: `https://github.com/teanores/nof-platform-hybrid.git`
- default control manifest: `ops/release-builder/desired-state.tsv`
- GitHub Actions runner service: `actions.runner.teanores-nof-ht.hbl-runner.service`
- active legacy Helm releases: `nof-platform`, `forge-tasks`
- active legacy images: `localhost:32000/nof-platform:*`, `localhost:32000/forge-tasks:*`

## Target State

- control repo: `https://github.com/teanores/nof-infra.git`
- control manifest: `environments/hbl/desired-state.tsv`
- release-builder service keys: `nof-mp`, `nof-tt`, `nof-ht`
- Helm releases: `nof-mp`, `nof-tt`, `nof-ht`
- images: `localhost:32000/nof-mp:*`, `localhost:32000/nof-tt:*`, `localhost:32000/nof-ht:*`
- public Task Tracker host: `task-tracker.forgath.ru`
- OAuth secret resource names: `nof-mp-oauth-secrets`, `nof-tt-oauth-secrets`, `nof-ht-oauth-secrets`

## Owner Approval Required

Do not run these steps without explicit owner approval in the current conversation.

## Proposed Migration Steps

1. Push `nof-infra` bootstrap and release-builder script.
2. Add real Helm charts under `helm/nof-mp` and `helm/nof-tt`.
3. Locally render charts and verify no secret values are committed.
4. On hbl, create renamed Kubernetes secret resources by copying existing secret data without printing values:
   - `nof-platform-oauth-secrets` -> `nof-mp-oauth-secrets`
   - `forge-tasks-oauth-secrets` -> `nof-tt-oauth-secrets`
   - `forge-tasks-security-audit` -> `nof-tt-security-audit`
5. On hbl, backup current script and systemd units.
6. Install `nof-infra/release-builder/nof-release-builder.sh` to `/opt/nof-release-builder/nof-release-builder.sh`.
7. Run `nof-release-builder.sh list` and verify it shows `nof-mp`, `nof-tt`, `nof-ht`.
8. Keep `environments/hbl/desired-state.tsv` rows disabled until local regression and owner UAT approval.
9. Enable one service at a time.

## Stop Conditions

- The script cannot fetch `nof-infra`.
- Chart path is missing.
- Helm release render differs unexpectedly from current service config.
- Any secret value appears in logs or files.
- OAuth flow creates synthetic users or reuses another product session.
