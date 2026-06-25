# CI/CD Ownership

Status: accepted working standard for June beta hardening; updated 2026-06-25 to include the nof-ht owner-owned service release trigger.
Owner: nof-main / nof-infra.
Tracker task: `MANUAL-INFRA-CICD-STANDARD`.
Related runbook: `../runbooks/hbl-release-builder-migration.md`.
Decision record: `../decisions/cicd-standard-2026-06-11.md`.

## Decision

`nof-infra` is the canonical repository for deployment and environment management that is not service application code.

Service repositories own code, tests and service-local runtime configuration examples. `nof-infra` owns cross-service deployment definitions and environment desired-state.

Secrets are not owned by `nof-infra` as values. This repository may document secret names, ownership, mount points and rollout steps, but secret values stay in the target environment secret store and must not be printed into tickets, Wiki, logs or commits.

## Expected Flow

```text
service repository semver tag
  -> owner-approved nof-infra release workflow
  -> hbl infra-owned GitHub Actions self-hosted runner
  -> nof-infra release-builder and Helm definitions
  -> MicroK8s namespace nof-apps
  -> owner UAT acceptance
```

The current target release-builder control file is `environments/hbl/desired-state.tsv`. The target remote trigger is a `nof-infra` GitHub Actions `workflow_dispatch` job running on the hbl self-hosted runner.

Current target script defaults:

- control repo: `https://github.com/teanores/nof-infra.git`;
- control manifest: `environments/hbl/desired-state.tsv`;
- service keys: `nof-mp`, `nof-tt`, `nof-ht`.

Historical hbl state may still include legacy service names such as `nof-platform` and `forge-tasks`. Treat those names as migration inventory only unless a rollback runbook explicitly says otherwise.

## Current Flow Inventory - 2026-06-09

Current production delivery is converging on `nof-infra` release-builder and service release request bridges.

| Service | Current deploy trigger | Local workflow file | hbl mechanism | Status |
| --- | --- | --- | --- | --- |
| `nof-ht` | GitHub Release published | `nof-ht/.github/workflows/request-nof-infra-release.yml` | `nof-infra` hbl runner -> release-builder | Migrated to owner-owned service release request bridge |
| `nof-mp` | GitHub Release published | `nof-mp/.github/workflows/request-nof-infra-release.yml` | `nof-infra` hbl runner -> release-builder | Migrated to owner-owned service release request bridge |
| `nof-tt` | GitHub Release published | `nof-tt/.github/workflows/request-nof-infra-release.yml` | `nof-infra` hbl runner -> release-builder | Migrated to owner-owned service release request bridge |

Additional hbl state:

- `nof-release-builder-sync.timer` runs every 5 minutes and calls `nof-release-builder-sync.service`.
- The release-builder supports service keys `nof-mp`, `nof-tt` and `nof-ht`.
- `nof-ht` legacy deploy workflow exists only as a manual no-op marker.

Agents must state which path they are using before any release-bound action:

- canonical `github-runner release-builder` path for owner-owned service release requests;
- `desired-state automation` only for an explicitly approved timer/pull release window;
- `manual release-builder` only for an explicitly approved emergency/manual fallback;
- no broad multi-service sync unless every enabled service is explicitly approved in the current conversation.

## Release Modes

Agents must not blur GitHub state, desired-state and direct hbl execution. Use one of these names in chat, tracker evidence and runbooks.

| Mode | Trigger | Intended use | Production action owner | Status |
| --- | --- | --- | --- | --- |
| `desired-state automation` | Push service tag and one-service `nof-infra` desired-state update; hbl sync/timer or pull agent applies it | Fail-closed fallback/pull mode for owner-approved release windows | hbl release-builder automation | Fallback |
| `github-runner release-builder` | Owner-approved `nof-infra` workflow dispatch runs on hbl self-hosted runner and invokes release-builder | Target remote release path for routine releases when direct hbl SSH is unavailable | hbl infra-owned GitHub Actions runner | Target |
| `manual release-builder` | Agent runs `/opt/nof-release-builder/nof-release-builder.sh deploy <service> <tag>` over SSH after approval | Supervised hotfix, automation outage, incident recovery | Agent in current owner-approved session | Temporary allowed exception |

Manual release-builder mode must always be called manual in the owner-facing report. A release is not GitHub-driven merely because its tag and desired-state were pushed before the SSH command.

## Automation Target

The preferred June target is to make `github-runner release-builder` safe enough that nof-main agents do not need direct SSH to hbl for routine releases:

1. Service repo creates and pushes an approved semver tag after local checks.
2. `nof-infra` local preflight proves service key, tag, release policy, edge targets and legacy identifiers are safe.
3. Owner approves a `nof-infra` workflow dispatch for exactly one service/tag.
4. The hbl self-hosted runner executes the release-builder command for that exact service/tag.
5. Evidence and rollback data are written under the hbl release-builder evidence directory.
6. The agent reads the evidence, performs smoke checks, and asks the owner for UAT.

Do not make this the default until the runner is infra-owned, workflow inputs are constrained, production environments require owner approval, and the job delegates to `nof-infra` release-builder rather than reimplementing deployment logic.

`desired-state automation` remains a fail-closed fallback/pull mode. The default desired-state rows are disabled. During a controlled desired-state release window, exactly one row is enabled and hbl allowlist must match the same service.

## Accepted Standard - 2026-06-11

Use `nof-infra` release-builder as the canonical production deployment path for NOF services. The preferred remote trigger is an infra-owned GitHub Actions self-hosted runner on hbl. Desired-state/timer sync remains a fail-closed fallback and inventory/control mechanism, not a reason to bypass release approval.

GitHub Actions may remain useful for service-local CI checks, but production deploy is only canonical when it delegates to `nof-infra` release-builder and follows the same owner approval, evidence and rollback gates.

`nof-ht` is no longer a legacy deploy exception: its push-to-main production deploy path is disabled, and its GitHub Release request bridge delegates production deployment to `nof-infra` release-builder.

## Current Release Alignment - 2026-06-14

Local service repository tags currently verified:

| Service | Current tag | Desired-state row | Notes |
| --- | --- | --- | --- |
| `nof-mp` | `v0.2.47` | `v0.2.47`, disabled | Runtime and Helm history are aligned after the appVersion stamp fix; routine deploys must use one explicitly approved release mode per window. |
| `nof-tt` | `v0.2.5` | `v0.2.5`, disabled | Task Tracker MCP endpoint remains `task-tracker.forgath.ru/api/mcp`; routine deploys remain release-window scoped. |
| `nof-ht` | `v1.33.59` pending tag | `v1.33.59`, disabled | nof-ht has naragothal product-bot readiness changes after `v1.33.58`; release requires a fresh semver tag and owner-approved window. |

Do not push desired-state changes to the control branch as a side effect of documentation work. A pushed enabled row can become production-bound if hbl sync is active.

## Discovery Questions

- What currently receives GitHub merge/tag/release events?
- Is the deploy component a GitHub Actions runner, webhook receiver, cron, systemd unit, Kubernetes job or manual script?
- Which component is authoritative after migration: GitHub Actions runner, release-builder timer, manual scoped release-builder, or an explicit hybrid?
- Which legacy Helm releases can be removed after accepted UAT?
- Which secrets are required by name only, and which service owns each secret resource?
- Which system users and database names must be renamed or preserved for rollback?

## Repository Boundary

Keep in service repos:

- application code;
- service-local tests;
- service-local `.env.example`;
- service-specific migrations.

Keep in `nof-infra`:

- Helm charts and Kubernetes manifests;
- release-builder definitions;
- hbl runner/webhook/systemd/cron definitions;
- deployment and rollback runbooks;
- desired-state for local/hbl environments;
- non-secret environment variable names and ownership.

Keep outside `nof-infra`:

- `.env` files, Kubernetes secret values, private keys and tokens;
- application migrations and app runtime code;
- local experimental scripts that have not passed architecture review.

Put prototypes under the NOF root `_incubator` until ownership is approved, then move the production deployment part into `nof-infra` and the application part into the owning service repository.

## Naming Rule

Infrastructure keys must use service keys:

| Service | Release key | Image | Helm release | Public host |
| --- | --- | --- | --- | --- |
| Main Platform | `nof-mp` | `nof-mp` | `nof-mp` | `forgath.ru` |
| Task Tracker | `nof-tt` | `nof-tt` | `nof-tt` | `task-tracker.forgath.ru` |
| Habit Tracker | `nof-ht` | `nof-ht` | `nof-ht` | `habit-tracker.forgath.ru` |
| Coffee Bot | `nof-cb` | `nof-cb` | `nof-cb` | to confirm |

`task-tracker` is allowed as a public hostname/product display name, not as a Helm/image/release-builder key.

## Release Builder Acceptance

A release-builder change is acceptable only when:

- `release-builder/nof-release-builder.sh list` exposes only approved service keys;
- `environments/hbl/desired-state.tsv` uses release tags for enabled production rows;
- Helm chart paths exist for every enabled row;
- local preflight passes before any hbl run;
- owner approval exists in the current conversation for any production-changing command;
- rollback and evidence locations are recorded in the release task or Wiki.
- the chosen release mode is named explicitly.

## Open Cleanup

- DONE: Migrate `nof-ht` production deploy from GitHub Actions to the release-builder standard.
- Add runner health, backoff recovery and owner-facing incident steps if GitHub Actions remains part of the standard.
- Confirm whether the hbl GitHub Actions runner is still needed after the hbl timer release-builder flow is stable.
- Add an infra-owned hbl GitHub Actions runner workflow in `nof-infra`.
- Keep hbl `nof-release-builder-sync.timer` and `nof-release-builder-sync.service` as fail-closed fallback/pull automation.
- Add a nof-infra tracker project and stop storing infra delivery tasks under service projects.
- Rename remaining hbl systemd/unit documentation from legacy wording to NOF service keys after accepted UAT.
- Decide database and system-user naming separately from this deployment ownership document.
