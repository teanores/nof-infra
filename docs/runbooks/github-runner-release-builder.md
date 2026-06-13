# GitHub Runner Release-Builder Runbook

Status: draft implementation runbook.
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

## Workflow Inputs

| Input | Meaning |
| --- | --- |
| `service` | `nof-mp`, `nof-tt`, or `nof-ht` |
| `ref` | semver tag, for example `v0.2.35` |
| `approval_id` | owner approval / tracker evidence id |
| `execute_deploy` | `false` validates only; `true` runs production deploy after GitHub environment approval |

## Dry Run

Use `execute_deploy=false` to validate the request without touching hbl production:

```text
service=nof-mp
ref=v0.2.35
approval_id=IDEA-...
execute_deploy=false
```

Expected:

- validate job passes;
- deploy job is skipped;
- no hbl command runs.

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
- workflow can deploy on ordinary push;
- workflow accepts branch refs or raw commits;
- job reimplements deployment instead of calling release-builder;
- logs expose secrets;
- evidence/rollback data is missing after deploy.
