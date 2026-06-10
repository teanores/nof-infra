# nof-infra Tracker Project Bootstrap

Status: blocked on `platform:admin` MCP scope.
Tracker blocker: `MANUAL-CFF5F43D`.
Related idea: `IDEA-20260609-585967`.

## Purpose

Create a dedicated Task Tracker project for infrastructure work so CI/CD, Helm, Kubernetes, release-builder and hbl/VPS work is not mis-scoped under `nof-tt`, `nof-mp` or `nof-ht`.

## Current Blocker

Project-scoped MCP tokens cannot create tracker projects.

Observed error:

```text
create_project requires platform:admin scope
```

This is expected. Agents must not bypass it by storing infrastructure work under the wrong project or by using service-scoped tokens for platform administration.

## Required Project

```text
key: nof-infra
name: NOF Infrastructure
description: Инфраструктура NOF: Helm, Kubernetes, release-builder, CI/CD, hbl/VPS desired state, deployment runbooks and operational evidence without service application code or secret values.
```

## After Project Creation

Create these delivery records under `nof-infra`:

1. Epic: `NOF-INFRA-EPIC-CICD-STANDARDIZATION`
   - Outcome: one accepted CI/CD standard for `nof-mp`, `nof-tt` and `nof-ht` before July 2026 beta.
2. Sprint: `NOF-INFRA Ops Sprint: CI/CD standard decision and desired-state alignment`
   - Scope: decide GitHub Actions vs release-builder vs explicit hybrid, document runner health, release evidence, rollback and owner approval gates.
3. Tasks:
   - `NOF-INFRA-P1-DECIDE-CICD-STANDARD`
   - `NOF-INFRA-P1-ALIGN-HBL-DESIRED-STATE`
   - `NOF-INFRA-P1-DOCUMENT-RUNNER-HEALTH-AND-BACKOFF`
   - `NOF-INFRA-P1-VERIFY-RELEASE-BUILDER-PREFLIGHT`

## Safety Rules

- Do not record secret values.
- Do not push desired-state changes or run hbl-changing commands without owner approval in the current conversation.
- Do not create new infrastructure tasks under `NOFTT-*` or service project keys after `nof-infra` exists.
- Keep `nof-ht` release-builder desired-state disabled until the owner accepts a single CI/CD standard or explicitly moves nof-ht from GitHub Actions to release-builder.

## Verification

After project creation:

```powershell
claude mcp list
```

Expected for Claude Code agents launched from `C:\Users\User\Documents\dev\NOF`:

- `nof-tt-mcp` connected;
- `nof-mp-mcp` connected;
- `nof-ht-mcp` connected.

Infrastructure project records may still be created through a platform-admin tracker session until a dedicated `nof-infra-mcp` alias exists.
