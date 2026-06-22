# Platform OAuth Secret Rotation

Status: plan, production changes require owner approval.
Tracker task: `NOF-INFRA-19`.
Source request: `NOF-MP-15`.

## Purpose

Coordinate platform OAuth secret rotation across:

- `nof-mp` issuer / verifier material;
- `nof-tt` OAuth client material;
- `nof-ht` OAuth client material.

The goal is to rotate without printing raw secrets or hashes and without breaking login/callback flows.

## Current State

Local nof-infra evidence:

- `helm/nof-mp/values.yaml` mounts `NOF_PLATFORM_OAUTH_JWT_SECRET`, `NOF_PLATFORM_OAUTH_CLIENT_SECRET_SHA256_NOF_TT` and `NOF_PLATFORM_OAUTH_CLIENT_SECRET_SHA256_NOF_HT` from `nof-mp-oauth-secrets`;
- `helm/nof-tt/values.yaml` mounts `NOF_PLATFORM_OAUTH_JWT_SECRET` and `NOF_TT_OAUTH_CLIENT_SECRET` from `nof-tt-oauth-secrets`;
- `helm/nof-ht/templates/deployment.yaml` imports `nof-ht-oauth-secrets` through `envFrom`;
- `docs/runbooks/hbl-release-builder-migration.md` records the expected OAuth secret resource names.

## Secret Boundaries

Never print or store:

- raw OAuth client secrets;
- raw JWT secrets;
- SHA-256 hashes of client secrets;
- cookies, auth headers or callback query secrets.

Allowed metadata:

- secret name;
- key name;
- encoded value length;
- pod env presence as `SET` or `MISSING`;
- public OAuth URLs and non-secret client ids if already public.

## Standard Delivery Path

Use GitHub runner release-builder as the standard apply/deploy path.

Manual SSH/local release-builder remains emergency-only under NOF-INFRA-16 guardrails:

```bash
NOF_RELEASE_MANUAL_OVERRIDE=1
NOF_RELEASE_APPROVAL_ID='<current-chat-owner-approval-or-tracker-evidence-id>'
```

Do not use manual flow as routine product-agent delivery.

## Rotation Strategy

Use a coordinated maintenance window unless nof-mp/product code has confirmed dual-verify support for the specific OAuth material being rotated.

Default order:

1. Prepare new raw client secrets and derived hashes out of band.
2. Confirm owner approval for the exact rotation window in the current chat.
3. Apply nof-mp verifier/hash secret metadata first.
4. Deploy/restart nof-mp through approved release-builder path.
5. Apply product client secrets for nof-tt and nof-ht.
6. Deploy/restart nof-tt and nof-ht through approved release-builder path.
7. Run metadata-only checks.
8. Run owner UAT for platform login and product callbacks.

If dual-verify support is confirmed before live work, record the exact dual-verify behavior and adjust order. Without that evidence, assume a short maintenance window is required because issuer and clients must agree on secret material.

## Metadata-Only Verification

Safe local dry run:

```powershell
just check-platform-oauth-secrets-dry-run
```

This prints hbl read-only commands but does not run SSH.

Live metadata-only check, only after owner approval:

```powershell
just check-platform-oauth-secrets
```

Expected output shape:

- `nof-mp-oauth-secrets` key names and encoded lengths;
- `nof-tt-oauth-secrets` key names and encoded lengths;
- `nof-ht-oauth-secrets` key names and encoded lengths;
- pod env presence as `SET`/`MISSING`.

No raw value or hash should appear.

Post-rotation:

```powershell
just check-platform-oauth-secrets-live
```

Expected:

- nof-mp pod has OAuth verifier/hash envs present;
- nof-tt pod has OAuth JWT/client envs present;
- nof-ht pod has required OAuth envs present through `nof-ht-oauth-secrets`;
- no secret/hash value appears in output.

## Owner UAT

After approved rotation and deploys:

1. Open `https://forgath.ru/login`.
2. Sign in normally.
3. Open `https://task-tracker.forgath.ru` and complete platform OAuth flow.
4. Open `https://habit-tracker.forgath.ru` and complete platform OAuth flow.

Expected:

- platform login succeeds;
- nof-tt OAuth callback succeeds;
- nof-ht OAuth callback succeeds;
- no loop back to login;
- no OAuth secret/hash/cookie/header is visible in UI or logs.

## Rollback

If OAuth login or callbacks fail:

1. Stop further rotations.
2. Restore the previous approved secret material out of band without printing values.
3. Roll back affected service Helm releases through approved release-builder path.
4. Re-run metadata-only verification.
5. Re-run owner UAT.
6. Record failed rotation and rollback evidence without secret values.

## Stop Conditions

Stop if:

- any command would print raw secret or hash values;
- owner approval is missing for live secret/Kubernetes/hbl operations;
- nof-mp and product services would use mismatched OAuth material;
- platform login fails;
- nof-tt or nof-ht OAuth callback fails;
- the GitHub runner release path is unavailable and emergency/manual mode was not explicitly approved.

## Evidence To Record

- owner approval reference;
- services included in the window;
- secret names and key names only;
- deploy path and release-builder evidence ids;
- metadata-only verification output;
- UAT result for platform, nof-tt and nof-ht;
- rollback command or stop condition.
