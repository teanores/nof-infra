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

## Checks

- nof-infra working tree is clean.
- `environments/hbl/desired-state.tsv` contains the expected service row.
- The service release ref matches the expected release ref.
- The service remains `enabled=false` before owner-approved production deploy.
- Edge target files do not contain live legacy `forge-tasks.forgath.ru` targets.
- Edge target files do not contain obvious secret-looking markers.

## Stop Conditions

- Working tree is dirty.
- Desired-state uses a branch name for a production release candidate.
- A target edge file contains `forge-tasks.forgath.ru` as a live hostname.
- A target edge file contains secret-looking content.
- Owner has not approved production action in the current conversation.

## Limits

This preflight does not prove the live hbl/VPS state matches the repository. When access returns, run the live diff/backup/apply procedure in `portal-gateway-declarative-state.md`.
