# Portal Gateway CSP form-action Hotfix

Status: prepared, not applied.
Owner: nof-infra.
Tracker: `NOF-INFRA-40`, sprint `NOF-INFRA-SPRINT-19`.

## Purpose

Fix the confirmed production defect where the platform consent page at
`https://forgath.ru/oauth/consent` cannot complete first-time product login.

The current platform CSP uses:

```text
form-action 'self'
```

The consent approve form posts to the platform and then redirects to trusted
first-party product callback origins. Browsers enforce `form-action` against
that redirect target, so the approve navigation is blocked for product callback
origins.

## Prepared Change

File:

```text
environments/hbl/edge/portal-gateway-configmap.target.yaml
```

Only the `forgath.ru www.forgath.ru _` server block is changed:

```text
form-action 'self' https://task-tracker.forgath.ru https://habit-tracker.forgath.ru
```

No other CSP directive is broadened. Product server blocks remain unchanged.

## Local Verification

Run before production apply:

```powershell
just test
git diff --check
```

Expected:

- `tests/portal-gateway-security-headers.ps1` confirms the platform server
  block emits enforced CSP;
- platform `frame-ancestors 'self'` remains present;
- platform `form-action` allows only the two trusted product origins;
- Task Tracker server block remains present and keeps `frame-ancestors 'self'`;
- no hbl/VPS commands are run by local tests.

## Production Gate

This is a production-changing edge config update.

Do not apply or reload until the owner gives explicit GO in the current chat.

## Apply Procedure

Use the existing portal-gateway declarative procedure after owner GO.

On hbl:

```bash
ts="$(date -u +%Y%m%dT%H%M%SZ)"
sudo microk8s kubectl get configmap portal-gateway -n nof-apps -o yaml \
  > "/home/nofadminhbl/portal-gateway-configmap.backup-${ts}.yaml"

sudo microk8s kubectl apply -f portal-gateway-configmap.target.yaml
sudo microk8s kubectl rollout restart deployment/portal-gateway -n nof-apps
sudo microk8s kubectl rollout status deployment/portal-gateway -n nof-apps --timeout=180s
```

If applying from the local agent, copy only the reviewed target file to a temp
path on hbl and run the same commands. Do not print secret values.

## Live Verification

After rollout:

```bash
curl -sI https://forgath.ru/login | grep -i '^content-security-policy:'
curl -sI https://task-tracker.forgath.ru/ | grep -i '^content-security-policy:'
curl -sI https://habit-tracker.forgath.ru/ | grep -i '^content-security-policy:'
```

Expected:

- `https://forgath.ru/login` CSP contains:
  `form-action 'self' https://task-tracker.forgath.ru https://habit-tracker.forgath.ru`;
- product hosts still keep enforced CSP and `frame-ancestors 'self'`;
- no secret values appear in logs.

Owner UAT:

1. Open `https://forgath.ru`.
2. Launch Task Tracker.
3. On consent, click `Продолжить`.
4. Expected: browser reaches `https://task-tracker.forgath.ru/projects` or the
   expected Task Tracker authenticated landing flow; user is not stuck on
   consent.
5. Continue Phase 3 isolation UAT: regular user A must not see user B's
   projects.

## Rollback

Rollback requires owner approval unless it is an immediate failed-apply stop
condition during the same approved window.

Use the recorded backup:

```bash
sudo microk8s kubectl apply -f /home/nofadminhbl/portal-gateway-configmap.backup-<timestamp>.yaml
sudo microk8s kubectl rollout restart deployment/portal-gateway -n nof-apps
sudo microk8s kubectl rollout status deployment/portal-gateway -n nof-apps --timeout=180s
```

Expected rollback CSP on `forgath.ru`:

```text
form-action 'self'
```

## Stop Conditions

Stop and do not proceed if:

- owner GO is missing;
- local diff touches anything except the platform server block CSP form-action,
  the security header test, this runbook, and evidence/memory updates;
- `just test` or `git diff --check` fails;
- live header after apply does not contain the expected product origins;
- product hosts lose `frame-ancestors 'self'`;
- any secret value appears in terminal output, logs, Wiki, tracker, or git.
