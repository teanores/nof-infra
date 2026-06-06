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
- Live Task Tracker public host in VPS Caddy: `task-tracker.forgath.ru`
- Live Task Tracker `server_name` inside `portal-gateway`: `task-tracker.forgath.ru`
- Legacy rollback upstream: `nof-platform:3000`
- ConfigMap backup before switch: `/home/nofadminhbl/portal-gateway-configmap.backup-20260605T2110Z.yaml`
- ConfigMap backup before removing legacy Task Tracker hostname: `/home/nofadminhbl/portal-gateway-configmap.backup-20260605T2134Z.yaml`
- VPS Caddy backup before removing legacy Task Tracker hostname: `/etc/caddy/Caddyfile.backup-20260605T2134Z`
- Smoke checks after switch:
  - `https://forgath.ru/login` -> 200
  - `https://forgath.ru/services/task-tracker` -> 200

## Required Target State

- `nof-infra` owns target edge artifacts:
  - VPS Caddy target: `environments/hbl/edge/vps-caddy/Caddyfile.target`
  - hbl portal-gateway target: `environments/hbl/edge/portal-gateway-configmap.target.yaml`
- Service upstreams must use service keys:
  - `nof-mp` for platform routes.
  - `nof-tt` for Task Tracker routes after separate owner approval.
  - `nof-ht` for Habit Tracker routes.
- Public hostnames may use product names such as `task-tracker.forgath.ru`.
- Legacy names are allowed only in rollback notes and historical evidence.
- `forge-tasks.forgath.ru` must not remain as a live public hostname after the Task Tracker cutover.

## Apply Procedure

Only run these steps after explicit owner approval in the current conversation.

1. Verify hbl and VPS access.
2. Backup live files before changing them:
   - VPS Caddy: `/etc/caddy/Caddyfile.backup-<timestamp>`
   - hbl portal-gateway: `/home/nofadminhbl/portal-gateway-configmap.backup-<timestamp>.yaml`
3. Compare target state with live state. Do not apply if the diff includes an unknown hostname, unknown upstream, or secret-bearing data.
4. Apply VPS Caddy target, validate, then reload:
   - `sudo caddy validate --config /etc/caddy/Caddyfile`
   - `sudo systemctl reload caddy`
5. Apply hbl portal-gateway target, restart, then wait for rollout:
   - `sudo microk8s kubectl apply -f portal-gateway-configmap.target.yaml`
   - `sudo microk8s kubectl rollout restart deployment/portal-gateway -n nof-apps`
   - `sudo microk8s kubectl rollout status deployment/portal-gateway -n nof-apps --timeout=180s`
6. Smoke:
   - `https://forgath.ru/login` -> 200
   - `https://forgath.ru/services/task-tracker` -> 200 or expected redirect
   - `https://task-tracker.forgath.ru/auth/platform/start?next=%2Fprojects` -> OAuth redirect after nof-tt deployment
   - `https://habit-tracker.forgath.ru` -> 200 or expected auth redirect

## Current Offline Limitation

The target artifacts were prepared offline while hbl was unavailable. Before production use, validate them against live hbl/VPS state and update the files if live non-secret routing contains required settings not present here.

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

If Task Tracker domain cutover is rejected before `nof-tt` deployment, restore these backups:

1. VPS Caddy: `/etc/caddy/Caddyfile.backup-20260605T2134Z`, then `sudo caddy validate --config /etc/caddy/Caddyfile` and `sudo systemctl reload caddy`.
2. hbl portal-gateway: `/home/nofadminhbl/portal-gateway-configmap.backup-20260605T2134Z.yaml`, then restart and wait for `deployment/portal-gateway`.

## Stop Conditions

- Any public platform route returns a blank page or unexpected 5xx.
- OAuth flow creates a synthetic user instead of explicit account authorization.
- Gateway config contains an unintended legacy service as the live target.
- A rollback would require reading or printing secret values.
