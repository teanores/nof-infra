# CI/CD Ownership

Status: accepted working standard for June beta hardening.
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
  -> owner-approved release-builder action
  -> nof-infra release-builder control manifest and Helm definitions
  -> MicroK8s namespace nof-apps
  -> owner UAT acceptance
```

The current target release-builder control file is `environments/hbl/desired-state.tsv`.

Current target script defaults:

- control repo: `https://github.com/teanores/nof-infra.git`;
- control manifest: `environments/hbl/desired-state.tsv`;
- service keys: `nof-mp`, `nof-tt`, `nof-ht`.

Historical hbl state may still include legacy service names such as `nof-platform` and `forge-tasks`. Treat those names as migration inventory only unless a rollback runbook explicitly says otherwise.

## Current Flow Inventory - 2026-06-09

Current production delivery is still a hybrid during migration, but the target standard is accepted: production deployment should converge on `nof-infra` release-builder and desired-state.

| Service | Current deploy trigger | Local workflow file | hbl mechanism | Status |
| --- | --- | --- | --- | --- |
| `nof-ht` | GitHub push to `main` | `nof-ht/.github/workflows/deploy.yml` | self-hosted runner `actions.runner.teanores-nof-ht.hbl-runner.service` | Temporary legacy exception until migrated to release-builder |
| `nof-mp` | Owner-approved manual tag deploy | none | `/opt/nof-release-builder/nof-release-builder.sh deploy nof-mp <tag>` | Reliable when manually invoked; not GitHub Actions driven |
| `nof-tt` | Owner-approved manual tag deploy | none | `/opt/nof-release-builder/nof-release-builder.sh deploy nof-tt <tag>` | Supported by release-builder; runtime still has legacy `forge-tasks` cleanup debt |

Additional hbl state:

- `nof-release-builder-sync.timer` runs every 5 minutes and calls `nof-release-builder-sync.service`.
- The release-builder supports service keys `nof-mp`, `nof-tt` and `nof-ht`.
- `nof-ht` GitHub Actions and release-builder both exist today, so the authoritative deployment path is not yet singular.

Until migration is complete, agents must state which path they are using before any release-bound action:

- legacy GitHub Actions runner path for `nof-ht`;
- canonical scoped release-builder path for `nof-mp` and `nof-tt`;
- no broad multi-service sync unless every enabled service is explicitly approved in the current conversation.

## Accepted Standard - 2026-06-11

Use `nof-infra` release-builder and desired-state as the canonical production deployment path for NOF services.

GitHub Actions may remain useful for service-local CI checks, but production deploy is only canonical when it delegates to `nof-infra` release-builder and follows the same owner approval, evidence and rollback gates.

`nof-ht` remains a temporary legacy exception on GitHub Actions until `MANUAL-INFRA-RUNNER-HEALTH` and a dedicated migration task close the runner/backoff and release-builder parity gaps.

## Current Release Alignment - 2026-06-10

Local service repository tags currently verified:

| Service | Current tag | Desired-state row | Notes |
| --- | --- | --- | --- |
| `nof-mp` | `v0.2.17` | `v0.2.17`, enabled | Auth/compliance release accepted locally; any hbl sync still requires owner release approval. |
| `nof-tt` | `v0.2.5` | `v0.2.5`, enabled | Telegram-auth cleanup release accepted locally; Task Tracker MCP endpoint remains `task-tracker.forgath.ru/api/mcp`. |
| `nof-ht` | `v1.33.51` | `v1.33.51`, disabled | nof-ht uses GitHub Actions runner path today; release-builder row remains disabled until CI/CD standard decision. |

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

## Open Cleanup

- Migrate `nof-ht` production deploy from GitHub Actions to the release-builder standard.
- Add runner health, backoff recovery and owner-facing incident steps if GitHub Actions remains part of the standard.
- Confirm whether the hbl GitHub Actions runner is still needed after the hbl timer release-builder flow is stable.
- Rename remaining hbl systemd/unit documentation from legacy wording to NOF service keys after accepted UAT.
- Decide database and system-user naming separately from this deployment ownership document.
