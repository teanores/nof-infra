# hbl Release Builder Migration

Status: draft, partially implemented; updated 2026-06-13 after nof-mp v0.2.35 exposed manual-vs-automated deploy ambiguity.
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
- current local desired-state rows on 2026-06-14:
  - `nof-mp` -> `v0.2.35`, disabled;
  - `nof-tt` -> `v0.2.5`, disabled;
  - `nof-ht` -> `v1.33.59`, disabled because nof-ht still needs a dedicated release window for the naragothal product-bot readiness release.

Use read-only hbl discovery before changing any hbl service, timer, Helm release or Kubernetes object. The local repository state is not proof that the hbl host has the same script installed.

Current read-only discovery on 2026-06-11:

- `/opt/nof-release-builder/nof-release-builder.sh list` returns `nof-mp`, `nof-tt`, `nof-ht`.
- `nof-release-builder-sync.timer` is active and calls `/opt/nof-release-builder/nof-release-builder.sh sync main` every 5 minutes.
- No checked-out `environments/hbl/desired-state.tsv` file was found under `/opt/nof-release-builder` or `/home/nofadminhbl/nof-release-builder`; the timer may create/use a transient checkout during sync.
- Live Helm still includes legacy releases `nof-platform` and `forge-tasks` alongside canonical `nof-mp` and `nof-tt`; treat legacy release cleanup as a separate post-UAT task.
- nof-ht GitHub Actions runner health and recovery are documented in `hbl-github-actions-runner-health.md`.

Current read-only discovery on 2026-06-13:

- `nof-release-builder-sync.timer` is enabled and active, with `OnUnitActiveSec=5min`.
- `nof-release-builder-sync.service` runs `/opt/nof-release-builder/nof-release-builder.sh sync main` as `nofadminhbl`.
- Installed release-builder defaults point to `https://github.com/teanores/nof-infra.git`.
- Installed release-builder defaults use `environments/hbl/desired-state.tsv`.
- `/opt/nof-release-builder/nof-release-builder.sh list` returns `nof-mp`, `nof-tt`, `nof-ht`.
- Journal evidence shows the timer fetched `nof-infra main` and applied `nof-mp v0.2.35` from desired-state after the same tag had already been deployed manually.
- Journal evidence also shows broad sync iterating over enabled `nof-tt v0.2.5` and `nof-ht v1.33.56`, skipping them only because commits were unchanged.

Implication: hbl desired-state automation is already active enough to deploy a pushed enabled row. Manual release-builder deploy plus desired-state push can cause a duplicate rollout. Routine nof-mp/nof-tt releases should move to one mode per release window: either desired-state automation or manual release-builder, not both.

## Target State

- control repo: `https://github.com/teanores/nof-infra.git`
- control manifest: `environments/hbl/desired-state.tsv`
- release-builder service keys: `nof-mp`, `nof-tt`, `nof-ht`
- Helm releases: `nof-mp`, `nof-tt`, `nof-ht`
- images: `localhost:32000/nof-mp:*`, `localhost:32000/nof-tt:*`, `localhost:32000/nof-ht:*`
- public Task Tracker host: `task-tracker.forgath.ru`
- OAuth secret resource names: `nof-mp-oauth-secrets`, `nof-tt-oauth-secrets`, `nof-ht-oauth-secrets`
- nof-ht chart source after migration: `nof-infra/helm/nof-ht`

### nof-ht Shared Public Bot Secret Gate

The nof-ht chart includes shared public NOF bot plumbing from TD-12. The environment names remain service-local for compatibility, but `@naragothal_bot` is not a habit-only bot:

- public config: `NEXT_PUBLIC_TELEGRAM_HABIT_BOT_USERNAME`;
- value: `telegramHabitBotUsername`;
- Kubernetes secretRef: `nof-ht-habit-bot-secrets`.
- current shared public NOF product/community bot username: `naragothal_bot` (`@naragothal_bot`);
- identity/linking bot username: `nof_sentinel_bot` (`@nof_sentinel_bot`).

The secret must exist before deploying this chart in production. Required keys:

```text
TELEGRAM_HABIT_BOT_TOKEN
TELEGRAM_HABIT_BOT_WEBHOOK_SECRET
```

Do not write secret values in git, Wiki, tracker, shell output or chat.

`test_elf_nof_bot` is legacy evidence only and must not be used as a live Helm default or runtime fallback.

Compliance boundary: this is not Telegram authorization. Telegram auth remains disabled by compliance decision; this secret is only for public NOF bot notifications/webhooks after normal email/platform authentication.

Before a nof-ht release window, print the read-only verification commands:

```powershell
just check-ht-bot-prereqs-dry-run
```

During an approved hbl read-only verification window, run:

```powershell
just check-ht-bot-prereqs
```

Expected:

- `nof-ht-secrets` contains `TELEGRAM_NOF_SENTINEL_BOT_TOKEN` and `TELEGRAM_NOF_SENTINEL_BOT_WEBHOOK_SECRET`;
- `nof-ht-habit-bot-secrets` contains `TELEGRAM_HABIT_BOT_TOKEN` and `TELEGRAM_HABIT_BOT_WEBHOOK_SECRET`;
- pre-deploy ConfigMap may still show legacy values; that is the rollout target, not a prereq failure;
- output prints only key names and encoded lengths, never secret values.

After deploy, run:

```powershell
just check-ht-bot-live
```

Expected:

- ConfigMap points sentinel/linking username to `nof_sentinel_bot`;
- ConfigMap points shared public NOF bot username to `naragothal_bot`;
- output prints only key names and encoded lengths, never secret values.

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

As of 2026-06-14, the desired target is stricter:

- routine `nof-mp` and `nof-tt` releases should move from direct SSH deploy commands to an infra-owned GitHub Actions self-hosted runner on hbl;
- the GitHub runner workflow must live in `nof-infra` and invoke `nof-infra` release-builder for exactly one approved service/tag;
- desired-state/timer sync remains a fail-closed fallback/pull mode and inventory/control mechanism;
- direct SSH release-builder deploys remain allowed only when explicitly named as `manual release-builder` mode;
- owner-facing evidence must state whether hbl applied the release by timer/sync or the agent invoked the deploy command.

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

## Desired-State Automation Readiness

Before routine releases rely on `nof-release-builder-sync.timer`, verify these read-only checks on hbl:

```bash
systemctl status nof-release-builder-sync.timer --no-pager -l
systemctl cat nof-release-builder-sync.service
systemctl cat nof-release-builder-sync.timer
journalctl -u nof-release-builder-sync.service -n 120 --no-pager -o short-iso
/opt/nof-release-builder/nof-release-builder.sh list
```

Expected:

- timer is active only if its behavior is understood and accepted;
- service command uses `/opt/nof-release-builder/nof-release-builder.sh sync main`;
- installed release-builder script points to `https://github.com/teanores/nof-infra.git`;
- installed release-builder script uses `environments/hbl/desired-state.tsv`;
- sync evidence or logs show which service/tag was applied;
- no secret values are printed in systemd status or journal output;
- broad sync cannot apply unapproved enabled service rows during a one-service release window.

The local release-builder now supports `NOF_RELEASE_SYNC_APPROVED_SERVICES` for sync mode. When this comma-separated allowlist is set, enabled manifest rows outside the list are skipped:

```bash
NOF_RELEASE_SYNC_APPROVED_SERVICES=nof-mp /opt/nof-release-builder/nof-release-builder.sh sync main
```

For timer-driven automation, use fail-closed mode:

```bash
NOF_RELEASE_SYNC_REQUIRE_APPROVED_SERVICES=1
NOF_RELEASE_SYNC_APPROVED_SERVICES=none
```

With `NOF_RELEASE_SYNC_REQUIRE_APPROVED_SERVICES=1`, an empty or unset allowlist blocks all enabled manifest rows. This is the safe default for the hbl timer. During an approved release window, set `NOF_RELEASE_SYNC_APPROVED_SERVICES` to the exact service keys approved for that window, for example `nof-mp` or `nof-mp,nof-tt`.

This guard is effective on hbl only after the updated script is installed and the systemd unit/timer is configured to pass the intended allowlist policy.

2026-06-13 status against these expectations:

- timer active: yes;
- service command: yes, `sync main`;
- control repo: yes, `nof-infra`;
- manifest path: yes, `environments/hbl/desired-state.tsv`;
- evidence/logs: yes, journal shows deploy/skip decisions and release-builder writes evidence;
- broad sync isolation: implemented through `NOF_RELEASE_SYNC_APPROVED_SERVICES`;
- fail-closed timer mode: installed on hbl through `NOF_RELEASE_SYNC_REQUIRE_APPROVED_SERVICES=1` and `NOF_RELEASE_SYNC_APPROVED_SERVICES=none`;
- repository desired-state policy: clean locally; routine desired-state automation still requires a one-service owner-approved release window before enabling any row.

If any expectation is not met, keep using explicitly approved `manual release-builder` mode for production hotfixes and treat automation as blocked.

Because hbl sync is fail-closed, a pushed desired-state row should not deploy without an explicit allowlist, but agents still must not push desired-state changes casually. Desired-state is production-bound release control and must remain one-service scoped for routine release windows.

Before switching routine releases to desired-state automation, correct repository desired-state policy drift and use a release-window wrapper so `NOF_RELEASE_SYNC_APPROVED_SERVICES` contains only the owner-approved service keys.

## GitHub Runner Remote Release Target

The preferred remote release trigger is an infra-owned GitHub Actions self-hosted runner on hbl.

Target shape:

```text
nof-infra workflow_dispatch
  inputs: service, ref, approval/evidence id
  -> hbl self-hosted runner
  -> local nof-infra preflight
  -> /opt/nof-release-builder/nof-release-builder.sh deploy <service> <semver-tag>
  -> release-builder evidence
  -> smoke checks
  -> owner UAT
```

Acceptance gates:

- runner is registered for `teanores/nof-infra`, not a product-specific repository;
- workflow uses constrained service choices: `nof-mp`, `nof-tt`, `nof-ht`;
- workflow accepts only semver tags, not branches or raw commits;
- production environment uses GitHub environment approval or an equivalent owner approval gate;
- job never prints secret values;
- job delegates deployment to `/opt/nof-release-builder/nof-release-builder.sh`;
- evidence path, image tag, Helm revision and rollback command are captured after the run;
- manual SSH release-builder remains incident/hotfix fallback only.

## Release Mode Checklist

Before asking for deploy approval, choose and state exactly one mode.

### desired-state automation

Use for the target routine flow only after readiness is confirmed.

1. Push service semver tag.
2. Update only one `environments/hbl/desired-state.tsv` row.
3. Run local `scripts/release-preflight.ps1` with the approved service and tag.
4. Push nof-infra desired-state.
5. Wait for hbl sync/timer or the approved pull agent.
6. Read release-builder evidence and smoke the service.
7. Ask owner for UAT.

### manual release-builder

Use for supervised hotfixes, incident recovery or automation outage only.

1. Push service semver tag.
2. Update and push nof-infra desired-state for traceability.
3. Run local preflight.
4. Tell the owner that the rollout will be a direct SSH release-builder invocation.
5. After explicit approval, run:

```bash
/opt/nof-release-builder/nof-release-builder.sh deploy <service> <semver-tag>
```

6. Record evidence path, image, Helm revision and UAT checklist.

Do not call this GitHub automation.

## Current Next Steps Without Owner Interaction

- Keep local docs, runbooks and desired-state consistent with NOF naming.
- Keep `nof-ht` disabled in desired-state until a dedicated migration moves nof-ht from GitHub Actions to release-builder.
- Keep post-UAT cleanup tasks linked to `MANUAL-C48428C1`, `MANUAL-2F20751D`, `MANUAL-43DB73A9` and `MANUAL-38757CBE`.
- Prepare read-only command lists only; do not run hbl-changing commands without approval.
- Add a dedicated `nof-infra` MCP alias/token when project-scoped agent access is needed; do not use nof-tt/nof-mp/nof-ht aliases to mutate nof-infra records.
- Create the `nof-infra` tracker project with platform:admin scope, then move infrastructure CI/CD work out of service projects.
- Add a local script or just recipe that prepares an approved-release evidence bundle without performing production changes.

## Stop Conditions

- The script cannot fetch `nof-infra`.
- Chart path is missing.
- Helm release render differs unexpectedly from current service config.
- `nof-release-builder-sync.timer` is active and a desired-state push would enable services outside the explicit owner-approved release window.
- Any secret value appears in logs or files.
- OAuth flow creates synthetic users or reuses another product session.
- A desired-state row would enable a production deploy before owner UAT approval.
