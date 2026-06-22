# GitHub Runner Release-Builder Runbook

Status: live and verified. The `teanores/nof-infra` runner was registered and a real no-op production deploy succeeded on 2026-06-21 (nof-tt redeployed to its current tag v0.2.29, Helm revision 33). This is now the only correct deploy path — no SSH to hbl required.
Owner: nof-infra.

## Purpose

Use GitHub Actions as the remote release control plane while keeping production deployment logic in `nof-infra` release-builder on hbl.

This path is for times when agents or the owner do not have direct SSH access to hbl.

## Workflow

Workflow file:

```text
.github/workflows/release-builder.yml
```

Mode name for owner-facing communication:

```text
github-runner release-builder
```

## Required hbl Runner

Register a self-hosted GitHub Actions runner for `teanores/nof-infra` or an approved infra scope.

Required labels:

```text
self-hosted
linux
nof-infra
```

The runner host must be hbl, because the job calls:

```bash
/opt/nof-release-builder/nof-release-builder.sh deploy <service> <semver-tag>
```

Do not reuse a product-specific runner label such as `nof-ht` for the target standard.

## Required GitHub Environment

Create a GitHub environment:

```text
hbl-production
```

Required settings:

- owner approval required before deployment jobs can start;
- only trusted branches/tags/workflows may target the environment;
- no secret values should be printed to logs.

## Concurrency Policy

The GitHub Actions workflow must use a per-service concurrency group:

```text
nof-release-builder-hbl-${{ inputs.service }}
```

This keeps unrelated service release requests from blocking each other at the GitHub Actions queue level.

The hbl release-builder script can still keep its local global `mkdir` lock. That host-level lock is a separate safety guard for constrained hbl execution and must not be removed as part of the Actions concurrency policy.

## Workflow Inputs

| Input | Meaning |
| --- | --- |
| `service` | `nof-mp`, `nof-tt`, or `nof-ht` |
| `ref` | semver tag, for example `v0.2.47` |
| `approval_id` | owner approval / tracker evidence id |
| `execute_deploy` | `false` validates only; `true` runs production deploy after GitHub environment approval |
| `nof_ht_migration_gate_approved` | must remain `false` except for an explicitly accepted nof-ht release-builder migration window |

## Dry Run

Use `execute_deploy=false` to validate the request without touching hbl production:

```text
service=nof-mp
ref=v0.2.47
approval_id=IDEA-...
execute_deploy=false
nof_ht_migration_gate_approved=false
```

Expected:

- validate job passes;
- deploy job is skipped;
- no hbl command runs.

## Quick Trigger For Product Agents (gh CLI)

This is the only supported way to deploy `nof-mp`, `nof-tt` or `nof-ht` to hbl. Direct SSH to hbl for deploys is not supported going forward (see NOF-INFRA-16).

Prerequisites:

- `gh` CLI authenticated against `teanores/nof-infra` with `workflow` scope (already true for this workspace).
- An approval/evidence id from the owning project's tracker task (e.g. `NOF-TT-188` or a chat approval line).
- A semver tag that already exists for the service (e.g. `v0.2.29`).

Dry run (always do this first):

```bash
gh workflow run release-builder.yml -R teanores/nof-infra \
  -f service=nof-tt \
  -f ref=v0.2.29 \
  -f approval_id=NOF-TT-188 \
  -f execute_deploy=false
```

Watch it:

```bash
gh run list -R teanores/nof-infra --workflow=release-builder.yml --limit 5
gh run watch -R teanores/nof-infra <run-id>
```

Real deploy, after the dry run passes and the owner has approved in chat:

```bash
gh workflow run release-builder.yml -R teanores/nof-infra \
  -f service=nof-tt \
  -f ref=v0.2.29 \
  -f approval_id=NOF-TT-188 \
  -f execute_deploy=true
```

For `nof-ht`, also pass `-f nof_ht_migration_gate_approved=true` once that gate is explicitly accepted; otherwise the validate step fails closed.

Evidence after a real deploy is written under `~/nof-release-builder/evidence/<service>-<sha>-<timestamp>.txt` on hbl. Read it back via the workflow's "Show latest evidence files" step output (`gh run view -R teanores/nof-infra <run-id> --log`) — do not SSH to hbl to fetch it.

## Local Readiness Checks

Validate the workflow and runbook gates before asking the owner to register the hbl runner:

```powershell
just check-runner-workflow
```

Expected:

- workflow is manual-only;
- deploy job targets `[self-hosted, linux, nof-infra]`;
- `hbl-production` environment gate is present;
- workflow concurrency is scoped per service as `nof-release-builder-hbl-${{ inputs.service }}`;
- deploy delegates to release-builder;
- runbook warns not to paste the registration token into chat, Wiki, tracker or git.

Production runner readiness is intentionally blocked until the separate nof-infra runner is registered:

```powershell
just check-runner-production
```

Expected before registration:

- command exits blocked and explains that the short-lived GitHub runner registration token is still required.

## hbl Runner Registration

Do not reconfigure the existing product-specific nof-ht runner.

Read-only discovery on 2026-06-14 found:

- existing service: `actions.runner.teanores-nof-ht.hbl-runner.service`;
- existing runner URL: `https://github.com/teanores/nof-ht`;
- existing labels include product-specific `nof-ht`.

The target runner must be registered separately for `teanores/nof-infra`.

Recommended hbl paths:

```text
/home/nofadminhbl/actions-runner-nof-infra
```

Recommended systemd service name after `svc.sh install`:

```text
actions.runner.teanores-nof-infra.hbl-runner.service
```

Registration requires a short-lived GitHub runner registration token from the `teanores/nof-infra` repository settings. Do not paste that token into chat, Wiki, tracker or git.

Preferred setup helper:

```bash
ssh nofadminhbl@192.168.1.51
cd /tmp
git clone https://github.com/teanores/nof-infra.git nof-infra-runner-setup
cd nof-infra-runner-setup

# Copy RUNNER_PACKAGE_URL and RUNNER_PACKAGE_SHA256 from GitHub's official
# "New self-hosted runner" Linux x64 instructions for teanores/nof-infra.
RUNNER_PACKAGE_URL='<official-package-url>' \
RUNNER_PACKAGE_SHA256='<official-sha256>' \
  bash scripts/hbl-install-nof-infra-github-runner.sh
```

The helper reads the registration token from a hidden prompt. Do not provide the token as a command-line argument.

Manual setup outline:

```bash
ssh nofadminhbl@192.168.1.51
mkdir -p ~/actions-runner-nof-infra
cd ~/actions-runner-nof-infra

# Download the current GitHub Actions runner package from GitHub's official instructions.
# Then configure with the token shown by GitHub. Do not log the token.
./config.sh \
  --url https://github.com/teanores/nof-infra \
  --token <registration-token-from-github-ui> \
  --name hbl-nof-infra-runner \
  --labels nof-infra,linux \
  --work /tmp/actions-runner-nof-infra-work

sudo ./svc.sh install nofadminhbl
sudo ./svc.sh start
sudo systemctl status actions.runner.teanores-nof-infra.hbl-nof-infra-runner.service --no-pager
```

Exact service name may differ based on the runner name generated by `config.sh`; verify with:

```bash
systemctl list-units --type=service --all --no-pager | grep -i actions.runner
```

## Production Run

Before running with `execute_deploy=true`, the owner-facing chat briefing must include:

- service and semver tag;
- deploy mode: `github-runner release-builder`;
- checks already run;
- approval/evidence id;
- expected UAT;
- rollback and stop conditions.

Expected production behavior:

- GitHub environment approval gates the deploy job;
- hbl runner executes release-builder for exactly one service/tag;
- release-builder writes evidence under hbl release-builder evidence directory;
- agent reads evidence and requests owner UAT.

## Stop Conditions

Stop if:

- runner is not infra-owned;
- runner labels do not include `nof-infra`;
- GitHub environment approval is missing;
- `nof-ht` is selected without explicit migration gate approval;
- workflow can deploy on ordinary push;
- workflow accepts branch refs or raw commits;
- job reimplements deployment instead of calling release-builder;
- logs expose secrets;
- evidence/rollback data is missing after deploy.
