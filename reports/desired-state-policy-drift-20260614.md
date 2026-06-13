# Desired-State Policy Drift

Generated: 2026-06-14

## Scope

Environment: `hbl`

File: `environments/hbl/desired-state.tsv`

## Current Finding

`just check-policy` fails because the current desired-state file has multiple enabled rows:

- `nof-mp` -> `v0.2.35`
- `nof-tt` -> `v0.2.5`
- `nof-ht` -> `v1.33.56`

The accepted default routine-release policy allows at most one enabled row. `nof-ht` must also remain disabled until the release-builder migration gate is accepted.

## Why This Matters

hbl sync is now fail-closed through:

- `NOF_RELEASE_SYNC_REQUIRE_APPROVED_SERVICES=1`
- `NOF_RELEASE_SYNC_APPROVED_SERVICES=none`

That prevents unattended broad sync, but it does not make the repository control file clean. A release-window report should not have to infer whether unrelated enabled rows are inventory, approval, or stale state.

## Required Cleanup

Create an approved nof-infra desired-state cleanup task to choose and apply the default state:

- keep only the currently approved release-window service enabled; or
- set all rows `enabled=false` by default and enable exactly one row only during an approved release window.

Do not change `desired-state.tsv` as a side effect of documentation work. It is production-bound release control.

## Verification Commands

```powershell
just check-policy
just prepare-release nof-mp v0.2.35 desired-state
```

Expected before cleanup:

- `just check-policy` fails with multiple enabled rows.
- `just prepare-release ... desired-state` reports `BLOCKED for desired-state automation`.

Expected after cleanup:

- `just check-policy` passes when the default policy is satisfied.
- release-window preparation is `READY` only for the explicitly approved service/tag.
