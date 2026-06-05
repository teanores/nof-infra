# CI/CD Ownership

Status: draft.
Owner: nof-main / nof-infra.
Tracker task: `MANUAL-E2D0E876`.

## Decision

`nof-infra` is the canonical repository for deployment and environment management that is not service application code.

Service repositories own code, tests and service-local runtime configuration examples. `nof-infra` owns cross-service deployment definitions and environment desired-state.

## Expected Flow

```text
GitHub merge/tag/release
  -> CI/CD trigger
  -> hbl deploy agent or runner
  -> nof-infra release-builder/Helm definitions
  -> MicroK8s namespace nof-apps
```

## Discovery Questions

- What currently receives GitHub merge/tag/release events?
- Is the deploy component a GitHub Actions runner, webhook receiver, cron, systemd unit, Kubernetes job or manual script?
- Where are release-builder scripts stored today?
- Which identifiers are currently used for images and Helm releases?
- Which secrets are required by name only, and which service owns each secret?

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

## Naming Rule

Infrastructure keys must use service keys:

| Service | Release key | Image | Helm release | Public host |
| --- | --- | --- | --- | --- |
| Main Platform | `nof-mp` | `nof-mp` | `nof-mp` | `forgath.ru` |
| Task Tracker | `nof-tt` | `nof-tt` | `nof-tt` | `task-tracker.forgath.ru` |
| Habit Tracker | `nof-ht` | `nof-ht` | `nof-ht` | `habit-tracker.forgath.ru` |
| Coffee Bot | `nof-cb` | `nof-cb` | `nof-cb` | to confirm |

`task-tracker` is allowed as a public hostname/product display name, not as a Helm/image/release-builder key.
