# Release Window Preparation

Generated: 2026-06-14 00:29:38 +03:00

## Request

- Service: `nof-mp`
- Ref: `v0.2.35`
- Environment: `hbl`
- Mode: `desired-state`
- Approved services for this window: `nof-mp`

## Status

BLOCKED for desired-state automation.

## Mode Meaning

hbl timer/sync may apply the approved desired-state row; no direct deploy command should be used.

## Desired-State Row

- `nof-mp` -> `v0.2.35`, enabled=`true`

## Currently Enabled Rows

- nof-mp -> v0.2.35
- nof-tt -> v0.2.5
- nof-ht -> v1.33.56

## Stop Reasons / Warnings

- Desired-state contains enabled rows outside the approved service list: nof-tt=v0.2.5, nof-ht=v1.33.56.
- Working tree has local changes; report generated with AllowDirty=True.

## Owner Briefing Draft

I prepared a release window for `nof-mp` `v0.2.35`.

Verified locally:
- desired-state contains `nof-mp` at `v0.2.35`;
- release ref is a semver tag;
- approved service allowlist for this window is `nof-mp`;
- no production, hbl, Kubernetes, Helm, Docker or Caddy commands were run by this preparer.

If you approve, the next production action must use exactly this mode: `desired-state`.

Stop if:
- any service outside `nof-mp` is deployed;
- release-builder evidence references a different tag;
- hbl timer runs without `NOF_RELEASE_SYNC_REQUIRE_APPROVED_SERVICES=1`;
- any secret value appears in logs or evidence.
