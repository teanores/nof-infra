# Legacy Auth Secret Rotation

Status: plan, production changes require owner approval.
Tracker task: `NOF-INFRA-20`.
Source request: `NOF-MP-12`.

## Purpose

Rotate legacy platform auth secret material used by nof-mp and legacy nof-service while preserving session validation and bridge compatibility.

This runbook assumes nof-mp supports dual current/previous key verification for:

- `NOF_AUTH_SECRET_KEY`;
- `SECRET_KEY`;
- `NOF_AUTH_SECRET_KEY_PREVIOUS`;
- `SECRET_KEY_PREVIOUS`.

Do not execute live rotation until the owner approves the exact current-chat window.

## Current State

Local nof-infra chart evidence:

- `helm/nof-mp/values.yaml` maps `SECRET_KEY` and `NOF_AUTH_SECRET_KEY` to `dragon-forge-secrets` key `SECRET_KEY`;
- `helm/nof-mp/values.yaml` maps optional `SECRET_KEY_PREVIOUS` to `dragon-forge-secrets` key `SECRET_KEY_PREVIOUS`;
- `helm/nof-tt/values.yaml` maps `SECRET_KEY` to `dragon-forge-secrets` key `SECRET_KEY`;
- legacy nof-service compatibility remains required until decomposition/bridge cleanup is approved.

## Secret Boundaries

Never print or store:

- raw auth secret values;
- session signing/encryption material;
- cookies or authorization headers.

Allowed metadata:

- secret name;
- key name;
- encoded value length;
- pod env presence as `SET` or `MISSING`.

## Standard Delivery Path

Use GitHub runner release-builder as the standard deploy/restart path for nof-mp.

Manual SSH/local release-builder remains emergency-only under NOF-INFRA-16 guardrails:

```bash
NOF_RELEASE_MANUAL_OVERRIDE=1
NOF_RELEASE_APPROVAL_ID='<current-chat-owner-approval-or-tracker-evidence-id>'
```

Do not use manual flow as routine product-agent delivery.

## Rotation Phases

Do not run without explicit owner approval in the current conversation.

1. Metadata-only preflight.

   ```powershell
   just check-legacy-auth-secret-dry-run
   ```

   Live metadata preflight, if approved:

   ```powershell
   just check-legacy-auth-secret
   ```

2. Prepare new secret material out of band.

   Requirements:

   - do not paste values into chat, tracker, Wiki, shell history or git;
   - preserve previous current key as previous-key material;
   - keep `dragon-forge-secrets` until nof-service bridge cleanup is approved.

3. Apply previous/current relationship.

   Target Kubernetes Secret: `dragon-forge-secrets`.

   Required metadata after apply:

   - `SECRET_KEY` exists and has non-zero encoded length;
   - `SECRET_KEY_PREVIOUS` exists and has non-zero encoded length during transition.

4. Deploy/restart nof-mp through approved release-builder path.

5. Validate sessions and UAT.

6. Keep transition window long enough for active sessions to move or expire.

7. Schedule cleanup under `NOF-MP-16` only after owner accepts transition completion and legacy nof-service constraints are resolved.

## Metadata-Only Verification

Safe local dry run:

```powershell
just check-legacy-auth-secret-dry-run
```

This prints hbl read-only commands but does not run SSH.

Live metadata-only check, only after owner approval:

```powershell
just check-legacy-auth-secret
```

Expected output shape:

- `SECRET_KEY length=<number>`;
- `SECRET_KEY_PREVIOUS length=<number>` during transition;
- nof-mp env presence as `SECRET_KEY=SET`, `NOF_AUTH_SECRET_KEY=SET`, `SECRET_KEY_PREVIOUS=SET/MISSING`;
- nof-tt env presence as `SECRET_KEY=SET`.

No raw secret value should appear.

Post-rotation:

```powershell
just check-legacy-auth-secret-live
```

Expected:

- current and previous key metadata is present for the transition window;
- nof-mp reports current and previous env presence as expected;
- nof-tt remains compatible with existing `SECRET_KEY`;
- no raw value appears in output.

## Owner UAT

After approved rotation and nof-mp deploy/restart:

1. Existing session: open `https://forgath.ru/overview`.
2. New session: sign out and sign in at `https://forgath.ru/login`.
3. Open `https://task-tracker.forgath.ru` from the platform.
4. Exercise one legacy nof-service-backed path still routed through `NOF_SERVICE_INTERNAL_URL` if applicable.

Expected:

- existing session remains valid during transition or fails only according to the approved session-impact notice;
- new login succeeds;
- nof-tt access still works;
- legacy bridge path still works;
- no secret/cookie/header value is visible in UI or logs.

## Rollback

If sessions or legacy bridge fail:

1. Stop further cleanup.
2. Restore the prior approved `SECRET_KEY` / `SECRET_KEY_PREVIOUS` relationship out of band without printing values.
3. Roll back affected Helm release through approved release-builder path.
4. Re-run metadata-only verification.
5. Re-run owner UAT.
6. Record failed rotation and rollback evidence without secret values.

## Cleanup Criteria For NOF-MP-16

Create or continue cleanup only after:

- the owner accepts the rotation UAT;
- nof-mp has run long enough for the transition window;
- legacy nof-service bridge constraints are resolved or explicitly accepted;
- metadata-only checks prove no unexpected consumer still depends on the previous key.

Cleanup must remove previous-key dependency only after a separate approval.

## Stop Conditions

Stop if:

- any command would print raw secret, cookie or authorization data;
- owner approval is missing for live secret/Kubernetes/hbl operations;
- nof-mp dual-key behavior is not confirmed for the target release;
- nof-tt or legacy nof-service would be broken by the secret relationship;
- the GitHub runner release path is unavailable and emergency/manual mode was not explicitly approved;
- UAT fails for login, task-tracker access or legacy bridge path.

## Evidence To Record

- owner approval reference;
- services affected;
- secret name and key names only;
- release-builder evidence id;
- metadata-only verification output;
- UAT result for existing session, new login, nof-tt and legacy bridge;
- rollback command or stop condition;
- cleanup decision for `NOF-MP-16`.
