# nof-infra Agent Session State

Updated: 2026-06-26.

## Current Status

- Active tracker goal: `NOF-INFRA-GOAL-RELEASE-AND-OPS-OWNERSHIP`.
- Active nof-infra sprint: `NOF-INFRA-SPRINT-15` — Phase 1 live auth evidence and Phase 2 OIDC infra readiness.
- Latest closed sprint: `NOF-INFRA-SPRINT-14` — GitHub-driven release automation standard.
- `nof-infra` `main` is clean and aligned with `origin/main`.
- `NOF-INFRA-SPRINT-15` has one remaining open task: `NOF-INFRA-31`.
- No hbl/VPS/production-changing command was run in the latest session.
- No secret values were read, printed or changed.

## Completed Work In Latest Session

- Step 0 MCP self-check completed:
  - `nof-infra-mcp` is available;
  - `get_mcp_health` reports tracker operations closed and healthy;
  - `get_delivery_model` and `get_project_standards` were reread;
  - `NOF-INFRA-SPRINT-15` was created through MCP.
- `NOF-INFRA-30` closed:
  - old branch `chore/nof-infra-30/preserve-migration-utils` was stale relative to current `main` and would have reverted later release-builder work, so it was not merged directly;
  - preserved only reusable migration utilities on a fresh branch;
  - merged and pushed nof-infra `4a9e381 chore(NOF-INFRA-30): preserve migration utility scripts`.
- `NOF-INFRA-32` closed:
  - added nof-ht Helm metadata/env refs for Phase 2 OIDC: `NOFMP_CLIENT_ID`, `NOFMP_ISSUER`, expected secret key `NOFMP_CLIENT_SECRET`;
  - did not add `NOF_MP_OAUTH_CLIENT_SECRET` to nof-tt because current nof-tt runtime uses `NOF_TT_OAUTH_CLIENT_SECRET` and has no runtime consumer for that alias;
  - merged and pushed nof-infra `959a30a chore(NOF-INFRA-32): wire nof-ht oidc env refs`.
- `NOF-INFRA-33` closed:
  - recorded that nof-mp gateway switch for `NOF-TT-008DC104` is already captured in nof-infra declarative state;
  - documented target upstream `server nof-mp:3000;` in `environments/hbl/edge/portal-gateway-configmap.target.yaml`;
  - merged and pushed nof-infra `792f127 docs(NOF-INFRA-33): record gateway switch evidence`.

## Verification Evidence

- `just test` passed in `nof-infra`.
- `git diff --check` passed in `nof-infra` and `nof-ht`.
- Public nof-mp smoke passed:
  - `https://forgath.ru/` returned `200 OK`;
  - `https://forgath.ru/login` returned `200 OK` and rendered the login form;
  - `https://forgath.ru/register` returned `200 OK`.
- Local nof-mp release evidence:
  - `origin/main` currently points at `c8d8592 chore: release nof-mp v0.2.86`;
  - recent release tags include `v0.2.86`, `v0.2.85`, `v0.2.84`.

## Open Sprint Blocker

- `NOF-INFRA-31` remains active because required hbl read-only production evidence is not available yet.
- Failed read-only checks:
  - `ssh nofadminhbl@192.168.1.51 ...` closed the connection;
  - configured `ssh 192.168.1.51 ...` also closed the connection;
  - `Test-NetConnection 192.168.1.51 -Port 22` timed out.
- Not confirmed yet:
  - live nof-mp image;
  - Helm revision;
  - release-builder evidence file path;
  - runtime env presence for mail delivery and auth provider.
- No real registration email was sent because that is a side-effect/UAT action and needs explicit owner approval plus test recipient.

## Important Operational Notes

- `NOF-INFRA-SPRINT-15` must not be closed until `NOF-INFRA-31` has the missing hbl/release-builder evidence.
- Next safe step: restore or confirm read-only hbl access for this agent, or provide release-builder/GitHub Actions evidence for the nof-mp deploy.
- After evidence is available, rerun metadata-only checks and close `NOF-INFRA-31`.
- Do not run hbl/VPS/production-changing commands without explicit owner approval in the current conversation.
- Do not print or store game passwords, private keys, tokens, database URLs or Kubernetes secret values.
- SPRINT-14 deploy-unification remains paused.
- OpenBao Secrets ADR remains parked.

## Backlog Candidates

Do not take backlog work until `NOF-INFRA-SPRINT-15` is resolved or explicitly replanned.
