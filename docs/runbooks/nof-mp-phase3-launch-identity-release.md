# nof-mp Phase 3 Launch + Identity Schema Release Runbook

Status: blocked at preflight on 2026-06-27.
Owner: nof-infra.
Tracker: `NOF-INFRA-39`, sprint `NOF-INFRA-SPRINT-18`.

## Purpose

Prepare the gated production release of `nof-mp` that combines:

- `NOF-MP-43` launch-button same-origin fix;
- canonical identity schema, Option A;
- no production identity data migration.

This runbook is release preparation only until the owner gives an explicit
production deploy GO in the current chat.

## Current Preflight Result

Release is stopped.

Evidence from 2026-06-27 revalidation:

- `origin/main` points to `e36a14d` (`merge: land canonical identity aliases`).
- `origin/main` contains the canonical identity schema merge.
- `origin/main` does not contain `NOF-MP-43`.
- `origin/bugfix/NOF-MP-43/launch-button-same-origin` points to `b3317c2`
  (`fix: launch products through platform access gate`).
- latest visible release tag `v0.2.89` points to `6bd2c03`, which is older
  than the target release scope and must not be deployed for this task.
- local `nof-mp` worktree is dirty in another agent's identity files; nof-infra
  must not overwrite or restore those changes.

## Required Release Ref

Before deploy, nof-mp must provide a semver tag whose peeled commit contains:

- `e36a14d` or a later equivalent canonical identity schema merge;
- `b3317c2` or a later equivalent `NOF-MP-43` launch-button fix;
- no production identity data migration command or one-off data migration.

Record the final release ref here before asking for deploy approval:

```text
service=nof-mp
ref=<blocked-until-new-tag>
commit=<blocked-until-new-tag>
approval_id=NOF-INFRA-39
deploy_mode=github-runner release-builder
```

## Pre-Deploy Gates

Run after the correct nof-mp ref exists:

```powershell
git -C nof-mp fetch --all --tags --prune
git -C nof-mp status --short --branch
git -C nof-mp merge-base --is-ancestor <identity-commit> "<release-ref>^{}"
git -C nof-mp merge-base --is-ancestor <launch-fix-commit> "<release-ref>^{}"
npm --prefix nof-mp run test -- --run
npm --prefix nof-mp run build
npm --prefix nof-mp run typecheck
npm --prefix nof-mp run lint
git -C nof-mp diff --check
```

Expected:

- worktree has no unrelated local changes from nof-infra;
- release ref contains both target scopes;
- tests/build/typecheck/lint pass;
- no secret values are printed;
- no prod identity data migration is executed.

## Owner Briefing Before Deploy

Before running `execute_deploy=true`, post this information in chat:

- service: `nof-mp`;
- release ref and commit;
- deploy mode: `github-runner release-builder`;
- tracker approval/evidence id: `NOF-INFRA-39`;
- checks run and results;
- explicit note: schema-only, no prod identity data migration;
- rollback target from latest live release evidence;
- post-deploy UAT scenarios.

Do not deploy without explicit owner GO after this briefing.

## Deploy Command

Use only after owner GO:

```powershell
gh workflow run release-builder.yml -R teanores/nof-infra `
  -f service=nof-mp `
  -f ref=<approved-semver-tag> `
  -f approval_id=NOF-INFRA-39 `
  -f execute_deploy=true `
  -f nof_ht_migration_gate_approved=false
```

Watch:

```powershell
gh run watch <run-id> -R teanores/nof-infra --exit-status
gh run view <run-id> -R teanores/nof-infra --log
```

## Post-Deploy Smoke

Use public checks only; do not read secret values.

Expected checks:

- `https://forgath.ru/login` returns `200`.
- `https://forgath.ru/.well-known/openid-configuration` returns `200`.
- nof-mp footer/version marker shows the deployed version.
- Task Tracker launch CTA routes through same-origin
  `/products/<key>/launch` and reaches the OAuth flow instead of hanging.
- no prod identity data migration was run.

Record:

- GitHub Actions run id;
- image repository and tag;
- image digest if available;
- Helm release, namespace, revision and status;
- release-builder evidence file path;
- smoke results;
- rollback target.

## Rollback

Rollback requires separate owner approval in the current chat.

Preferred rollback path:

```powershell
gh workflow run release-builder.yml -R teanores/nof-infra `
  -f service=nof-mp `
  -f ref=<previous-known-good-nof-mp-tag> `
  -f approval_id=NOF-INFRA-39-rollback `
  -f execute_deploy=true `
  -f nof_ht_migration_gate_approved=false
```

Before finalizing rollback target, re-read latest live release evidence from
release-builder logs. The memory bank currently records `v0.2.87` / Helm
revision `117` as a previous successful nof-mp deploy, but that may no longer
be the current live rollback target.

## Stop Conditions

Stop immediately if:

- release ref does not contain both identity schema and `NOF-MP-43`;
- deploy would run a prod identity data migration;
- owner has not given explicit in-chat GO;
- workflow logs expose a secret value;
- release-builder evidence is missing;
- public smoke shows login/OIDC/launch flow regression.
