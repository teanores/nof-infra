# Portal Gateway Declarative State

Status: active migration guard.
Owner: nof-infra.

## Purpose

Keep hbl `portal-gateway` routing aligned with NOF service keys and prevent manual-only production state.

## Current Production State

As of 2026-06-05, owner approved deployment of `nof-mp` v0.2.0.

- Public platform host: `https://forgath.ru`
- Platform service key: `nof-mp`
- Live platform upstream inside `portal-gateway`: `nof-mp:3000`
- Legacy rollback upstream: `nof-platform:3000`
- ConfigMap backup before switch: `/home/nofadminhbl/portal-gateway-configmap.backup-20260605T2110Z.yaml`
- Smoke checks after switch:
  - `https://forgath.ru/login` -> 200
  - `https://forgath.ru/services/task-tracker` -> 200

## Required Target State

- `nof-infra` must own the `portal-gateway` chart or a generated ConfigMap artifact.
- Service upstreams must use service keys:
  - `nof-mp` for platform routes.
  - `nof-tt` for Task Tracker routes after separate owner approval.
  - `nof-ht` for Habit Tracker routes.
- Public hostnames may use product names such as `task-tracker.forgath.ru`.
- Legacy names are allowed only in rollback notes and historical evidence.

## Rollback

If owner rejects production UAT for `nof-mp` v0.2.0:

1. Restore the gateway backup on hbl:
   `sudo microk8s kubectl apply -f /home/nofadminhbl/portal-gateway-configmap.backup-20260605T2110Z.yaml`
2. Restart the gateway:
   `sudo microk8s kubectl rollout restart deployment/portal-gateway -n nof-apps`
3. Wait for rollout:
   `sudo microk8s kubectl rollout status deployment/portal-gateway -n nof-apps --timeout=180s`
4. Disable `nof-mp` in `environments/hbl/desired-state.tsv` and push nof-infra.
5. Optionally uninstall the first-revision `nof-mp` release after investigation:
   `sudo microk8s helm3 uninstall nof-mp -n nof-apps`

Do not use `helm rollback nof-mp 0`; first-revision releases have no previous Helm revision.

## Stop Conditions

- Any public platform route returns a blank page or unexpected 5xx.
- OAuth flow creates a synthetic user instead of explicit account authorization.
- Gateway config contains an unintended legacy service as the live target.
- A rollback would require reading or printing secret values.
