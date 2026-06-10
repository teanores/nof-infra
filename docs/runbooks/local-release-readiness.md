# Local Release Readiness

Status: active offline guard.
Owner: nof-infra.

## Purpose

Create a local, secret-free evidence pack before an owner-approved release window.

This runbook does not contact hbl, VPS, Kubernetes, Helm, Caddy or Docker. It reads local repositories and runs local checks only.

## Command

From `nof-infra`:

```powershell
.\scripts\local-release-readiness.ps1 -ExpectedNofTtRef v0.2.5 -ExpectedNofTtEnabled true -Environment hbl
```

Use `-SkipBuilds` only for a quick metadata check. Do not use skipped builds as release evidence.
Use `-ExpectedNofTtEnabled false` only when validating a deliberately disabled desired-state row.

## Checks

- `nof-mp`, `nof-tt` and `nof-infra` working trees are clean before checks.
- `nof-mp`, `nof-tt` and `nof-infra` are synchronized with their upstream branches before checks.
- Current branch, HEAD and upstream are recorded for each repository.
- `nof-tt` desired-state ref and enabled state match the expected release state.
- `nof-mp` runs `npm run check` and `npm run build`.
- `nof-tt` runs `npm run check` and `npm run build`.
- `nof-infra` runs `scripts/release-preflight.ps1`.
- A timestamped markdown report is written under `reports/`.

## Stop Conditions

- Any working tree is dirty.
- Any local check or build fails.
- nof-infra release preflight fails.
- A report would require reading or printing secret values.
- Owner has not approved production action in the current conversation.

## Limits

This evidence pack does not prove live hbl/VPS state. Before deploy, run live read-only diff/smoke checks with explicit owner approval.
