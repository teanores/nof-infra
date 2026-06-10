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

Read-only follow-up on 2026-06-09 found:

- `actions.runner.teanores-nof-ht.hbl-runner.service` is loaded, active and running.
- `nof-release-builder-sync.timer` is active and triggers approximately every 5 minutes.
- `nof-mp` and `nof-tt` repositories do not currently contain `.github/workflows`.
- `nof-ht` contains `.github/workflows/deploy.yml` and deploys through the self-hosted runner on push to `main`.
- `nof-mp` and `nof-tt` are deployed through scoped release-builder commands after explicit owner approval.

Local `nof-infra` state after bootstrap:

- release-builder script default control repo is `https://github.com/teanores/nof-infra.git`;
- default control manifest is `environments/hbl/desired-state.tsv`;
- supported release-builder service keys are `nof-mp`, `nof-tt`, `nof-ht`;
- current local desired-state rows on 2026-06-10:
  - `nof-mp` -> `v0.2.17`, enabled;
  - `nof-tt` -> `v0.2.5`, enabled;
  - `nof-ht` -> `v1.33.51`, disabled because nof-ht currently uses the GitHub Actions runner path.

Use read-only hbl discovery before changing any hbl service, timer, Helm release or Kubernetes object. The local repository state is not proof that the hbl host has the same script installed.

Current read-only discovery on 2026-06-11:

- `/opt/nof-release-builder/nof-release-builder.sh list` returns `nof-mp`, `nof-tt`, `nof-ht`.
- `nof-release-builder-sync.timer` is active and calls `/opt/nof-release-builder/nof-release-builder.sh sync main` every 5 minutes.
- No checked-out `environments/hbl/desired-state.tsv` file was found under `/opt/nof-release-builder` or `/home/nofadminhbl/nof-release-builder`; the timer may create/use a transient checkout during sync.
- Live Helm still includes legacy releases `nof-platform` and `forge-tasks` alongside canonical `nof-mp` and `nof-tt`; treat legacy release cleanup as a separate post-UAT task.

## Target State

- control repo: `https://github.com/teanores/nof-infra.git`
- control manifest: `environments/hbl/desired-state.tsv`
- release-builder service keys: `nof-mp`, `nof-tt`, `nof-ht`
- Helm releases: `nof-mp`, `nof-tt`, `nof-ht`
- images: `localhost:32000/nof-mp:*`, `localhost:32000/nof-tt:*`, `localhost:32000/nof-ht:*`
- public Task Tracker host: `task-tracker.forgath.ru`
- OAuth secret resource names: `nof-mp-oauth-secrets`, `nof-tt-oauth-secrets`, `nof-ht-oauth-secrets`

## CI/CD Standard Decision

Decision record: `../decisions/cicd-standard-2026-06-11.md`.

Accepted standard: `nof-infra` release-builder and desired-state are the canonical production deployment path for NOF services.

The current hybrid remains operational debt until nof-ht is migrated:

- `nof-ht` uses GitHub Actions and can be blocked by runner disconnect/backoff.
- `nof-mp` and `nof-tt` rely on manual scoped release-builder deploys.
- `nof-release-builder-sync.timer` also exists, so agents must not assume a single authoritative path.

Until nof-ht is migrated, production deploy requests must name the path explicitly:

- canonical release-builder path for `nof-mp` and `nof-tt`;
- temporary legacy GitHub Actions runner path for `nof-ht`.

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
- Keep `nof-ht` disabled in desired-state until a dedicated migration moves nof-ht from GitHub Actions to release-builder.
- Keep post-UAT cleanup tasks linked to `MANUAL-C48428C1`, `MANUAL-2F20751D`, `MANUAL-43DB73A9` and `MANUAL-38757CBE`.
- Prepare read-only command lists only; do not run hbl-changing commands without approval.
- Add a dedicated `nof-infra` MCP alias/token when project-scoped agent access is needed; do not use nof-tt/nof-mp/nof-ht aliases to mutate nof-infra records.

## Stop Conditions

- The script cannot fetch `nof-infra`.
- Chart path is missing.
- Helm release render differs unexpectedly from current service config.
- `nof-release-builder-sync.timer` is active and a desired-state push would enable services outside the explicit owner-approved release window.
- Any secret value appears in logs or files.
- OAuth flow creates synthetic users or reuses another product session.
- A desired-state row would enable a production deploy before owner UAT approval.
