# nof-infra Agent Session State

Updated: 2026-06-25.

## Current Status

- Active tracker goal: `NOF-INFRA-GOAL-RELEASE-AND-OPS-OWNERSHIP`.
- Active nof-infra sprint: none.
- Latest closed sprint: `NOF-INFRA-SPRINT-14` — GitHub-driven release automation standard.
- `nof-infra` `main` is clean and aligned with `origin/main`.
- `nof-ht` `main` is clean and aligned with `origin/main`.
- No hbl/VPS/production-changing command was run in the latest session.
- No secret values were read, printed or changed.

## Completed Work In Latest Session

- `NOF-INFRA-27` closed:
  - added/codified owner-owned service release request bridge for `nof-mp` and `nof-tt`;
  - service GitHub Release publication now requests `nof-infra` `release-builder.yml` through `workflow_dispatch`;
  - merged and pushed:
    - nof-infra `a5366bf docs(NOF-INFRA-27): codify owner-owned release dispatch`;
    - nof-mp `95b97e6 chore(NOF-INFRA-27): request infra release on publication`;
    - nof-tt `cd6f704 chore(NOF-INFRA-27): request infra release on publication`.
- `NOF-INFRA-29` closed:
  - codified direct SSH/manual release-builder as a `nof-infra-agent`-only emergency fallback;
  - product agents must hand off direct SSH deploy needs to nof-infra instead of running them directly;
  - updated nof-tt Wiki page `agent-priority-order-delegation-standard`;
  - merged and pushed nof-infra `60f7b32 docs(NOF-INFRA-29): codify emergency ssh fallback`.
- `NOF-INFRA-28` closed:
  - migrated `nof-ht` to the same release request bridge;
  - added `nof-ht/.github/workflows/request-nof-infra-release.yml`;
  - kept `nof-ht/.github/workflows/deploy.yml` as a manual no-op legacy marker;
  - closed the nof-ht-specific release-builder migration gate in nof-infra validation while keeping the old input as compatibility;
  - merged and pushed:
    - nof-infra `18476e1 chore(NOF-INFRA-28): close nof-ht release-builder gate`;
    - nof-ht `5ed0962 chore(NOF-INFRA-28): request infra release on publication`.
- `NOF-INFRA-SPRINT-14` closed as `done`.

## Verification Evidence

- `just test` passed in `nof-infra`.
- `git diff --check` passed in `nof-infra` and `nof-ht`.
- Static workflow check confirmed the new `nof-ht` request workflow has:
  - `release: published` and manual validation triggers;
  - fixed service key `nof-ht`;
  - `NOF_INFRA_RELEASE_DISPATCH_TOKEN` as the request token;
  - no `push` or `pull_request` deploy trigger;
  - no self-hosted runner, SSH, hbl host access, Helm/Kubernetes command or direct `/opt/nof-release-builder` invocation.

## Current Release Standard

Routine owner-owned service releases should follow:

```text
service GitHub Release published
  -> service-local request workflow validates semver tag
  -> service workflow dispatches teanores/nof-infra release-builder.yml
  -> nof-infra hbl runner executes release-builder
  -> release-builder writes evidence
  -> owner UAT
```

Owner-owned services currently covered:

- `nof-mp`;
- `nof-tt`;
- `nof-ht`.

Partner-owned or external services must not inherit this hbl deployment path by default.

## Important Operational Notes

- `NOF_INFRA_RELEASE_DISPATCH_TOKEN` must exist in each owner-owned service repository before the first real automatic release request can work.
- First real dispatches still need GitHub environment approval, release-builder evidence review and owner UAT.
- Desired-state/timer remains a fail-closed fallback/pull mode, not the standard daily release path.
- Manual SSH/local release-builder remains available only as an explicitly approved emergency/manual fallback for `nof-infra-agent`.
- Do not run hbl/VPS/production-changing commands without explicit owner approval in the current conversation.
- Do not print or store game passwords, private keys, tokens, database URLs or Kubernetes secret values.

## Backlog Candidates

No active sprint exists. Before continuing implementation, plan or accept a new focused `NOF-INFRA-SPRINT-*`.

Known candidates from tracker:

- `NOF-INFRA-22` — revalidate nof-tt `BOT_API_KEY` Helm mount, readiness 60.
- `NOF-INFRA-30` — preserve reusable secret/configmap migration utilities in `nof-infra/scripts`, readiness 100.
- `NOF-INFRA-9` — watch nof-service decomposition support, readiness 60.
- `NOF-INFRA-25` — post-beta bot gateway Helm/release-builder scaffolding, readiness 40.

Recommendation for the next session: wait for discovery-agent priorities or run a short sprint-planning step before taking backlog work.
