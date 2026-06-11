# nof-ht DB Migration Gate Backlog

Status: proposed backlog.
Date: 2026-06-11.
Owner: nof-main / nof-infra, with nof-ht implementation handoff.

## Goal

Make nof-ht safe to deploy through the canonical nof-infra release-builder path without risking schema/app mismatch or secret leakage.

## nof-ht Tasks

### NOF-HT-P0-HARDEN-MIGRATION-RUNNER

Purpose: make the service-owned migration runner safe enough for production release-builder use.

Acceptance:

- runner does not read `.env.local` in production/release mode;
- release mode requires `DATABASE_URL` from process environment;
- no logs print connection strings or passwords;
- migration batch acquires a Postgres advisory lock;
- each migration file is applied atomically where PostgreSQL allows it;
- migration hash is recorded only after successful SQL execution;
- failed migration exits non-zero and does not continue;
- tests cover apply, skip, failure, parser edge cases and secret redaction.

### NOF-HT-P0-ADD-RELEASE-MIGRATION-COMMAND

Purpose: expose a stable command for release-builder.

Acceptance:

- package script exists, for example `db:migrate:release`;
- command runs in container context without dev-only assumptions;
- output includes applied/skipped filenames and hashes;
- output excludes secret values;
- command is documented in nof-ht AGENTS/runbook.

### NOF-HT-P1-MIGRATION-COMPATIBILITY-AUDIT

Purpose: verify existing migrations are compatible with the hardened runner.

Acceptance:

- list top-level `db/migrations/*.sql` files;
- identify any non-transactional statements;
- identify any files where semicolon splitting is unsafe;
- identify any migrations that need post-apply schema checks;
- document result for nof-infra before release-builder migration deploy.

## nof-infra Tasks

### NOF-INFRA-P0-RELEASE-BUILDER-MIGRATION-JOB

Purpose: add release-builder support for service migration jobs before Helm upgrade.

Current guard:

- release-builder declares `nof-ht` as `MIGRATION_MODE=job`;
- release-builder runs a Kubernetes migration Job before Helm upgrade for `MIGRATION_MODE=job`;
- the Job uses the target image tag, existing nof-ht secret/configMap refs and `npm run db:migrate:release`;
- if the Job fails or times out, release-builder exits before Helm upgrade;
- this prevents nof-ht from going live through release-builder while the service-owned release migration command is missing or failing.

Acceptance:

- service config can declare migration mode: `none` or `job`;
- nof-ht uses `job`; ✅
- release-builder creates a one-shot Kubernetes Job using the target image tag; ✅
- Job receives existing service env/secret refs without exposing secret values; ✅
- release-builder waits for Job completion and fails before Helm upgrade on migration failure; ✅
- Job logs are captured with secret redaction; ✅
- nof-ht image contains a tested `db:migrate:release` command; pending nof-ht.

### NOF-INFRA-P0-MIGRATION-PREFLIGHT

Purpose: detect whether the target nof-ht release contains migrations and whether the gate is enabled.

Acceptance:

- compare deployed ref/tag and target ref/tag where possible;
- list changed `db/migrations/*.sql`;
- fail if migrations exist and service migration mode is not enabled;
- record filenames and hashes in evidence.

### NOF-INFRA-P1-MIGRATION-EVIDENCE

Purpose: make release evidence useful without secrets.

Acceptance:

- evidence records target tag, image tag, chart version, migration mode, migration job name, applied/skipped counts and hashes;
- evidence records Helm revision only after migration gate passes;
- evidence includes rollback note separating app rollback from schema rollback.

## Deployment Rule

`nof-ht` remains disabled in nof-infra desired-state until:

1. nof-ht P0 runner tasks are done;
2. nof-infra P0 release-builder migration job tasks are done;
3. local validation passes;
4. owner approves a dedicated nof-ht migration release window.

## Owner Decision Needed Later

No immediate owner decision is required for this planning document.

Later decision:

- use hardened current runner as the first release-builder migration path, or
- replace it with Drizzle official migrator before migration to release-builder.
