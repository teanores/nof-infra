# CrowdSec VPS Observe-Only Setup

Status: draft, production VPS changes require owner approval.
Tracker task: `MANUAL-05EDAEC7`.

## Live Apply Evidence

Applied on 2026-06-09 with owner approval.

- SSH maintenance user: `nofadminvps`.
- SSH key used locally: `C:\Users\User\.ssh\nof-admin-vps`.
- Installed package: `crowdsec 1.7.8`.
- Service state: `enabled`, `active`.
- Installed collections: `crowdsecurity/caddy`, `crowdsecurity/linux`, `crowdsecurity/sshd`.
- Bouncers: none registered.
- Active decisions after install smoke: none.
- Active alerts after install smoke: none.
- Acquisition metrics confirm reads from:
  - `/var/log/caddy/forgath-access.log`;
  - `/var/log/auth.log`.
- Portal smoke: `https://forgath.ru/` returned HTTP 200 through Caddy.

No remediation component was installed.

## Purpose

Add standard open-source security monitoring on the public VPS without changing traffic handling in the first phase.

This is intentionally separate from the nof-mp security dashboard ingestion:

- CrowdSec detects and summarizes hostile behavior from Caddy and SSH logs.
- nof-mp admin security shows product/platform-facing audit data.
- Blocking is a later explicit decision after observe-only evidence and owner approval.

## Safety Model

Phase 1 is observe-only:

- install CrowdSec security engine;
- install `crowdsecurity/caddy` and `crowdsecurity/sshd` collections;
- read sanitized Caddy access logs and SSH auth logs;
- do not install `crowdsec-firewall-bouncer`, Caddy bouncer, nginx bouncer or appsec bouncer;
- do not change firewall rules;
- do not make `/var/log/caddy` world-readable.

## Current VPS Facts

Observed on 2026-06-08:

- VPS host: `176.12.67.92`, hostname `forgath.ru`.
- OS: Ubuntu 24.04.4 LTS.
- Caddy is installed and active.
- Caddy access log path: `/var/log/caddy/forgath-access.log`.
- Caddy access log owner/mode: `caddy:caddy`, `0640`.
- hbl reverse tunnel reaches VPS through `noftunnelhblvps`.
- Current accessible VPS user has no sudo and cannot read Caddy logs.

Root/sudo access is required to install CrowdSec safely.

## Install Plan

Do not run without owner approval in the current conversation.

1. Become a root-capable maintenance user on the VPS.

2. Install CrowdSec from the official CrowdSec Debian/Ubuntu repository.

   ```bash
   curl -s https://install.crowdsec.net | sudo sh
   sudo apt-get update
   sudo apt-get install -y crowdsec
   ```

   If the installer changes its recommended command, use the current official CrowdSec Linux install documentation and record the delta in this runbook.

3. Install required collections.

   ```bash
   sudo cscli collections install crowdsecurity/caddy
   sudo cscli collections install crowdsecurity/sshd
   sudo cscli hub update
   ```

4. Configure acquisition.

   The 2026-06-09 install used `cscli setup`, which generated:

   ```text
   /etc/crowdsec/acquis.d/setup.caddy.yaml
   /etc/crowdsec/acquis.d/setup.linux.yaml
   /etc/crowdsec/acquis.d/setup.sshd.yaml
   ```

   The Caddy generated acquisition reads `/var/log/caddy/*.log`, including the live `/var/log/caddy/forgath-access.log`.

   Do not additionally copy `environments/hbl/edge/vps-crowdsec/acquis.yaml.target` unless the generated setup files are removed or intentionally replaced; duplicate acquisition can double-count events.

5. Grant CrowdSec read access to Caddy logs without public permissions if the installed package uses a dedicated service user.

   On the 2026-06-09 VPS install, the systemd unit does not set a dedicated `User=`, so the service runs as root and can already read `0640` Caddy logs. No group or ACL change was needed.

   If a future package version uses a dedicated `crowdsec` user, prefer:

   ```bash
   sudo usermod -aG caddy crowdsec
   ```

   Then restart CrowdSec so group membership is effective.

   If the package user is not named `crowdsec`, inspect the service user first:

   ```bash
   systemctl cat crowdsec
   id crowdsec
   ```

6. Restart and enable CrowdSec.

   ```bash
   sudo systemctl restart crowdsec
   sudo systemctl enable crowdsec
   ```

## Verification

Run these checks after installation. Do not paste secrets; these commands should not output secret values.

1. Service is active.

   ```bash
   sudo systemctl status crowdsec --no-pager
   ```

2. No bouncer is registered.

   ```bash
   sudo cscli bouncers list
   ```

   Expected: empty list or no active bouncers for this VPS.

3. Collections are installed.

   ```bash
   sudo cscli collections list | grep -E 'crowdsecurity/(caddy|sshd)'
   ```

4. Acquisition sees log files.

   ```bash
   sudo cscli metrics
   ```

   Expected: metrics include Caddy and SSH acquisition/parsing after traffic exists.

5. Generate safe traffic.

   ```bash
   curl -I https://forgath.ru/
   curl -I https://forgath.ru/.well-known/nof-crowdsec-smoke
   ```

6. Inspect alerts/decisions.

   ```bash
   sudo cscli alerts list
   sudo cscli decisions list
   ```

   Expected in observe-only phase: alerts may appear after suspicious traffic, but no traffic is blocked because no bouncer is installed.

## Future Blocking Gate

Do not enable blocking until a separate owner-approved task exists.

Before any bouncer:

- confirm admin/operator IP allowlist;
- confirm rollback command;
- test in a short maintenance window;
- start with firewall bouncer only if it is the simplest fit for VPS traffic;
- never enable application blocking and Caddy config changes in the same step.

Potential future commands belong in a separate runbook, not here.

## Rollback

If CrowdSec itself causes resource or logging issues:

```bash
sudo systemctl disable --now crowdsec
```

If package removal is approved:

```bash
sudo apt-get remove crowdsec
```

Do not remove logs or package state until evidence needed for incident review is exported.

## Stop Conditions

- The command would require printing secret values.
- Installer asks to install or enable a bouncer in phase 1.
- Caddy log access requires world-readable permissions.
- CrowdSec service cannot start after acquisition config.
- CPU, memory or disk usage becomes abnormal after installation.
