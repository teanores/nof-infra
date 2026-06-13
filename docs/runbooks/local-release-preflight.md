# Local Release Preflight

Status: active offline guard.
Owner: nof-infra.

## Purpose

Run a local, secret-free release candidate sanity check before any owner-approved hbl deployment window.

This preflight does not contact hbl, VPS, Kubernetes, Helm, Caddy or Docker. It only reads the local nof-infra repository.

## Command

From `nof-infra`:

Prepare an owner-facing release-window report first:

```powershell
just prepare-release nof-mp v0.2.35 desired-state
```

If the repository contains known unrelated local changes and you only need a planning report, use the explicit dirty variant:

```powershell
just prepare-release-dirty nof-mp v0.2.35 desired-state
```

The preparer writes a report under `reports/` and does not contact hbl, VPS, Kubernetes, Helm, Caddy or Docker.

Then run the stricter preflight:

```powershell
.\scripts\release-preflight.ps1 -Service nof-tt -ExpectedRef v0.2.5 -Environment hbl -ExpectedEnabled true
```

After the owner explicitly approves a production deploy window and the desired-state row is intentionally enabled, run:

```powershell
.\scripts\release-preflight.ps1 -Service nof-tt -ExpectedRef v0.2.5 -Environment hbl -ExpectedEnabled true -ApprovedProductionDeploy -ApprovedServices nof-tt
```

For a scoped release-builder deploy command such as `deploy nof-ht <tag>`, add `-ScopedDeployOnly`. This means existing enabled rows for other services are not treated as approval to run a broad desired-state sync.

Use `-ExpectedEnabled false` only when validating a deliberately disabled row. Use `-ExpectedEnabled any` for read-only inventory checks that should not assert deployment state.

For `nof-ht`, `enabled=true` is additionally blocked unless the migration gate has accepted evidence:

```powershell
.\scripts\release-preflight.ps1 -Service nof-ht -ExpectedRef v1.33.52 -Environment hbl -ExpectedEnabled true -ApprovedProductionDeploy -ApprovedServices nof-ht -ScopedDeployOnly -NofHtMigrationGateApproved -NofHtMigrationEvidence "IDEA-... / commit ..."
```

Do not use this flag until nof-ht has provided release migration evidence and nof-infra migration Job gate is installed for the approved release window.

## Checks

- `scripts/prepare-release-window.ps1` builds a release-window briefing and flags whether the selected mode is ready or blocked.
- `just prepare-release <service> <ref> <mode>` is the preferred entry point for release-window planning.
- `just prepare-release-dirty <service> <ref> <mode>` is allowed only for planning reports when unrelated local changes exist; it must not be used as proof that production is safe.
- nof-infra working tree is clean.
- `environments/hbl/desired-state.tsv` contains the expected service row.
- The service release ref matches the expected release ref.
- The service `enabled` value is either `true` or `false`.
- The service `enabled` value matches `-ExpectedEnabled` unless `-ExpectedEnabled any` is used.
- `-ApprovedProductionDeploy` additionally requires `enabled=true`, but the flag itself is not a deployment and does not contact production.
- `-ApprovedProductionDeploy` requires `-ApprovedServices` and fails if desired-state contains enabled services outside that explicit approval list, unless `-ScopedDeployOnly` is used for a single-service scoped release-builder deploy.
- `nof-ht enabled=true` requires `-NofHtMigrationGateApproved` and non-empty `-NofHtMigrationEvidence`.
- Edge target files do not contain live legacy `forge-tasks.forgath.ru` targets.
- Edge target files do not contain obvious secret-looking markers.
- Live infra target files under `helm`, `release-builder` and `environments/<env>` do not contain legacy `FORGE_TASKS_*` runtime env names.
- Live infra target files do not contain legacy `forge-tasks` Helm release, image, service or app label identifiers.

## Stop Conditions

- Working tree is dirty.
- Desired-state uses a branch name for a production release candidate.
- Desired-state `enabled` is neither `true` nor `false`.
- Desired-state `enabled` does not match the expected release state.
- Production deploy mode is used without `-ApprovedServices`.
- Desired-state contains enabled services outside the owner-approved release window and the action is not explicitly scoped to one service.
- `nof-ht enabled=true` is requested without accepted migration readiness evidence.
- A target edge file contains `forge-tasks.forgath.ru` as a live hostname.
- A target edge file contains secret-looking content.
- A live infra target file reintroduces `FORGE_TASKS_DATABASE_URL`, `FORGE_TASKS_DB_SCHEMA` or `FORGE_TASKS_MCP_TOKEN_SECRET`.
- A live infra target file reintroduces `localhost:32000/forge-tasks`, Helm release `forge-tasks`, service name `forge-tasks` or app label `forge-tasks`.
- Owner has not approved production action in the current conversation.

## Limits

This preflight does not prove the live hbl/VPS state matches the repository. When access returns, run the live diff/backup/apply procedure in `portal-gateway-declarative-state.md`.
