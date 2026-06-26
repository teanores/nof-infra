# nof-infra Agent Session State

Updated: 2026-06-26.

## Current Status

- Active tracker goal: `NOF-INFRA-GOAL-RELEASE-AND-OPS-OWNERSHIP`.
- Active nof-infra sprint: none.
- Latest closed sprint: `NOF-INFRA-SPRINT-15` — Phase 1 live auth evidence and Phase 2 OIDC infra readiness.
- `nof-infra` `main` is clean and aligned with `origin/main`.
- `NOF-INFRA-SPRINT-15` is closed as `done`.
- Latest approved production action: `NOF-TT-200` deploy of `nof-tt` `v0.2.36` through nof-infra release-builder.
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
- `NOF-INFRA-31` closed:
  - recorded nof-mp release-builder production evidence for `v0.2.87`;
  - verified public auth/OIDC/mail-boundary endpoints with read-only and negative-smoke checks;
  - closed `NOF-INFRA-SPRINT-15` as `done`.
- `NOF-INFRA-34` created as PARKED backlog:
  - `Secrets management pilot: OpenBao + ESO (one local token, one prod secret)  PARKED`;
  - linked in description to `NOF-INFRA-DECISION-1`;
  - not added to a sprint, readiness 70, blocked by owner accept and keystone/OpenBao deployment choices.
- `NOF-TT-200` production deploy completed:
  - accepted nof-tt release `v0.2.36`;
  - release commit/tag `6047ec8 chore: release nof-tt v0.2.36`;
  - deployed via nof-infra GitHub Actions release-builder workflow.

## Verification Evidence

- `just test` passed in `nof-infra`.
- `git diff --check` passed in `nof-infra` and `nof-ht`.
- nof-mp release-builder evidence:
  - GitHub Actions run `28235103984` succeeded;
  - service/ref `nof-mp` / `v0.2.87`;
  - image `localhost:32000/nof-mp:ba4525e`;
  - Helm release `nof-mp`, namespace `nof-apps`, revision `117`, status `deployed`;
  - rollout completed: `deployment "nof-mp" successfully rolled out`;
  - evidence file `/home/nofadminhbl/nof-release-builder/evidence/nof-mp-ba4525e-20260626T112835Z.txt`.
- Public nof-mp smoke passed:
  - `https://forgath.ru/` returned `200 OK`;
  - `https://forgath.ru/login` returned `200 OK` and rendered the login form;
  - `https://forgath.ru/register` returned `200 OK`;
  - `https://forgath.ru/.well-known/openid-configuration` returned `200 OK` with issuer `https://forgath.ru` and OAuth endpoints;
  - `https://forgath.ru/oauth/authorize` without params returned controlled `400 invalid_client`;
  - `https://forgath.ru/oauth/token` with invalid client data returned controlled `401 invalid_client`;
  - `https://forgath.ru/password-reset` returned `200 OK`;
  - `https://forgath.ru/api/internal/email/password-reset` without bearer token returned controlled `401 unauthorized`;
  - `https://forgath.ru/api/public/registration/request` with invalid email returned controlled redirect to `/register?error=invalid_email`.
- nof-tt `NOF-TT-200` release evidence:
  - GitHub Actions run `28236712967` succeeded;
  - service/ref `nof-tt` / `v0.2.36`;
  - image `localhost:32000/nof-tt:6047ec8`;
  - image digest `sha256:24ac2511be1a792f381bad1c4a44f7ecf8c0e92aa7df30c0b68a1dbb1bacd6a5`;
  - Helm release `nof-tt`, namespace `nof-apps`, revision `39`, status `deployed`;
  - rollout completed: `deployment "nof-tt" successfully rolled out`;
  - evidence file `/home/nofadminhbl/nof-release-builder/evidence/nof-tt-6047ec8-20260626T120433Z.txt`.
- nof-tt `NOF-TT-200` post-deploy smoke:
  - `https://task-tracker.forgath.ru/` returned `307` to `/projects`;
  - `GET /api/mcp` with `Accept: text/event-stream` returned `405 Method Not Allowed` and `Allow: POST`;
  - `GET /api/mcp/sse` returned `410 Gone`;
  - `POST /api/mcp/message` returned `410 Gone`;
  - after an idle interval elapsed during post-deploy checks, `nof-tt-mcp.get_mcp_health` succeeded with no `session expired`.

## Important Operational Notes

- Real registration email delivery was not triggered because sending email and creating a registration code is a side-effect/UAT action, not read-only smoke.
- Owner UAT can validate real registration email delivery with a chosen test recipient.
- Direct hbl SSH/kubectl remains unavailable from this local environment, but release-builder workflow evidence provided live image, Helm revision, rollout status and evidence path.
- Do not run hbl/VPS/production-changing commands without explicit owner approval in the current conversation.
- Do not print or store game passwords, private keys, tokens, database URLs or Kubernetes secret values.
- SPRINT-14 deploy-unification remains paused.
- OpenBao Secrets ADR remains parked; `NOF-INFRA-34` tracks the future pilot.
- `NOF-TT-200` rollback target, if separately approved later: nof-tt `v0.2.35`.

## Backlog Candidates

No active sprint exists. Before taking backlog work, run a short planning step or wait for discovery-agent priorities.

Known candidates still visible in tracker:

- `NOF-INFRA-22` — revalidate nof-tt `BOT_API_KEY` Helm mount, readiness 60.
- `NOF-INFRA-34` — OpenBao + ESO secrets management pilot, PARKED, readiness 70.
- `NOF-INFRA-9` — watch nof-service decomposition support, readiness 60.
- `NOF-INFRA-25` — post-beta bot gateway Helm/release-builder scaffolding, readiness 40.
