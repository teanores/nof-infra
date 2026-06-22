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

## Token Rotation Path

Use this path for `NOF-INFRA-17` / `NOF-MP-13` edge audit ingest token rotation.

The standard path is:

1. Prepare a new token out of band. Do not paste it into chat, tracker, Wiki, logs or git.
2. Confirm the owner approved the exact rotation window in the current chat.
3. Apply the updated Kubernetes Secret through the approved release-builder / GitHub runner release window, or use the NOF-INFRA-16 emergency manual flow only if explicitly approved.
4. Deploy or restart nof-mp through the same approved release window so the pod reads the updated `nof-mp-security-audit` value.
5. Run metadata-only verification.
6. Run owner UAT on the admin security dashboard.

Required approval packet before any live rotation:

- target secret name: `nof-mp-security-audit`;
- target key: `edge-ingest-token`;
- service affected: `nof-mp`;
- deployment path: `github-runner release-builder` unless emergency/manual mode is explicitly approved;
- evidence id: tracker task or current-chat approval reference;
- rollback condition and UAT steps.

Manual/emergency SSH flow remains available only under the release-builder guardrails in `docs/runbooks/github-runner-release-builder.md`:

```bash
NOF_RELEASE_MANUAL_OVERRIDE=1
NOF_RELEASE_APPROVAL_ID='<current-chat-owner-approval-or-tracker-evidence-id>'
```

Do not use manual flow as the routine product-agent path.

### Metadata-Only Preflight

Local dry run, safe by default:

```powershell
just check-edge-audit-token-dry-run
```

This prints the hbl read-only commands but does not run SSH.

Live read-only preflight, only after the owner approves reading hbl metadata:

```powershell
just check-edge-audit-token
```

The commands must only print:

- `edge-ingest-token length=<number>`;
- `NOF_SECURITY_AUDIT_INGEST_TOKEN=SET` or `MISSING`.

They must not decode or print the token value.

### Post-Rotation Verification

After the approved deploy/restart:

```powershell
just check-edge-audit-token-live
```

Expected:

- secret `nof-mp-security-audit` exists;
- key `edge-ingest-token` exists and has a non-zero encoded length;
- nof-mp pod reports `NOF_SECURITY_AUDIT_INGEST_TOKEN=SET`;
- no token value appears in command output.

Owner UAT:

1. Open `https://forgath.ru/admin/security`.
2. Generate safe public traffic:

   ```bash
   curl -i https://forgath.ru/.well-known/nof-edge-audit-smoke
   ```

3. Confirm edge request / not-found activity appears in the security dashboard.

Expected:

- edge events are visible;
- no raw token, cookie, authorization header or internal address is visible.

### Rotation Rollback

If nof-mp fails to ingest events or the pod does not expose the env:

1. Stop the collector timer if it is running:

   ```bash
   sudo systemctl disable --now nof-edge-audit-shipper.timer
   ```

2. Restore the previous approved `nof-mp-security-audit` key value out of band without printing it.
3. Roll back or restart nof-mp through the approved release-builder path.
4. Re-run metadata-only verification.
5. Keep both the failed rotation evidence and rollback evidence in tracker without secret values.

Stop immediately if any command would print the token value, the dashboard shows raw token-like data, or the approved service/ref differs from the actual target.

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
