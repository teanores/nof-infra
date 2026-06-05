# OAuth Release Cutover Runbook

Status: draft.
Purpose: prepare the NOF OAuth release without running production changes until owner approval.

## Target

- `nof-mp` is the platform identity provider.
- `nof-tt` and `nof-ht` use standard OAuth login with `nof-mp`.
- Legacy product exchange does not create synthetic cross-service users.
- Public Task Tracker URL is `https://task-tracker.forgath.ru`.

## Pre-Release Gates

- nof-mp tests, typecheck, lint, build and audit pass locally.
- nof-tt and nof-ht OAuth contracts are documented and accepted.
- hbl deploy mechanism is understood and recorded in `nof-infra`.
- Secrets are present by name in the correct Kubernetes secrets, without exposing values.
- Owner gives explicit production UAT approval.

## Stop Conditions

- Any secret value appears in logs, terminal output, docs or commits.
- OAuth creates a synthetic user instead of redirecting to login/registration.
- Existing service session overrides platform identity across products.
- `forge-tasks.forgath.ru` remains active after accepted hard cutover unless owner explicitly changes the decision.
- Helm/image/release-builder keys use display names instead of service keys.

## Rollback Notes

Rollback commands must be filled after hbl discovery confirms the current Helm release names and deployment mechanism.
