# nof-ht DB Migration Release Standard

Status: proposed.
Date: 2026-06-11.
Owner: nof-infra / nof-main.
Applies to: `nof-ht` release-builder migration.

## Context

`nof-ht` is still deployed by a temporary GitHub Actions runner path. The workflow currently performs:

1. build image;
2. push image;
3. Helm upgrade and rollout;
4. run database migrations;
5. smoke check.

This order is not acceptable for the canonical release-builder path because a new application version can become live before required database migrations are confirmed.

The repository has a service-owned migration command:

```text
npm run db:migrate
tsx scripts/db/migrate.ts
```

The runner reads top-level `db/migrations/*.sql`, records hashes in `__drizzle_migrations`, and skips already-applied hashes.

Known historical risks from nof-ht documentation:

- ad hoc SQL execution through `sql.unsafe()`;
- previous migration parsing defects;
- partial migration risk if a multi-statement file fails midway;
- release logs must never contain `DATABASE_URL` or raw passwords;
- build/deploy must not write to a database implicitly.

## Decision

`nof-ht` must not move to release-builder production deploy until database migrations are a first-class release gate.

The target release order is:

```text
owner approval
  -> local/release-builder preflight
  -> build image
  -> push image
  -> migration preflight against approved tag
  -> run required DB migrations as a Kubernetes Job or one-shot pod
  -> verify migration status
  -> Helm upgrade
  -> rollout status
  -> smoke checks
  -> owner UAT
  -> evidence
```

If migration preflight or migration execution fails, release-builder must stop before Helm upgrade.

## Required Migration Properties

The migration command or job must:

- run with the same image/tag that is about to be deployed;
- read `DATABASE_URL` only from existing Kubernetes secrets or mounted env;
- never print secret values;
- print migration filenames, hashes, applied/skipped counts and failure status only;
- acquire a database-level advisory lock before applying migrations;
- stop on first migration failure;
- record a migration only after its SQL has completed successfully;
- exit non-zero on any failure;
- be idempotent when re-run after successful application;
- be safe to run when zero new migrations exist.

## Advisory Lock

Use a fixed nof-ht migration lock key so two release attempts cannot apply migrations concurrently.

Example conceptual SQL:

```sql
SELECT pg_advisory_lock(hashtext('nof-ht:migrations'));
-- apply/check migrations
SELECT pg_advisory_unlock(hashtext('nof-ht:migrations'));
```

The concrete implementation may use transaction-scoped `pg_advisory_xact_lock` if the runner can keep the lock transaction open across the migration batch.

## Transaction Boundary

Preferred:

- one migration file is applied inside one transaction;
- migration hash is inserted in the same transaction after successful statements.

Accepted exception:

- PostgreSQL statements that cannot run inside a transaction must be explicitly marked and reviewed before release.

This exception must be rare and documented in release evidence.

## Options Considered

### Option A - Service-Owned Migration Job

Preferred.

Release-builder creates a one-shot Kubernetes Job using the approved nof-ht image tag and the existing nof-ht secret mounts. The job runs `npm run db:migrate:release` or equivalent.

Pros:

- release-builder never handles raw database URLs;
- migration code stays service-owned;
- evidence is clean and reproducible;
- the same image that will be deployed proves it can migrate the schema.

Cons:

- nof-ht must harden its migration runner first;
- nof-infra must add Job orchestration and log collection.

### Option B - Release-Builder Orchestrated psql

Temporary fallback only.

Release-builder reads nof-ht migration files and applies them through `psql` in the database pod.

Pros:

- close to the current GitHub Actions behavior;
- less service code needed.

Cons:

- more risk of secret leakage through shell scripts;
- release-builder becomes responsible for service schema details;
- harder to test and maintain across services.

### Option C - Application Auto-Migrate On Startup

Rejected.

The app container applies migrations during normal startup.

Reason:

- each replica/startup can contend for schema changes;
- migration failure becomes an availability failure;
- release evidence becomes weaker;
- rollback behavior is less predictable.

## Required Work Before Enabling nof-ht in Desired State

1. nof-ht: add a release-safe migration command.
2. nof-ht: add tests for migration parser/runner behavior, including skip, apply, failure and no secret logging.
3. nof-ht: ensure migration command supports advisory lock and per-file transaction discipline.
4. nof-infra: teach release-builder to run the migration job before Helm upgrade for services that declare `migrations=job`.
5. nof-infra: add preflight that detects new migrations between deployed tag and target tag.
6. nof-infra: add evidence fields for migration filenames, hashes, applied/skipped counts and job status.
7. nof-infra: keep `nof-ht` disabled in desired-state until the migration gate is implemented and owner approves a migration release window.

## Stop Conditions

Stop before deploy if:

- migration job would run after Helm upgrade;
- migration command can print `DATABASE_URL`, password or full connection string;
- advisory lock is missing;
- a failed migration could be recorded as applied;
- release-builder cannot detect migration job failure;
- target nof-ht tag contains DB migrations but migration gate is disabled;
- owner has not approved the release window.

## Open Questions

1. Should nof-ht replace the custom runner with Drizzle's official migrator, or harden the current runner?
2. Do any existing nof-ht migrations require non-transactional PostgreSQL statements?
3. Should the migration table keep the current hash-based compatibility or add filename/version uniqueness?
4. How should rollback evidence distinguish app rollback from irreversible schema forward changes?
