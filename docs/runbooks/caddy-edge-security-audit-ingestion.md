# Caddy Edge Security Audit Ingestion

Status: draft, production changes require owner approval.
Tracker task: `MANUAL-7708F9E2`.

## Purpose

Feed public edge access events into the nof-mp admin security dashboard without exposing secret values or internal addresses in the UI.

This complements application audit events emitted by nof-mp itself. It is not a replacement for app-level login/admin audit events.

## Target Components

- nof-mp hidden ingest endpoint: `https://forgath.ru/api/admin/security/edge-events`
- Kubernetes secret: `nof-mp-security-audit`
- Kubernetes env var in nof-mp pod: `NOF_SECURITY_AUDIT_INGEST_TOKEN`
- VPS Caddy JSON access log: `/var/log/caddy/forgath-access.log`
- VPS collector script: `/usr/local/bin/nof-ship-caddy-security-audit`
- VPS collector state: `/var/lib/nof-edge-audit/offset`
- systemd service/timer: `nof-edge-audit-shipper.service` / `nof-edge-audit-shipper.timer`

## Secret Rules

- Never print, decode or paste the token value.
- Metadata-only checks are allowed:
  - secret exists;
  - key exists;
  - base64 length is non-zero;
  - pod env name is present.
- If copying an existing token from a legacy secret, pipe Kubernetes objects directly; do not render values in chat or files.

## Prepared Repository State

- `helm/nof-mp/values.yaml` mounts:
  - `NOF_SECURITY_AUDIT_INGEST_TOKEN`
  - from secret `nof-mp-security-audit`
  - key `edge-ingest-token`
- `environments/hbl/edge/vps-caddy/Caddyfile.target` mirrors the current VPS Caddy shape: TLS edge proxies to `127.0.0.1:18080`, the hbl reverse tunnel forwards that to `portal-gateway`, and Caddy writes filtered JSON access logs to `/var/log/caddy/forgath-access.log`.
- `scripts/ship-caddy-security-audit.sh` ships only new log bytes to the nof-mp ingest endpoint and records an offset.

## Read-Only Discovery Notes

Observed on 2026-06-08:

- hbl service `nof-tunnel-hbl-vps.service` maintains a reverse SSH tunnel to `noftunnelhblvps@176.12.67.92`.
- VPS host name: `forgath.ru`.
- VPS Caddy binary: `/usr/bin/caddy`.
- VPS Caddyfile: `/etc/caddy/Caddyfile`.
- Public ports on VPS: 80/443; tunnel port listens on `127.0.0.1:18080`.
- Existing access log: `/var/log/caddy/forgath-access.log`, owner `caddy:caddy`, mode `0640`.
- Existing log filter removes `Authorization`, `Cookie`, `X-Api-Key`, `X-Telegram-Bot-Api-Secret-Token` and `Set-Cookie`.
- The tunnel user can connect and read the world-readable Caddyfile, but it cannot read Caddy logs or run sudo. Installing the shipper requires a root-capable maintenance step on the VPS.

## Production Apply Plan

Do not run without owner approval in the current conversation.

1. Create or confirm `nof-mp-security-audit`.

   If reusing an existing approved token, copy data server-side without printing values. Example shape:

   ```bash
   sudo microk8s kubectl get secret nof-tt-security-audit -n nof-apps -o yaml \
     | sed 's/name: nof-tt-security-audit/name: nof-mp-security-audit/' \
     | sudo microk8s kubectl apply -n nof-apps -f -
   ```

   Prefer a new token when rotation ownership is agreed.

2. Deploy or upgrade nof-mp with the updated Helm chart so the pod has `NOF_SECURITY_AUDIT_INGEST_TOKEN`.

3. Verify metadata only:

   ```bash
   sudo microk8s kubectl exec -n nof-apps deploy/nof-mp -- sh -c \
     'printenv | grep "^NOF_SECURITY_AUDIT_INGEST_TOKEN=" >/dev/null && echo ingest_token=SET || echo ingest_token=MISSING'
   ```

4. Confirm VPS Caddyfile still matches the repository target or intentionally record the delta.

   Do not apply the target if it would remove unknown live hostnames or tunnel ports.

5. Backup VPS Caddyfile before any Caddy change:

   ```bash
   sudo cp /etc/caddy/Caddyfile /etc/caddy/Caddyfile.backup-$(date -u +%Y%m%dT%H%M%SZ)
   ```

6. Validate Caddy as a user that can write the configured Caddy logs, usually root or caddy:

   ```bash
   sudo caddy validate --config /etc/caddy/Caddyfile
   ```

7. Reload Caddy only if the config actually changed:

   ```bash
   sudo systemctl reload caddy
   ```

8. Install collector script:

   ```bash
   sudo install -m 0755 scripts/ship-caddy-security-audit.sh /usr/local/bin/nof-ship-caddy-security-audit
   ```

9. Create `/etc/nof-edge-audit.env` with token reference out of band. Do not write values to tracker, Wiki or chat.

   Required names:

   ```text
   NOF_EDGE_AUDIT_TOKEN=<secret value>
   NOF_EDGE_AUDIT_ENDPOINT=https://forgath.ru/api/admin/security/edge-events
   NOF_EDGE_AUDIT_LOG_FILE=/var/log/caddy/forgath-access.log
   NOF_EDGE_AUDIT_STATE_FILE=/var/lib/nof-edge-audit/offset
   ```

10. Install systemd service and timer.

   The service user must be able to read `/var/log/caddy/forgath-access.log` without broadening public permissions. Preferred options:

   - run the oneshot shipper as `root` with `NoNewPrivileges=true`, `ProtectSystem=strict` and read/write path exceptions;
   - or create a dedicated `nof-edge-audit` user and grant it read access through the `caddy` group or ACL.

   ```ini
   [Unit]
   Description=Ship NOF Caddy edge access logs to nof-mp security audit

   [Service]
   Type=oneshot
   User=root
   EnvironmentFile=/etc/nof-edge-audit.env
   ExecStart=/usr/local/bin/nof-ship-caddy-security-audit
   NoNewPrivileges=true
   PrivateTmp=true
   ProtectHome=true
   ProtectSystem=strict
   ReadOnlyPaths=/var/log/caddy
   ReadWritePaths=/var/lib/nof-edge-audit
   ```

   ```ini
   [Unit]
   Description=Run NOF edge audit shipper every minute

   [Timer]
   OnBootSec=1min
   OnUnitActiveSec=1min
   Unit=nof-edge-audit-shipper.service

   [Install]
   WantedBy=timers.target
   ```

11. Enable timer:

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now nof-edge-audit-shipper.timer
   ```

## Verification

1. Unauthorized endpoint remains hidden:

   ```bash
   curl -i -X POST https://forgath.ru/api/admin/security/edge-events --data '{}'
   ```

   Expected: JSON `404`.

2. Generate safe synthetic edge traffic:

   ```bash
   curl -i https://forgath.ru/.well-known/nof-edge-audit-smoke
   ```

3. Run shipper once:

   ```bash
   sudo systemctl start nof-edge-audit-shipper.service
   sudo systemctl status nof-edge-audit-shipper.service --no-pager
   ```

4. Owner opens `https://forgath.ru/admin/security`.

   Expected:

   - latest events include edge request/not found entries;
   - 404 / unknown or scan counters reflect safe synthetic traffic;
   - no secret values or internal IPs are shown.

## Rollback

1. Stop collector:

   ```bash
   sudo systemctl disable --now nof-edge-audit-shipper.timer
   ```

2. Restore previous Caddyfile backup and reload Caddy.

3. Roll back nof-mp Helm release if the secret env mount causes rollout failure.

4. Keep `nof-mp-security-audit` until rotation/cleanup is explicitly approved.

## Stop Conditions

- Any command would print the token value.
- nof-mp rollout fails after mounting the secret.
- Caddy validation fails.
- Collector logs reveal secret values.
- `/admin/security` shows raw internal addresses, tokens or unsanitized query secrets.
