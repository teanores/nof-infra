# forgath.ru Mail Domain Readiness

Status: readiness plan, production DNS/provider changes require owner approval.
Tracker task: `NOF-INFRA-21`.
Source request: `NOF-MP-24`.

## Purpose

Prepare infrastructure readiness for nof-mp registration code and password reset email delivery from an approved `@forgath.ru` sender.

Application contract belongs to nof-mp. DNS, provider readiness, runtime secret wiring and production rollout gates belong to nof-infra.

## Current Public DNS Evidence

Read-only DNS checks on 2026-06-22:

```powershell
Resolve-DnsName -Name forgath.ru -Type MX
Resolve-DnsName -Name forgath.ru -Type TXT
Resolve-DnsName -Name _dmarc.forgath.ru -Type TXT
Resolve-DnsName -Name mail.forgath.ru -Type A
```

Observed:

- MX: `forgath.ru` points to `mail.forgath.ru` with priorities `10` and `20`;
- A: `mail.forgath.ru` points to `176.12.67.92`;
- SPF: no apex TXT answer was returned for `forgath.ru`;
- DMARC: no TXT answer was returned for `_dmarc.forgath.ru`;
- authoritative DNS in the negative TXT responses points to `ns1.firstvds.ru`.

Interpretation:

- inbound mail DNS exists in basic form;
- outbound application mail is not production-ready yet for routine delivery because SPF and DMARC are not published;
- DKIM/provider signing is not proven from public DNS in this readiness pass.

## Current Runtime Wiring

Local nof-infra chart evidence:

- `helm/nof-mp/values.yaml` expects `nof-mp-email-secrets`;
- required keys:
  - `NOF_MP_EMAIL_WEBHOOK_TOKEN`;
  - `NOF_MP_EMAIL_FROM`;
  - `SMTP_HOST`;
  - `SMTP_PORT`;
  - `SMTP_USER`;
  - `SMTP_PASS`.

Do not print or store SMTP credentials.

## Phase 1 Recommendation

Use a provider-backed SMTP sender for nof-mp Phase 1 instead of treating the VPS host as a production outbound mail server.

Recommended sender shape:

```text
no-reply@forgath.ru
```

Required before production enablement:

1. Select the SMTP provider/account out of band.
2. Publish provider-required SPF.
3. Publish provider-required DKIM records.
4. Publish DMARC for `_dmarc.forgath.ru`.
5. Create or update `nof-mp-email-secrets` out of band.
6. Deploy/restart nof-mp through the approved release-builder path.
7. Run metadata-only verification and owner UAT.

Minimum DMARC posture for Phase 1 may start as monitoring/quarantine depending on provider guidance, but it must be explicit and owner-approved.

## Metadata-Only Verification

Safe public DNS check:

```powershell
just check-mail-dns
```

Expected output:

- MX hostnames/priorities;
- SPF TXT presence/missing status;
- DMARC TXT presence/missing status;
- `mail.forgath.ru` A record.

Live hbl/Kubernetes secret checks are not part of this read-only DNS readiness task. Any check of `nof-mp-email-secrets` requires separate current-chat owner approval and must print only key names/encoded lengths or SET/MISSING env presence.

## Production Rollout Gate

Before enabling nof-mp app mail:

- owner approves exact sender address;
- owner approves SMTP provider/account;
- DNS SPF/DKIM/DMARC are published and verified;
- `nof-mp-email-secrets` exists with required keys, without printing values;
- nof-mp release/deploy path is approved;
- UAT recipient addresses are agreed without recording real addresses in tracker/Wiki.

## Owner UAT

After approved rollout:

1. Trigger registration email using a test recipient agreed out of band.
2. Trigger password reset email using a test recipient agreed out of band.
3. Confirm messages arrive and links work.
4. Check spam/promotions classification manually.

Expected:

- sender is the approved `@forgath.ru` address;
- registration code email arrives;
- password reset email arrives;
- no SMTP password, token or real recipient address is recorded in logs/tracker/Wiki/chat.

## Rollback

If delivery fails or messages are rejected:

1. Disable app email feature path or restore previous runtime setting through approved release-builder path.
2. Keep DNS records intact unless the owner approves DNS rollback.
3. Preserve provider diagnostics without credentials or recipient addresses.
4. Record aggregate failure status and next DNS/provider action.

## Stop Conditions

Stop if:

- any command would print SMTP credentials, tokens or real recipient addresses;
- SPF/DKIM/DMARC requirements are unclear;
- provider account ownership is not confirmed;
- nof-mp deploy would proceed without current-chat owner approval;
- production mail would be enabled before DNS readiness is verified.
