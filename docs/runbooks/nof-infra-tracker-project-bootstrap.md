# nof-infra Tracker Project Bootstrap

Status: done.
Verified: 2026-06-21.

Tracker project `nof-infra` exists and the project-scoped `nof-infra-mcp`
alias is available for delivery records. The original bootstrap blocker
`MANUAL-CFF5F43D` is closed. Historical note: project creation still requires
platform-admin scope, but routine nof-infra goals, epics, tasks, sprints and
Wiki records now go through `nof-infra-mcp`.

## Purpose

Create a dedicated Task Tracker project for infrastructure work so CI/CD, Helm, Kubernetes, release-builder and hbl/VPS work is not mis-scoped under `nof-tt`, `nof-mp` or `nof-ht`.

## Historical Blocker

Project-scoped MCP tokens cannot create tracker projects.

Observed error:

```text
create_project requires platform:admin scope
```

This is expected. Agents must not bypass it by storing infrastructure work under the wrong project or by using service-scoped tokens for platform administration.

This blocker no longer prevents nof-infra delivery work because the project and
scoped MCP alias already exist.

## Required Project

```text
key: nof-infra
name: NOF Infrastructure
description: Инфраструктура NOF: Helm, Kubernetes, release-builder, CI/CD, hbl/VPS desired state, deployment runbooks and operational evidence without service application code or secret values.
```

## Created Baseline Records

The initial delivery records were created under `nof-infra`:

1. Goal: `NOF-INFRA-GOAL-RELEASE-AND-OPS-OWNERSHIP`.
2. Epic: `NOF-INFRA-EPIC-CICD-STANDARDIZATION`.
   - Status: done as baseline release-governance work.
3. Epic: `NOF-INFRA-EPIC-VPS-HBL-GAME-TUNNEL`.
   - Status: used for WireGuard and Enshrouded game tunnel operations.
4. Closed CI/CD baseline tasks:
   - `MANUAL-INFRA-CICD-STANDARD`;
   - `MANUAL-INFRA-DESIRED-STATE`;
   - `MANUAL-INFRA-RUNNER-HEALTH`;
   - `MANUAL-INFRA-PREFLIGHT`;
   - `MANUAL-INFRA-NOF-INFRA-MCP-ALIAS`.

## Safety Rules

- Do not record secret values.
- Do not push desired-state changes or run hbl-changing commands without owner approval in the current conversation.
- Do not create new infrastructure tasks under `NOFTT-*` or service project keys after `nof-infra` exists.
- Keep `nof-ht` release-builder desired-state disabled until the owner accepts a single CI/CD standard or explicitly moves nof-ht from GitHub Actions to release-builder.

## Verification

For Codex agents launched from `C:\Users\User\Documents\dev\NOF`, verify:

Expected MCP aliases:

- `nof-tt-mcp` connected;
- `nof-mp-mcp` connected;
- `nof-ht-mcp` connected.
- `nof-infra-mcp` connected.

Expected tracker packet:

```text
projectKey: nof-infra
activeSprint: null unless an owner-approved nof-infra sprint is running
```

All tracker and Wiki mutations for nof-infra must use `nof-infra-mcp`.
