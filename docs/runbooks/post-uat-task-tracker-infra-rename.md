# Post-UAT Task Tracker Infrastructure Rename

Status: prepared; do not execute before accepted owner UAT.
Date: 2026-06-06.

Purpose: finish the Task Tracker infrastructure rename after `nof-tt` v0.2.0 is deployed and accepted by the owner.

This runbook is a checklist only. Production and hbl changes require explicit owner approval in the current conversation.

## Scope

Canonical target names:

| Resource type | Target |
| --- | --- |
| Service key | `nof-tt` |
| Release-builder service | `nof-tt` |
| Docker image | `localhost:32000/nof-tt:<tag>` |
| Helm release | `nof-tt` |
| Kubernetes service/deployment | `nof-tt` |
| Public host | `task-tracker.forgath.ru` |
| OAuth secret resource | `nof-tt-oauth-secrets` |
| Security audit secret resource | `nof-tt-security-audit` |

Legacy names allowed only as rollback/history references:

- `forge-tasks`
- `forge-tasks.forgath.ru`
- `localhost:32000/forge-tasks:*`
- `forge-tasks-oauth-secrets`
- `forge-tasks-security-audit`

## Preconditions

- Owner explicitly accepted Task Tracker production UAT.
- `https://task-tracker.forgath.ru` smoke passed.
- Platform OAuth login from `https://forgath.ru/services/task-tracker` passed.
- MCP `tools/list`, `get_delivery_model` and `list_tracker_snapshot` passed through `https://task-tracker.forgath.ru/api/mcp`.
- The previous working Helm release/revision and image tag are recorded.
- Backups for gateway/Caddy and release-builder are recorded.
- No secret value is printed, copied into docs, or committed.

## Read-Only Discovery

Record names and revisions only:

```bash
sudo microk8s helm3 list -n nof-apps
sudo microk8s kubectl get deploy,svc,secret,configmap -n nof-apps
sudo microk8s kubectl get ingress -A
```

Expected after nof-tt deployment:

- `nof-tt` Helm release exists.
- `nof-tt` deployment is ready.
- `nof-tt` service exists.
- `nof-tt-oauth-secrets` exists.
- `nof-tt-security-audit` exists if the app still needs that secret.
- `forge-tasks` release/service/deployment is not serving live traffic.

## Rename And Cleanup Steps

Run only after explicit owner approval.

1. Confirm `environments/hbl/desired-state.tsv` uses:
   - `nof-tt<TAB>v0.2.0<TAB>true` during release window;
   - or the current accepted nof-tt release tag after promotion.
2. Confirm `release-builder/nof-release-builder.sh list` shows `nof-tt`.
3. Confirm `helm/nof-tt` renders with:
   - image repository `localhost:32000/nof-tt`;
   - service/deployment name `nof-tt`;
   - host env pointing to `https://task-tracker.forgath.ru`.
4. If legacy secret resources still exist, copy data into canonical resources without printing values.
5. Restart or redeploy only the affected service after secret resource rename.
6. Smoke canonical route and MCP.
7. Disable or remove the old public hostname `forge-tasks.forgath.ru`.
8. Remove any legacy release-builder state files that would redeploy `forge-tasks`.
9. Keep old images and Helm revision history until at least one accepted nof-tt release window has passed.

## Stop Conditions

Stop immediately if:

- a secret value appears in command output, logs, Wiki or chat;
- `task-tracker.forgath.ru` TLS fails;
- OAuth start/callback fails after rename;
- MCP fails through canonical host;
- the wrong user session is used;
- a synthetic user is created where an existing platform identity should link;
- rollback target is unknown;
- desired state would deploy `forge-tasks` as a live service.

## Verification

After cleanup, run local preflight before pushing nof-infra changes:

```powershell
.\scripts\release-preflight.ps1 -Service nof-tt -ExpectedRef v0.2.0 -Environment hbl
```

Expected:

- no live infra target file contains `localhost:32000/forge-tasks`;
- no live infra target file contains Helm release/service/app label `forge-tasks`;
- no edge target contains `forge-tasks.forgath.ru` as a live hostname;
- docs may still contain legacy names only in rollback/history sections.

## Rollback

If cleanup fails before legacy resources are removed:

1. Restore gateway/Caddy backup captured before the cleanup window.
2. Roll back the current nof-tt Helm release to the recorded previous revision:

```bash
sudo microk8s helm3 rollback nof-tt <previous-revision> -n nof-apps --wait --timeout 180s
```

3. If rollback requires the pre-rename release, use the read-only discovery evidence to restore the observed legacy release. Do not guess release names.
4. Smoke the endpoint that was live before the cleanup window.

## Evidence To Record

- Owner approval text.
- Release-builder control ref.
- nof-tt source ref and deployed commit.
- Helm release name and revision.
- Image repository and tag.
- Smoke results.
- Owner UAT result.
- Rollback command or first-revision rollback note.
