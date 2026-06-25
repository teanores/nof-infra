# CI/CD Standard Decision - 2026-06-11

Status: accepted working standard for June beta hardening; updated on 2026-06-25 after owner-owned service release trigger clarification.
Owner: nof-main / nof-infra.
Tracker: `NOF-INFRA-SPRINT-CICD-20260611`, task `MANUAL-INFRA-CICD-STANDARD`.

## Context

NOF currently has more than one production delivery path:

- `nof-mp` is deployed through hbl release-builder commands.
- `nof-tt` is deployed through hbl release-builder commands.
- `nof-ht` is deployed through GitHub Actions on a self-hosted hbl runner.
- hbl also has `nof-release-builder-sync.timer`, so desired-state can become production-bound if pushed to the active control branch.

This hybrid works, but it is operational technical debt. Agents must not guess which path owns a service during release work.

Recent nof-mp releases exposed a process ambiguity: the agent pushed service tags and `nof-infra` desired-state, then also invoked `/opt/nof-release-builder/nof-release-builder.sh deploy ...` over SSH. That is reliable for a supervised hotfix, but it is not the target automation model because GitHub state, hbl timer state and chat approval can drift.

## Decision

The canonical production deployment model for NOF services is:

```text
service repository tag
  -> nof-infra release workflow
  -> hbl infra-owned GitHub Actions self-hosted runner
  -> nof-infra release-builder
  -> hbl MicroK8s / Helm release
  -> owner UAT acceptance
```

The target remote operating mode for owner-owned services is a service-local GitHub Release trigger that requests the infra-owned release-builder workflow:

```text
owner-owned service repository GitHub Release published
  -> service-local release workflow validates the semver tag
  -> service-local release workflow calls nof-infra workflow_dispatch with fixed service, tag and approval/evidence id
  -> hbl self-hosted runner executes release-builder for exactly one approved service/tag
  -> release-builder writes evidence and rollback data
  -> agent reads evidence and requests owner UAT
```

The hbl self-hosted runner must be owned by `nof-infra`, not by a single product repository. It is an execution agent for `nof-infra` release-builder, not an independent deployment implementation.

This privileged release trigger is only for owner-owned services such as `nof-mp` and `nof-tt`. Partner-owned or external services must not automatically use NOF hbl or NOF release-builder. Those services must configure their own hosting, Git repository integration and deployment flow unless the owner explicitly moves them into the owner-owned service set.

The service-local workflow is a request bridge only. It must not SSH to hbl, run Helm/Kubernetes commands, or duplicate release-builder logic. Its deploy authority is limited to calling `teanores/nof-infra/.github/workflows/release-builder.yml` through GitHub `workflow_dispatch` with a fixed service key and the published semver tag.

The desired-state timer remains a fail-closed fallback/pull mode:

```text
service repository semver tag
  -> local service checks and nof-infra preflight
  -> nof-infra desired-state update for exactly one approved service/tag
  -> hbl release-builder sync/timer applies the approved row only when the release window allowlist permits it
  -> release-builder writes evidence and rollback data
  -> agent reads evidence and requests owner UAT
```

Direct SSH invocation of `nof-release-builder.sh deploy <service> <tag>` is allowed only as an explicitly named manual release-builder mode for a supervised hotfix, incident recovery, or automation outage. It must not be described as GitHub-driven automation in owner communication.

## Desired-State Policy

`environments/hbl/desired-state.tsv` is production-bound release control, not a general inventory list.

Default policy:

- at most one service row may be `enabled=true` for a routine release window;
- every enabled row must have explicit owner approval in the current conversation;
- `nof-ht` must remain `enabled=false` until its release-builder migration gate is accepted;
- multi-service release windows are exceptional and must name every approved service in chat, tracker evidence and release-window reports;
- disabled rows may keep their last known semver tag for inventory, but they are not approval to deploy.

Local guard:

```powershell
just check-policy
```

This command does not contact hbl or production. It fails when desired-state drifts away from the default routine-release policy.

`nof-infra` owns:

- release-builder scripts;
- hbl desired-state;
- Helm charts and deployment manifests;
- release, rollback and smoke runbooks;
- non-secret environment variable inventories.

Service repositories own:

- application source code;
- service-local tests, lint, typecheck and build;
- service-local migrations;
- `.env.example` files without secret values.

GitHub Actions may be used for service-local CI checks and, for owner-owned services, as a release request bridge. Production deploy is canonical only when the final GitHub Actions deploy job runs in `nof-infra` on the infra-owned hbl self-hosted runner and delegates to `nof-infra` release-builder with the same owner approval, evidence and rollback gates.

## Transition Rule

`nof-ht` remains on the existing GitHub Actions deploy path only as a temporary legacy exception.

Until it is migrated:

- `environments/hbl/desired-state.tsv` keeps `nof-ht` disabled;
- no broad desired-state sync may deploy `nof-ht`;
- nof-ht release requests must explicitly say they use the legacy GitHub Actions runner path;
- runner health/backoff recovery must be documented.
- nof-ht runner health checks must follow `../runbooks/hbl-github-actions-runner-health.md`.

The target state is to move `nof-ht` production deployment to the same release-builder standard as `nof-mp` and `nof-tt`.

## Owner Approval Gates

No production-changing command may run without explicit owner approval in the current conversation.

Before deploy approval, the agent must state in chat:

- what changed;
- what was verified;
- what tag/version will be deployed;
- which service key and release-builder path will be used;
- rollback command or first-revision rollback note;
- exact UAT scenarios and expected results.

The agent must also state the deploy mode:

- `github-runner release-builder`: remote workflow dispatch runs on the infra-owned hbl self-hosted runner and invokes nof-infra release-builder;
- `desired-state automation`: push tag and nof-infra desired-state, then wait for hbl sync/timer or a documented pull agent;
- `manual release-builder`: direct SSH invocation of the hbl release-builder command after approval;
- `legacy GitHub Actions`: temporary nof-ht exception only.
- `service release request`: owner-owned service repository published a GitHub Release and dispatched the canonical `nof-infra` workflow; the actual deploy mode remains `github-runner release-builder`.

If the deploy mode is `manual release-builder`, the post-release evidence must explicitly say that the rollout was direct SSH, not passive GitHub automation.

## Version Policy

Production deploys must use semver tags such as `v0.2.17` or `v1.33.51`.

Do not deploy user-facing services with raw commit refs. Public UI version markers must show the semver release version, not a commit hash.

## Stop Conditions

Stop before deploy if:

- service key does not match the NOF naming standard;
- desired-state contains a branch or raw commit for a production row;
- desired-state would deploy multiple enabled services without explicit owner approval for each;
- local preflight fails;
- hbl live state cannot be read when the release depends on live state;
- secret values would be printed, copied into docs, or committed;
- no rollback path is known.

Stop before relying on desired-state automation if:

- hbl `nof-release-builder-sync.timer` status has not been read recently;
- the sync service still points at a legacy control repo or manifest path;
- the sync cadence, last run and evidence path are unknown;
- desired-state has enabled rows for services not approved in the current release window;
- another agent has uncommitted nof-infra changes that could be accidentally pushed with the release-control commit.

## Follow-Up Tasks

- `MANUAL-INFRA-DESIRED-STATE`: align and document hbl desired-state.
- `MANUAL-INFRA-RUNNER-HEALTH`: document hbl runner health/backoff while nof-ht remains on the legacy path.
- `MANUAL-INFRA-PREFLIGHT`: verify release-builder preflight and readiness checks.
- `IDEA-20260613-160A72`: create a dedicated `nof-infra` tracker project and convert this release automation standard into project-scoped epics/tasks.
- Add a single approved-release command or script that prepares service tag, updates desired-state, runs preflight and prints the exact owner briefing without running production changes.
- Install and configure the release-builder sync allowlist guard `NOF_RELEASE_SYNC_APPROVED_SERVICES` on hbl, then verify whether hbl sync/timer can safely replace direct SSH deploys for `nof-mp` and `nof-tt`.
- DONE: Create an infra-owned GitHub Actions self-hosted runner workflow in `nof-infra` for remote `workflow_dispatch` production releases.
- Add owner-owned service release request workflows for `nof-mp` and `nof-tt` that call the infra-owned workflow on GitHub Release publication.
- After owner-owned service release request workflows are proven in controlled release windows, make manual deploy emergency-only for those services.
