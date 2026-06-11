# nof-ht Release Builder Migration Plan

Status: planning, no production changes.
Owner: nof-infra / nof-main.
Tracker: `MANUAL-INFRA-HT-MIGRATION-PLAN`.
Sprint: `NOF-INFRA-SPRINT-HT-RELEASE-BUILDER-20260611`.

## Purpose

Move `nof-ht` production deployment from the temporary GitHub Actions runner path to the canonical NOF release-builder path:

```text
nof-ht semver tag
  -> nof-infra desired-state / release-builder
  -> hbl MicroK8s Helm release nof-ht
  -> owner UAT
```

No production change is approved by this document.

Migration safety standard: `docs/decisions/nof-ht-db-migration-release-standard-2026-06-11.md`.
Controlled UAT window runbook: `docs/runbooks/nof-ht-release-builder-controlled-uat-window.md`.

## Current State

`nof-ht` currently deploys through `nof-ht/.github/workflows/deploy.yml`:

- trigger: push to `main`;
- runner labels: `self-hosted`, `linux`, `nof-ht`;
- image: `localhost:32000/nof-ht:<short-commit>`;
- Helm chart source: `nof-ht/charts/nof-ht`;
- Helm release: `nof-ht`;
- namespace: `nof-apps`;
- migration step reads `DATABASE_URL` from `nof-ht-secrets` into a shell variable and pipes it into `psql`;
- smoke: `GET /login` on the canonical Habit Tracker URL.

Current nof-infra release-builder already knows service key `nof-ht`, but keeps `nof-ht` disabled in `environments/hbl/desired-state.tsv`.

## Gaps To Close Before Migration

1. Chart ownership:
   - target: `nof-infra/helm/nof-ht`;
   - current: `nof-ht/charts/nof-ht`;
   - action: copy/adapt the chart into `nof-infra` and make release-builder use the nof-infra chart source.
2. Version policy:
   - target: production deploy ref is a semver tag such as `v1.33.51`;
   - current workflow image tag is short commit SHA;
   - release-builder already derives public `NEXT_PUBLIC_APP_VERSION` from semver tag.
3. Migration execution:
   - target: no secret values printed or committed;
   - current GitHub Actions workflow reads `DATABASE_URL` into a shell variable;
   - current GitHub Actions workflow runs migrations after Helm rollout;
   - action: define a release-builder migration gate that runs before Helm upgrade and avoids printing secret values.
4. Rollback:
   - target: release-builder evidence records Helm revision and rollback command;
   - current workflow relies on GitHub Actions logs plus Helm state.
5. Owner approval:
   - target: nof-ht desired-state row remains disabled until a nof-ht migration release window is explicitly approved.

## Proposed Steps

1. Prepare nof-infra Helm chart ownership locally.
2. Update release-builder `nof-ht` chart source from service repo chart to `nof-infra/helm/nof-ht`.
3. Add or document a safe nof-ht migration execution path.
   - Safety runbook: `nof-ht-migration-secret-safety.md`.
   - Release standard: `docs/decisions/nof-ht-db-migration-release-standard-2026-06-11.md`.
   - Preferred target: one-shot Kubernetes Job using the approved nof-ht image tag, existing secret mounts and a service-owned migration command.
4. Run local nof-infra preflight for:
   - `nof-ht v1.33.51 enabled=false`;
   - production-mode guard with nof-ht disabled.
5. Ask owner for a dedicated nof-ht migration deploy window only after local checks pass.
   - Use `nof-ht-release-builder-controlled-uat-window.md`.
6. During approved window:
   - temporarily enable nof-ht desired-state for the approved semver tag;
   - deploy via release-builder;
   - smoke `https://habit-tracker.forgath.ru/login`;
   - verify OAuth start/callback does not regress;
   - record owner UAT.
7. After accepted UAT, disable or remove the GitHub Actions deploy trigger.

## Stop Conditions

Stop before deploy if:

- nof-ht chart in nof-infra differs materially from the live chart and the diff is not understood;
- nof-ht semver tag is not available locally and on origin;
- migration step could print `DATABASE_URL` or other secret values;
- release-builder does not run required nof-ht DB migrations before Helm upgrade for the approved release;
- migration job lacks a database advisory lock;
- migration failure would still allow Helm upgrade;
- release-builder preflight fails;
- owner has not approved the nof-ht migration release window;
- rollback target is unknown.

## Owner UAT After Migration Deploy

UAT is not needed for this planning step. After a future approved migration deploy, owner checks:

1. Open `https://habit-tracker.forgath.ru/login`.
   Expected: page opens, version marker matches the approved nof-ht release.
2. Log in through platform OAuth.
   Expected: no redirect_uri mismatch, no wrong-user session reuse.
3. Open the main habit dashboard.
   Expected: existing habits and weekly schedules remain visible.
4. Trigger logout/login user switch if possible.
   Expected: no session mixing.
