# hbl Release Builder Migration

Status: draft, partially implemented.
Purpose: move hbl release control from legacy `nof-platform-hybrid` to `nof-infra`.
Tracker task: `MANUAL-38757CBE`.

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

Local `nof-infra` state after bootstrap:

- release-builder script default control repo is `https://github.com/teanores/nof-infra.git`;
- default control manifest is `environments/hbl/desired-state.tsv`;
- supported release-builder service keys are `nof-mp`, `nof-tt`, `nof-ht`;
- `nof-mp` desired-state row is enabled at `v0.2.13`;
- `nof-tt` and `nof-ht` desired-state rows remain disabled until owner approval and service UAT.

Use read-only hbl discovery before changing any hbl service, timer, Helm release or Kubernetes object. The local repository state is not proof that the hbl host has the same script installed.

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

## Release Version Policy

User-facing production deploys for `nof-mp`, `nof-tt` and `nof-ht` must use semver tag refs such as `v0.2.13`.

Do not deploy these services with raw commit refs. The release-builder passes `NEXT_PUBLIC_APP_VERSION` into the Docker build and Helm env from the release ref; a raw commit ref would become a public UI marker such as `v12ebee4`, which is invalid for NOF releases.

Evidence must keep the source ref and the public app version separate:

- `source_ref=<git tag ref>`;
- `app_version=<semver without leading v>`;
- `commit=<full commit sha>`.

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

## Current Next Steps Without Owner Interaction

- Keep local docs, runbooks and desired-state consistent with NOF naming.
- Keep `nof-tt` disabled in desired-state until the owner approves a deploy window.
- Keep post-UAT cleanup tasks linked to `MANUAL-C48428C1`, `MANUAL-2F20751D`, `MANUAL-43DB73A9` and `MANUAL-38757CBE`.
- Prepare read-only command lists only; do not run hbl-changing commands without approval.

## Stop Conditions

- The script cannot fetch `nof-infra`.
- Chart path is missing.
- Helm release render differs unexpectedly from current service config.
- Any secret value appears in logs or files.
- OAuth flow creates synthetic users or reuses another product session.
- A desired-state row would enable a production deploy before owner UAT approval.
