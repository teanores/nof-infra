# Release Window Preparation

Generated: 2026-06-14 18:15:35 +03:00

## Request

- Service: `nof-mp`
- Ref: `v0.2.36`
- Environment: `hbl`
- Mode: `manual-release-builder`
- Approved services for this window: `nof-mp`

## Status

READY for manual release-builder briefing, pending explicit owner approval.

## Mode Meaning

agent/operator would invoke release-builder deploy directly after owner approval; this must be reported as manual release-builder mode.

## Desired-State Row

- `nof-mp` -> `v0.2.36`, enabled=`false`

## Currently Enabled Rows

- none

## Stop Reasons / Warnings

- none

## Owner Briefing Draft

I prepared a release window for `nof-mp` `v0.2.36`.

Verified locally:
- desired-state contains `nof-mp` at `v0.2.36`;
- release ref is a semver tag;
- approved service allowlist for this window is `nof-mp`;
- no production, hbl, Kubernetes, Helm, Docker or Caddy commands were run by this preparer.

If you approve, the next production action must use exactly this mode: `manual-release-builder`.

Stop if:
- any service outside `nof-mp` is deployed;
- release-builder evidence references a different tag;
- hbl timer runs without `NOF_RELEASE_SYNC_REQUIRE_APPROVED_SERVICES=1`;
- any secret value appears in logs or evidence.
