# CI/CD Ownership

Status: draft, current working standard.
Owner: nof-main / nof-infra.
Tracker task: `MANUAL-38757CBE`.
Related runbook: `../runbooks/hbl-release-builder-migration.md`.

## Decision

`nof-infra` is the canonical repository for deployment and environment management that is not service application code.

Service repositories own code, tests and service-local runtime configuration examples. `nof-infra` owns cross-service deployment definitions and environment desired-state.

Secrets are not owned by `nof-infra` as values. This repository may document secret names, ownership, mount points and rollout steps, but secret values stay in the target environment secret store and must not be printed into tickets, Wiki, logs or commits.

## Expected Flow

```text
GitHub merge/tag/release
  -> CI/CD trigger
  -> hbl deploy agent or runner
  -> nof-infra release-builder control manifest and Helm definitions
  -> MicroK8s namespace nof-apps
```

The current target release-builder control file is `environments/hbl/desired-state.tsv`.

Current target script defaults:

- control repo: `https://github.com/teanores/nof-infra.git`;
- control manifest: `environments/hbl/desired-state.tsv`;
- service keys: `nof-mp`, `nof-tt`, `nof-ht`.

Historical hbl state may still include legacy service names such as `nof-platform` and `forge-tasks`. Treat those names as migration inventory only unless a rollback runbook explicitly says otherwise.

## Discovery Questions

- What currently receives GitHub merge/tag/release events?
- Is the deploy component a GitHub Actions runner, webhook receiver, cron, systemd unit, Kubernetes job or manual script?
- Which component is authoritative after migration: GitHub Actions runner, hbl timer or both?
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

- Confirm whether the hbl GitHub Actions runner is still needed after the hbl timer release-builder flow is stable.
- Rename remaining hbl systemd/unit documentation from legacy wording to NOF service keys after accepted UAT.
- Decide database and system-user naming separately from this deployment ownership document.
