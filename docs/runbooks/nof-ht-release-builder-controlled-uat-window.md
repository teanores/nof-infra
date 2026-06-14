# nof-ht Release-Builder Controlled UAT Window

Status: draft, no production approval.
Date: 2026-06-11.
Owner: nof-main / nof-infra / nof-ht.

## Purpose

Move `nof-ht` from the temporary GitHub Actions deploy path to the canonical `nof-infra` release-builder path only after migration safety evidence is accepted.

This runbook is a plan. It does not approve any hbl, Kubernetes, Helm, secret or production action.

## Preconditions

Do not start the window until all items are true:

- nof-ht provides final release-builder readiness evidence:
  - `db:migrate:release` exists in the approved nof-ht tag;
  - migration runner tests pass;
  - migration compatibility audit for top-level `db/migrations/*.sql` is complete;
  - no non-transactional or parser-unsafe migration remains unresolved;
  - nof-ht working tree is clean or dirty files are explicitly out of scope.
- nof-infra branch `docs/NOF-INFRA-HT-MIGRATION-SAFETY-STANDARD` is reviewed.
- nof-infra release-builder migration Job gate is merged to `main`.
- hbl release-builder script update is approved in the current owner conversation.
- `nof-ht` desired-state remains disabled until the release window begins.
- nof-ht legacy GitHub Actions production deploy path is disabled, gated, or explicitly held as emergency-only so it cannot race the release-builder path.
- nof-ht approved release identity is consistent:
  - the approved semver tag points to the intended commit;
  - production image tag, package version and owner-facing version marker are not silently drifting;
  - no untagged `main` commit is selected for the controlled release-builder window.
- The owner explicitly approves the nof-ht release-builder UAT window.

## What Will Change During The Window

Approved window changes may include:

- installing updated `/opt/nof-release-builder/nof-release-builder.sh` on hbl;
- running read-only verification of hbl release-builder version/list;
- enabling `nof-ht` desired-state for one approved semver tag;
- running release-builder deploy for `nof-ht`;
- running one Kubernetes migration Job before Helm upgrade;
- running owner UAT on `https://habit-tracker.forgath.ru`;
- disabling/removing the old GitHub Actions deploy trigger only after accepted UAT.

Approved window must not include:

- changing secret values;
- printing secret values;
- running arbitrary SQL manually;
- deploying raw commit refs;
- broad desired-state sync for multiple services;
- nof-mp or nof-tt deploys unless explicitly named in a separate approval.
- leaving the legacy GitHub Actions deploy path active as a parallel production writer.

## Release Path

Target order:

```text
owner approval
  -> merge nof-infra migration gate
  -> install release-builder script on hbl
  -> local release-preflight for nof-ht with migration evidence
  -> scoped release-builder deploy nof-ht <semver-tag>
  -> build/push image
  -> Kubernetes migration Job
  -> Helm upgrade
  -> rollout status
  -> smoke checks
  -> owner UAT
  -> evidence
```

If the migration Job fails or times out, release-builder stops before Helm upgrade.

## Preflight Commands

Local, before hbl changes:

```powershell
.\scripts\release-preflight.ps1 `
  -Service nof-ht `
  -ExpectedRef <approved-nof-ht-tag> `
  -Environment hbl `
  -ExpectedEnabled false
```

After owner accepts nof-ht migration readiness evidence and the desired-state row is intentionally enabled for the approved window:

```powershell
.\scripts\release-preflight.ps1 `
  -Service nof-ht `
  -ExpectedRef <approved-nof-ht-tag> `
  -Environment hbl `
  -ExpectedEnabled true `
  -ApprovedProductionDeploy `
  -ApprovedServices nof-ht `
  -ScopedDeployOnly `
  -NofHtMigrationGateApproved `
  -NofHtMigrationEvidence "<tracker/wiki/commit evidence>"
```

## hbl Install Plan

Requires explicit owner approval.

1. Backup current release-builder script.
2. Copy updated nof-infra `release-builder/nof-release-builder.sh` to hbl.
3. Verify `nof-release-builder.sh list` returns `nof-mp`, `nof-tt`, `nof-ht`.
4. Verify `nof-ht` service config uses `MIGRATION_MODE=job`.
5. Do not run deploy yet.

## Deploy Plan

Requires explicit owner approval after install verification.

1. Confirm approved nof-ht semver tag exists locally and on origin.
2. Confirm nof-infra desired-state uses only the approved `nof-ht` tag for this window.
3. Run scoped deploy, not broad sync:

```bash
/opt/nof-release-builder/nof-release-builder.sh deploy nof-ht <approved-nof-ht-tag>
```

4. Watch for:
   - image build/push;
   - migration Job start;
   - migration Job complete;
   - Helm upgrade only after migration Job completion;
   - rollout success.

## Owner UAT

After deploy completes, owner checks:

1. Open `https://habit-tracker.forgath.ru/login`.
   Expected: page opens, no TLS/browser error, version marker matches the approved nof-ht tag.
2. Login through NOF Platform OAuth.
   Expected: no redirect_uri mismatch, no wrong-user session reuse.
3. Open Habit Tracker main dashboard.
   Expected: existing habits, schedules and account state remain visible.
4. Create or mark a safe test habit action if agreed for the window.
   Expected: write path works and data survives refresh.
5. Logout/login user switch if practical.
   Expected: no session mixing.

## Evidence To Record

Record:

- owner approval message;
- nof-ht tag and commit;
- nof-infra commit with migration Job gate;
- release-builder script checksum or commit source;
- migration Job name;
- migration Job status;
- migration log path after redaction;
- Helm revision;
- rollout status;
- smoke result;
- owner UAT result;
- rollback command.

Do not record:

- database URLs;
- passwords;
- token values;
- raw Kubernetes secret values.

## Rollback

If Helm upgraded and UAT fails:

1. Roll back app release using Helm rollback from evidence.
2. Do not attempt schema rollback unless nof-ht has provided a specific reversible migration plan.
3. Keep migration evidence attached because schema migrations may be forward-only.
4. Re-enable old GitHub Actions path only if explicitly approved and documented.

If migration Job fails before Helm:

1. Do not run Helm upgrade.
2. Keep nof-ht desired-state disabled.
3. Collect redacted migration Job logs.
4. Return to nof-ht for runner/migration fix.

## Stop Conditions

Stop immediately if:

- nof-ht evidence is incomplete;
- nof-infra preflight fails;
- target ref is not a semver tag;
- migration Job would run after Helm upgrade;
- migration Job logs show an unredacted secret;
- Kubernetes Job fails or times out;
- Helm rollout fails;
- OAuth redirects to the wrong path or user;
- nof-ht production is already on an untagged image commit that does not match the approved semver tag;
- `.github/workflows/deploy.yml` or another legacy path can still auto-run production Helm/migration actions on push to `main`;
- owner has not approved the current production action.
