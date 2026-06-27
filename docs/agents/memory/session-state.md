# nof-infra Agent Session State

Updated: 2026-06-26.

## Current Status

- Active tracker goal: `NOF-INFRA-GOAL-RELEASE-AND-OPS-OWNERSHIP`.
- Active nof-infra sprint: none.
- Agent mode: standby after release deploy.
- Latest closed sprint: `NOF-INFRA-SPRINT-17` — nof-tt `v0.2.37` release deploy for Phase 3 isolation.
- `nof-infra` `main` is clean and aligned with `origin/main`.
- `NOF-INFRA-SPRINT-17` is closed as `done`.
- Latest approved production action: `NOF-INFRA-38` deploy of `nof-tt` `v0.2.37` through nof-infra release-builder.
- Latest completed work: nof-mp `v0.2.90` production release for `NOF-INFRA-39`.
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
- `NOF-INFRA-SPRINT-16` closed:
  - `NOF-INFRA-37` formalized nof-ht forgath.ru OIDC Helm refs;
  - `NOF-INFRA-36` restored nof-mp GitHub release dispatch bridge;
  - no additional production/hbl/VPS deploy was run.
- `NOF-INFRA-38` production deploy completed:
  - accepted nof-tt release `v0.2.37` from nof-tt-agent;
  - release commit/tag target `3f394b0 chore: release nof-tt v0.2.37`;
  - created and closed `NOF-INFRA-SPRINT-17` as the approved P0 unblocker sprint;
  - deployed via nof-infra GitHub Actions release-builder workflow;
  - recorded evidence in tracker task `NOF-INFRA-38`;
  - no direct SSH, kubectl or Helm command was run from the local agent session.
- `NOF-INFRA-SPRINT-18` started:
  - active task `NOF-INFRA-39`;
  - purpose: gated nof-mp prod release for `NOF-MP-43` launch-button fix plus canonical identity schema;
  - release is stopped at freshness gate because `origin/main` contains identity merge `e36a14d` but not the launch fix `b3317c2`;
  - latest visible tag `v0.2.89` points to `6bd2c03` and is not suitable for this release;
  - runbook prepared at `docs/runbooks/nof-mp-phase3-launch-identity-release.md`;
  - no production deploy, desired-state flip, SSH, kubectl or Helm command was run.
- `NOF-INFRA-SPRINT-18` closed:
  - owner approved production deploy in-chat on 2026-06-27;
  - deployed nof-mp `v0.2.90` through GitHub runner release-builder;
  - closed task `NOF-INFRA-39` as done with release-builder and public smoke evidence;
  - no prod identity DATA migration was run.

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
- nof-ht OIDC Helm refs:
  - commit `cd75ea2 chore(NOF-INFRA-37): formalize nof-ht oidc refs` pushed to nof-infra `main`;
  - `NOFMP_CLIENT_ID`, `NOFMP_ISSUER`, `NOF_PLATFORM_AUTHORIZE_URL`, `NOF_PLATFORM_TOKEN_URL`, `NOF_PLATFORM_CLIENT_ID`, `NOF_PLATFORM_ISSUER`, `NOF_PLATFORM_AUDIENCE` are declared via ConfigMap metadata;
  - `NOFMP_CLIENT_SECRET`, `NOF_PLATFORM_JWT_SECRET` and legacy `NOF_PLATFORM_CLIENT_SECRET` remain Kubernetes Secret keys only, with no values in git/tracker/chat;
  - `just test` and `git diff --check` passed.
- nof-mp release dispatch bridge:
  - GitHub repo secret metadata `NOF_INFRA_RELEASE_DISPATCH_TOKEN` exists in `teanores/nof-mp`, updated `2026-06-26T14:37:45Z`;
  - validation-only workflow run `https://github.com/teanores/nof-mp/actions/runs/28245045149` succeeded;
  - validation used `ref=v0.2.88`, `execute_deploy=false`;
  - log confirmed no nof-infra dispatch was sent.
- nof-tt `NOF-INFRA-38` / Phase 3 isolation release evidence:
  - GitHub Actions run `28256939509` succeeded;
  - service/ref `nof-tt` / `v0.2.37`;
  - release commit `3f394b0`;
  - image `localhost:32000/nof-tt:3f394b0`;
  - image digest `sha256:6f62f896c96e68f0e43f79f0af98f1493b7bc8306d4e0e82bcd76c9547f5585e`;
  - Helm release `nof-tt`, namespace `nof-apps`, revision `40`, status `deployed`;
  - rollout completed: `deployment "nof-tt" successfully rolled out`;
  - evidence file `/home/nofadminhbl/nof-release-builder/evidence/nof-tt-3f394b0-20260626T181901Z.txt`.
- nof-tt `NOF-INFRA-38` post-deploy smoke:
  - `GET https://task-tracker.forgath.ru/api/mcp` with `Accept: text/event-stream` returned `405 Method Not Allowed` and `Allow: POST`;
  - unauthenticated `GET https://task-tracker.forgath.ru/api/projects/nof-tt/wiki` returned `401` and did not return wiki data;
  - `HEAD https://task-tracker.forgath.ru/` returned `307` to `/projects`;
  - `nof-infra-mcp.get_mcp_health` reported healthy tracker operations after deploy.
- nof-mp `NOF-INFRA-39` / `v0.2.90` release evidence:
  - GitHub Actions run `28293504824` succeeded;
  - service/ref `nof-mp` / `v0.2.90`;
  - release commit `f7cc53f`;
  - image `localhost:32000/nof-mp:f7cc53f`;
  - image digest `sha256:a4bac7ffa54d2b5eb4425712c02bb6dc8ccc52ef6a5cb027923f03817c966730`;
  - Helm release `nof-mp`, namespace `nof-apps`, revision `120`, status `deployed`;
  - rollout completed: `deployment "nof-mp" successfully rolled out`;
  - evidence file `/home/nofadminhbl/nof-release-builder/evidence/nof-mp-f7cc53f-20260627T153030Z.txt`;
  - release-builder logged `Migration gate: not required for nof-mp`, so no prod identity DATA migration was run.
- nof-mp `NOF-INFRA-39` pre-deploy checks:
  - `npm run test -- --run`: 96 files / 387 tests passed;
  - `npm run typecheck`: passed;
  - `npm run lint`: passed;
  - `npm run build`: passed;
  - `git diff --check`: passed.
- nof-mp `NOF-INFRA-39` post-deploy smoke:
  - `https://forgath.ru/login` returned `200 OK`;
  - `https://forgath.ru/.well-known/openid-configuration` returned `200 OK` with issuer `https://forgath.ru`;
  - `https://forgath.ru/products/task-tracker/launch` returned `303` to `/login?next=%2Fproducts%2Ftask-tracker%2Flaunch`, then login returned `200 OK`;
  - `https://forgath.ru/overview` returned `307` to `/login?next=%2Foverview`;
  - `https://forgath.ru/` returned `200 OK` from the public static landing page.

## Important Operational Notes

- Real registration email delivery was not triggered because sending email and creating a registration code is a side-effect/UAT action, not read-only smoke.
- Owner UAT can validate real registration email delivery with a chosen test recipient.
- Direct hbl SSH/kubectl remains unavailable from this local environment, but release-builder workflow evidence provided live image, Helm revision, rollout status and evidence path.
- Do not run hbl/VPS/production-changing commands without explicit owner approval in the current conversation.
- Do not print or store game passwords, private keys, tokens, database URLs or Kubernetes secret values.
- SPRINT-14 deploy-unification remains paused.
- OpenBao Secrets ADR remains parked; `NOF-INFRA-34` tracks the future pilot.
- `NOF-TT-200` rollback target, if separately approved later: nof-tt `v0.2.35`.
- Applying nof-ht Helm refs to live hbl/nof-ht still requires separate owner approval.
- Next real nof-mp GitHub Release should validate the restored automatic dispatch bridge under normal release gates.
- Standby rule for next session: do not start new nof-infra work until the owner or discovery-agent provides a ready sprint/task. The expected next production-bound work is nof-mp release after `NOF-MP-43 + identity` merge to `main` and explicit owner approval in the current chat.
- Rollback target for `NOF-INFRA-38`, if separately approved later: nof-tt `v0.2.36`.
- `NOF-INFRA-39` release preflight blocker:
  - nof-mp `origin/main` is `e36a14d` and contains canonical identity schema;
  - nof-mp `origin/main` does not contain `NOF-MP-43`;
  - `origin/bugfix/NOF-MP-43/launch-button-same-origin` is `b3317c2`;
  - `v0.2.89` is `6bd2c03`, older than the target scope;
  - local nof-mp worktree currently has uncommitted changes in another agent's identity files; nof-infra must not overwrite them;
  - continue only after nof-mp provides a semver release tag containing both identity and launch-fix scopes.
- `NOF-INFRA-39` remains production-gated: no deploy without a final owner in-chat GO after release ref/checklist are presented.
- `NOF-INFRA-39` is done. Remaining UAT caveat:
  - public unauthenticated pages did not expose a visible `v0.2.90` footer/version marker;
  - owner/authenticated UAT should verify the portal footer/version marker, or nof-mp should add a future public version endpoint if that evidence must be machine-checkable.

## Backlog Candidates

No active sprint exists. Before taking backlog work, run a short planning step or wait for discovery-agent priorities.

Known candidates still visible in tracker:

- `NOF-INFRA-34` — OpenBao + ESO secrets management pilot, PARKED, readiness 70.
- `NOF-INFRA-22` — revalidate nof-tt `BOT_API_KEY` Helm mount, readiness 60.
- `NOF-INFRA-9` — watch nof-service decomposition support, readiness 60.
- `NOF-INFRA-25` — post-beta bot gateway Helm/release-builder scaffolding, readiness 40.
