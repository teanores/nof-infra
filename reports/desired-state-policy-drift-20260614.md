# Desired-State Policy Drift

Generated: 2026-06-14

## Scope

Environment: `hbl`

File: `environments/hbl/desired-state.tsv`

## Original Finding

`just check-policy` failed because the desired-state file had multiple enabled rows:

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

Owner approved cleanup in chat on 2026-06-14:

- set all rows `enabled=false` by default;
- enable exactly one row only during an approved release window;
- keep `nof-ht enabled=false` until its release-builder migration gate is accepted.

Applied default state:

- `nof-mp` -> `v0.2.35`, `enabled=false`
- `nof-tt` -> `v0.2.5`, `enabled=false`
- `nof-ht` -> `v1.33.56`, `enabled=false`

## Verification Commands

```powershell
just check-policy
just prepare-release nof-mp v0.2.35 desired-state
```

Expected after cleanup:

- `just check-policy` passes.
- `just prepare-release ... desired-state` remains `BLOCKED` until the target service row is explicitly enabled for an approved release window.
