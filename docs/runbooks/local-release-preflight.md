# Local Release Preflight

Status: active offline guard.
Owner: nof-infra.

## Purpose

Run a local, secret-free release candidate sanity check before any owner-approved hbl deployment window.

This preflight does not contact hbl, VPS, Kubernetes, Helm, Caddy or Docker. It only reads the local nof-infra repository.

## Command

From `nof-infra`:

```powershell
.\scripts\release-preflight.ps1 -Service nof-tt -ExpectedRef v0.2.0 -Environment hbl
```

After the owner explicitly approves a production deploy window and the desired-state row is intentionally enabled, run:

```powershell
.\scripts\release-preflight.ps1 -Service nof-tt -ExpectedRef v0.2.0 -Environment hbl -ApprovedProductionDeploy
```

## Checks

- nof-infra working tree is clean.
- `environments/hbl/desired-state.tsv` contains the expected service row.
- The service release ref matches the expected release ref.
- The service remains `enabled=false` before owner-approved production deploy.
- The service is `enabled=true` only when `-ApprovedProductionDeploy` is passed after owner approval.
- Edge target files do not contain live legacy `forge-tasks.forgath.ru` targets.
- Edge target files do not contain obvious secret-looking markers.
- Live infra target files under `helm`, `release-builder` and `environments/<env>` do not contain legacy `FORGE_TASKS_*` runtime env names.
- Live infra target files do not contain legacy `forge-tasks` Helm release, image, service or app label identifiers.

## Stop Conditions

- Working tree is dirty.
- Desired-state uses a branch name for a production release candidate.
- A target edge file contains `forge-tasks.forgath.ru` as a live hostname.
- A target edge file contains secret-looking content.
- A live infra target file reintroduces `FORGE_TASKS_DATABASE_URL`, `FORGE_TASKS_DB_SCHEMA` or `FORGE_TASKS_MCP_TOKEN_SECRET`.
- A live infra target file reintroduces `localhost:32000/forge-tasks`, Helm release `forge-tasks`, service name `forge-tasks` or app label `forge-tasks`.
- Owner has not approved production action in the current conversation.

## Limits

This preflight does not prove the live hbl/VPS state matches the repository. When access returns, run the live diff/backup/apply procedure in `portal-gateway-declarative-state.md`.
