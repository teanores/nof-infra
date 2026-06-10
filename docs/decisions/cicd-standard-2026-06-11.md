# CI/CD Standard Decision - 2026-06-11

Status: accepted working standard for June beta hardening.
Owner: nof-main / nof-infra.
Tracker: `NOF-INFRA-SPRINT-CICD-20260611`, task `MANUAL-INFRA-CICD-STANDARD`.

## Context

NOF currently has more than one production delivery path:

- `nof-mp` is deployed through hbl release-builder commands.
- `nof-tt` is deployed through hbl release-builder commands.
- `nof-ht` is deployed through GitHub Actions on a self-hosted hbl runner.
- hbl also has `nof-release-builder-sync.timer`, so desired-state can become production-bound if pushed to the active control branch.

This hybrid works, but it is operational technical debt. Agents must not guess which path owns a service during release work.

## Decision

The canonical production deployment model for NOF services is:

```text
service repository tag
  -> nof-infra desired-state / release-builder
  -> hbl MicroK8s / Helm release
  -> owner UAT acceptance
```

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

GitHub Actions may be used for service-local CI checks, but production deploy is not considered canonical unless the action delegates to `nof-infra` release-builder and follows the same owner approval, evidence and rollback gates.

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

## Follow-Up Tasks

- `MANUAL-INFRA-DESIRED-STATE`: align and document hbl desired-state.
- `MANUAL-INFRA-RUNNER-HEALTH`: document hbl runner health/backoff while nof-ht remains on the legacy path.
- `MANUAL-INFRA-PREFLIGHT`: verify release-builder preflight and readiness checks.
