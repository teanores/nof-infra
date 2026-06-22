# Per-Service PostgreSQL Roles And Secrets

Status: plan, production changes require owner approval.
Tracker task: `NOF-INFRA-18`.
Source request: `NOF-MP-14`.

## Purpose

Split NOF runtime database credentials from the shared Kubernetes Secret `postgres-secret` into service-owned PostgreSQL roles and service-owned Kubernetes Secrets.

This unblocks nof-mp DB credential rotation without breaking nof-tt or legacy nof-service.

## Current State

Local nof-infra chart evidence:

- `helm/nof-mp/values.yaml` maps `DB_USER`, `DB_PASS` and `DB_NAME` to shared `postgres-secret`;
- `helm/nof-tt/values.yaml` maps `DB_USER`, `DB_PASS` and `DB_NAME` to shared `postgres-secret`;
- legacy nof-service compatibility is still required until decomposition is complete.

Do not rotate or delete `postgres-secret` while any service still consumes it.

## Target State

Service-owned runtime secrets:

| Service | Target Kubernetes Secret | Keys |
| --- | --- | --- |
| `nof-mp` | `nof-mp-postgres-secret` | `postgres-user`, `postgres-password`, `postgres-db` |
| `nof-tt` | `nof-tt-postgres-secret` | `postgres-user`, `postgres-password`, `postgres-db` |
| `nof-service` legacy bridge | `postgres-secret` until decomposition decision | `postgres-user`, `postgres-password`, `postgres-db` |

Target PostgreSQL roles:

- one runtime role per service;
- least required privileges for the service schema/database usage;
- no shared password reuse between service roles;
- no password values in git, tracker, Wiki, logs or chat.

The exact role names should match approved naming at live-apply time. Record names only, never passwords.

## Standard Delivery Path

Use GitHub runner release-builder as the standard path for nof-mp and nof-tt chart changes.

Manual SSH/local release-builder is allowed only as the NOF-INFRA-16 emergency/manual flow with:

```bash
NOF_RELEASE_MANUAL_OVERRIDE=1
NOF_RELEASE_APPROVAL_ID='<current-chat-owner-approval-or-tracker-evidence-id>'
```

Do not use manual flow as the routine product-agent path.

## Migration Order

Do not run without explicit owner approval in the current conversation.

1. Capture metadata-only preflight.

   ```powershell
   just check-postgres-secret-split-dry-run
   ```

   Live metadata preflight, if approved:

   ```powershell
   just check-postgres-secret-split
   ```

2. Create target PostgreSQL runtime roles out of band.

   Requirements:

   - no password values printed;
   - role names recorded;
   - privileges limited to the service's required database/schema access;
   - legacy shared role remains until all consumers are migrated.

3. Create target Kubernetes Secrets out of band.

   Required keys:

   ```text
   postgres-user
   postgres-password
   postgres-db
   ```

   Use metadata-only verification; never decode values.

4. Move one service at a time.

   Recommended order:

   1. `nof-mp` first, because this task unblocks `NOF-MP-14`;
   2. `nof-tt` after nof-mp is stable;
   3. legacy nof-service only after the decomposition/bridge decision explicitly allows it.

5. For each service:

   - update the chart secretRef to the service-owned Secret;
   - deploy through GitHub runner release-builder;
   - run metadata-only checks;
   - run service smoke/UAT;
   - record evidence before moving to the next service.

6. Decommission shared `postgres-secret` only after no live consumer remains.

## Metadata-Only Verification

Safe local dry run:

```powershell
just check-postgres-secret-split-dry-run
```

This prints the hbl read-only commands but does not run SSH.

Live metadata-only check, only after owner approval:

```powershell
just check-postgres-secret-split
```

Expected output shape:

- secret key names with encoded lengths only;
- pod env presence as `DB_USER=SET`, `DB_PASS=SET`, `DB_NAME=SET`;
- PostgreSQL role names only, no passwords.

After a service has moved to its service-owned Secret:

```powershell
just check-postgres-secret-split-live
```

Expected:

- `nof-mp-postgres-secret` exists before nof-mp cutover is accepted;
- `nof-tt-postgres-secret` exists before nof-tt cutover is accepted;
- each expected key has non-zero encoded length;
- pod env values are present as SET/MISSING only;
- no password, database URL or raw connection string appears.

## Rollback

For a failed service cutover:

1. Stop immediately before moving any other service.
2. Roll back the service Helm release or restore the previous chart secretRef.
3. Keep `postgres-secret` unchanged.
4. Re-run metadata-only checks.
5. Record failed cutover and rollback evidence without values.

Do not delete service-specific roles/secrets during emergency rollback unless the owner explicitly approves cleanup.

## Stop Conditions

Stop if:

- any command would print a password, database URL, raw connection string or Secret data value;
- `postgres-secret` would be rotated while nof-tt or legacy nof-service still depends on it;
- the target service/ref differs from the owner-approved scope;
- a service DB smoke fails;
- the GitHub runner release path is unavailable and manual emergency flow has not been explicitly approved;
- owner approval is missing for live DB, Kubernetes or hbl operations.

## Evidence To Record

For each service phase:

- owner approval reference;
- target service and chart commit/ref;
- target Kubernetes Secret name and key names only;
- PostgreSQL role name only;
- metadata-only verification result;
- release-builder evidence id;
- service smoke/UAT result;
- rollback command or stop condition.
