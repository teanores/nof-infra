# nof-ht Migration Secret Safety

Status: planning, no production changes.
Owner: nof-infra / nof-ht.
Tracker: `MANUAL-INFRA-HT-SECRET-MIGRATION-SAFETY`.

## Purpose

Define safety requirements for running nof-ht database migrations from the canonical release-builder path without exposing secret values.

## Current Risk

The legacy nof-ht GitHub Actions workflow reads `DATABASE_URL` from Kubernetes secret `nof-ht-secrets` into a shell variable, then pipes it into `psql` inside the Postgres pod.

The current workflow does not intentionally print the value, but this pattern is fragile:

- `set -x` would leak the value;
- shell errors can expose commands;
- copied debug snippets can accidentally include sensitive values;
- release evidence should never contain database URLs.

## Target Rules

- Do not print secret values.
- Do not store database URLs in nof-infra files, tracker tasks, Wiki or chat.
- Prefer service-owned migration commands that run inside a pod with existing secret mounts.
- If release-builder must orchestrate migrations, it should pass secret values through stdin or environment only inside the target command boundary and never echo them.
- Migration evidence records filenames, hashes, counts and status only, not connection strings.

## Required Preflight Before nof-ht Release-Builder Deploy

1. Identify whether the approved nof-ht tag contains new migrations.
2. Confirm the migration runner path.
3. Confirm logs do not print secret values.
4. Confirm failed migration rollback or stop behavior is documented.
5. Confirm nof-ht application rollout does not proceed past a failed required migration.

## Acceptable Migration Options

### Option A - Service-Owned Migration Command

Preferred target.

The nof-ht image exposes a command that:

- runs inside the nof-ht pod/container context;
- reads DB settings from already-mounted runtime environment;
- applies migrations idempotently;
- prints migration identifiers and status only.

Release-builder calls that command through a Kubernetes Job or one-shot pod.

### Option B - Release-Builder Orchestrated psql

Temporary fallback only.

Requirements:

- no shell tracing;
- secret value passed through stdin or process environment only;
- command output filtered to migration status;
- stop immediately on any command that would echo the connection string.

## Stop Conditions

Stop before deploy if:

- a command prints `DATABASE_URL` or a raw password;
- a migration file cannot be hashed;
- migration status cannot be recorded without secret values;
- migration failure would leave the app deployed at the new version;
- owner has not approved the nof-ht migration release window.

## Follow-Up

The preferred implementation is to add a service-owned nof-ht migration command, then teach release-builder to call it before Helm rollout or as a pre-upgrade Job.
