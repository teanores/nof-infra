# hbl GitHub Actions Runner Health

Status: active runbook for the temporary nof-ht legacy deploy path.
Owner: nof-infra.
Tracker: `MANUAL-INFRA-RUNNER-HEALTH`.

## Purpose

Document how to inspect and recover the hbl self-hosted GitHub Actions runner used by `nof-ht` while `nof-ht` remains on the temporary legacy GitHub Actions deploy path.

This runner is not the target production deployment standard. The accepted target is `nof-infra` release-builder and desired-state. Use this runbook only until nof-ht is migrated.

## Current State - 2026-06-11

Read-only hbl discovery found:

- systemd unit: `actions.runner.teanores-nof-ht.hbl-runner.service`;
- service user: `nofadminhbl`;
- working directory: `/home/nofadminhbl/actions-runner`;
- state: loaded, enabled and active;
- runner process: `/home/nofadminhbl/actions-runner/bin/Runner.Listener run --startuptype service`;
- latest observed nof-ht deploy job completed successfully at `2026-06-10T22:18:03Z`;
- service unit has no explicit `Restart=` policy;
- nof-ht workflow file: `nof-ht/.github/workflows/deploy.yml`;
- workflow trigger: push to `main`;
- workflow runner labels: `self-hosted`, `linux`, `nof-ht`.

## Known Risks

- GitHub broker disconnect/backoff can leave deploy jobs queued for a long time.
- The runner service has no explicit systemd restart policy.
- nof-ht workflow deploys from push to `main`, not from an owner-approved release-builder desired-state row.
- nof-ht Docker image tag is the short commit SHA, while NOF release policy requires semver for user-facing production releases.
- The migration step reads `DATABASE_URL` from a Kubernetes secret into a shell variable. It does not print the value in the current workflow, but any future `set -x`, debug echo or shell failure could leak sensitive data.

## Read-Only Health Checks

Run from the NOF root on the owner laptop:

```powershell
ssh nofadminhbl@192.168.1.51 "systemctl status actions.runner.teanores-nof-ht.hbl-runner.service --no-pager -l | sed -n '1,80p'"
```

Check unit definition:

```powershell
ssh nofadminhbl@192.168.1.51 "systemctl cat actions.runner.teanores-nof-ht.hbl-runner.service"
```

Check recent logs without secret values:

```powershell
ssh nofadminhbl@192.168.1.51 "journalctl -u actions.runner.teanores-nof-ht.hbl-runner.service -n 120 --no-pager -o short-iso"
```

Look for:

- `Active: active (running)`;
- recent `Runner.Listener`;
- recent `Job deploy completed with result: Succeeded`;
- reconnect/backoff messages;
- repeated job failures;
- any accidental secret-looking output.

Stop and escalate if logs show secret values.

## Owner-Approved Recovery Ladder

These actions change hbl runtime state and require explicit owner approval in the current conversation.

1. Read-only evidence first:

```bash
systemctl status actions.runner.teanores-nof-ht.hbl-runner.service --no-pager -l
journalctl -u actions.runner.teanores-nof-ht.hbl-runner.service -n 120 --no-pager -o short-iso
```

2. If the runner is stopped or stuck in broker backoff, restart only the runner:

```bash
sudo systemctl restart actions.runner.teanores-nof-ht.hbl-runner.service
```

3. Verify reconnect:

```bash
systemctl status actions.runner.teanores-nof-ht.hbl-runner.service --no-pager -l
journalctl -u actions.runner.teanores-nof-ht.hbl-runner.service -n 80 --no-pager -o short-iso
```

4. If deploy remains blocked, choose one owner-approved path:

- wait for GitHub backoff to expire;
- restart runner again once, with evidence;
- bypass with `nof-infra` release-builder only if nof-ht release-builder migration has been approved and tested.

Do not restart unrelated services, Kubernetes, Docker, MicroK8s or Postgres to fix a runner-only issue.

## Hardening Backlog

- Add explicit runner service restart policy or a watchdog only after reviewing GitHub runner service recommendations.
- Move nof-ht production deploy to `nof-infra` release-builder.
- Change nof-ht production image/version policy from short SHA to semver release tag.
- Replace secret-in-shell migration handling with a safer service-owned migration mechanism or a release-builder migration step that never exposes secret values.
- Add a runner health check to release readiness evidence while nof-ht remains on GitHub Actions.

## Stop Conditions

Stop and ask the owner if:

- secret values appear in logs;
- the runner service repeatedly restarts;
- GitHub Actions deploy job is queued but the runner is active and no backoff message is visible;
- nof-ht production is serving the wrong version after a successful job;
- a recovery action would touch anything outside the runner service.
