# WireGuard VPS↔hbl Tunnel for Game Server UDP Forwarding

Status: readiness draft, production VPS and hbl changes require owner approval in the current conversation.

Tracker:

- Epic: `NOF-INFRA-EPIC-VPS-HBL-GAME-TUNNEL`.
- Sprint: `NOF-INFRA-SPRINT-1`.
- Tasks: `NOF-INFRA-1`, `NOF-INFRA-2`, `NOF-INFRA-3`, `NOF-INFRA-4`, `NOF-INFRA-5`.
- Related product dependency: `NOF-MP-10` (nof-mp UI, depends on this infra path).

## Purpose

Expose UDP game server ports running on `hbl` (starting with Enshrouded) to friends via the stable VPS public IP, instead of hbl's dynamic home IP. The existing VPS Caddy + reverse SSH tunnel path is HTTP(S)-only and cannot carry raw UDP game traffic.

## Discovery Evidence (2026-06-20/21)

- Leftover, unused WireGuard keypairs found on both hosts (`/etc/wireguard/{private,public}.key`, dated 2026-05-29) — no `wg0.conf` on either side, never wired up. This runbook generates fresh keys and a real config.
- VPS (`176.12.67.92`, `forgath.ru`): Ubuntu 24.04.4, single public IP on `ens3` (no NAT on VPS side). UFW active, default-deny INPUT/FORWARD, currently allows only `22/80/443/ispmanager`. WireGuard kernel module loaded, `wg`/`wg-quick` present. `nofadminvps` has sudo.
- hbl (`192.168.1.51`): behind home NAT, dynamic public IP (observed `37.204.66.35`). UFW active, allows only `OpenSSH` + Calico interfaces (`vxlan.calico`, `cali+`). WireGuard kernel module loaded, `wg`/`wg-quick` present. K8s Calico pod CIDR is `10.1.0.0/16`; docker0 is `172.17.0.0/16`; LAN is `192.168.1.0/24`.
- Existing, unrelated, working reverse SSH tunnel: systemd unit `nof-tunnel-hbl-vps.service` (active) via dedicated user `noftunnelhblvps`. This runbook does not touch it.
- Enshrouded dedicated server is already running on hbl via Wine under Linux user `enshrouded`, confirmed listening on UDP `15637` (query port) on `0.0.0.0`. Game port `15636/udp` assumed standard but not yet directly confirmed listening — verify during apply.
- Read-only freshness checks on 2026-06-21 confirmed: both hosts have `wg`/`wg-quick`; no active `wg0`; no WireGuard UDP port currently open in UFW; existing reverse SSH tunnel remains active; no hbl/VPS mutation was performed.

## Chosen Design

- hbl initiates the WireGuard session to VPS (hbl is behind NAT; VPS is not). VPS listens on `51820/udp`.
- Tunnel subnet: `10.250.0.0/30` — VPS `10.250.0.1`, hbl `10.250.0.2`. Chosen to avoid collision with Calico (`10.1.0.0/16`), docker0 (`172.17.0.0/16`), and LAN (`192.168.1.0/24`).
- VPS DNATs public UDP `15636-15637` to `10.250.0.2:15636-15637` (hbl's tunnel address).
- hbl UFW allows inbound on `wg0` (mirrors the existing pattern of trusting `cali+`/`vxlan.calico` interfaces).
- `PersistentKeepalive=25` on the hbl peer config so the NAT mapping does not expire.
- VPS SNATs forwarded game UDP packets to `10.250.0.1` on `wg0`. Without this, hbl WireGuard drops forwarded packets whose original source is an external public IP, because the hbl peer allows only `10.250.0.1/32`.

## Apply Procedure

Do not run without owner approval in the current conversation.

## Owner Approval Packet

Use this packet before any production VPS/hbl mutation. Approval must be explicit in the current chat and must name the WireGuard VPS-hbl game tunnel apply window.

I changed/prepared:

- A WireGuard tunnel design where hbl initiates to VPS, VPS listens on `51820/udp`, and VPS forwards public UDP `15636-15637` to hbl over `10.250.0.0/30`.
- A rollback path that disables `wg-quick@wg0`, removes UFW rules, removes transient iptables rules, and preserves the existing HTTP(S) reverse SSH tunnel.
- Secret boundary: private WireGuard keys stay on their hosts and must not be pasted into chat, tracker, Wiki, git or shell logs.

If you approve, the operator may run these production-changing groups:

1. Generate fresh WireGuard keys on VPS and hbl without printing private key values.
2. Create `/etc/wireguard/wg0.conf` on both hosts with mode `600`.
3. Open VPS `51820/udp`, start `wg-quick@wg0` on both hosts, and verify handshake.
4. Add temporary VPS forwarding/DNAT/SNAT rules for UDP `15636-15637`.
5. Open VPS UDP `15636-15637` and hbl inbound UDP `15636-15637` on `wg0`.
6. Smoke test UDP reachability and owner Enshrouded client connection.
7. Persist forwarding only after smoke passes and rollback persistence is known.

UAT after apply:

1. External game access
   Test: From an external network, connect an Enshrouded client to `176.12.67.92`.
   Expected: Server is discoverable/reachable and can be joined.
   Fail if: Client cannot reach the server, connection is unstable, or only local/LAN access works.

2. Existing public portal
   Test: Open `https://forgath.ru` and `https://task-tracker.forgath.ru`.
   Expected: Existing HTTP(S) access still works through the current Caddy/reverse SSH path.
   Fail if: Portal login, Task Tracker, Caddy, or `nof-tunnel-hbl-vps.service` is affected.

3. Access safety
   Test: Confirm SSH remains available on VPS and hbl after firewall changes.
   Expected: Existing SSH access is preserved.
   Fail if: Any firewall command threatens `22/tcp`, default SSH allow rules, or current admin access.

Approval does not include:

- changing Kubernetes, Helm, release-builder or desired-state;
- changing the existing reverse SSH tunnel;
- publishing or storing private key values;
- broad firewall allow rules beyond the ports/interfaces named above.

### 1. Generate fresh keys (do not reuse the 2026-05-29 leftovers)

These commands must not print private key contents. Public keys may be exchanged; private keys stay on their host.

On VPS:
```bash
sudo sh -c 'umask 077; wg genkey > /etc/wireguard/vps_private.key'
sudo sh -c 'wg pubkey < /etc/wireguard/vps_private.key > /etc/wireguard/vps_public.key'
sudo chmod 600 /etc/wireguard/vps_private.key
```

On hbl:
```bash
sudo sh -c 'umask 077; wg genkey > /etc/wireguard/hbl_private.key'
sudo sh -c 'wg pubkey < /etc/wireguard/hbl_private.key > /etc/wireguard/hbl_public.key'
sudo chmod 600 /etc/wireguard/hbl_private.key
```

Exchange only the **public** keys between hosts (never print/paste private key contents into chat).

### 2. VPS config — `/etc/wireguard/wg0.conf`

Create the file with mode `600`. Do not paste the private key into chat, tracker, Wiki or shell logs.

```ini
[Interface]
Address = 10.250.0.1/30
ListenPort = 51820
PrivateKey = <vps private key>

[Peer]
PublicKey = <hbl public key>
AllowedIPs = 10.250.0.2/32
```

### 3. hbl config — `/etc/wireguard/wg0.conf`

Create the file with mode `600`. Do not paste the private key into chat, tracker, Wiki or shell logs.

```ini
[Interface]
Address = 10.250.0.2/30
PrivateKey = <hbl private key>

[Peer]
PublicKey = <vps public key>
Endpoint = 176.12.67.92:51820
AllowedIPs = 10.250.0.1/32
PersistentKeepalive = 25
```

### 4. Open WireGuard port on VPS UFW

```bash
sudo ufw allow 51820/udp
```

### 5. Bring up the interface on both sides

```bash
sudo systemctl enable --now wg-quick@wg0
```

Verify handshake:
```bash
sudo wg show
```
Expected: `latest handshake` populated within ~30s on both sides, `transfer` counters non-zero.

### 6. VPS: enable forwarding + DNAT game ports

```bash
sudo sysctl -w net.ipv4.ip_forward=1
printf '%s\n' 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-wg-forward.conf

sudo iptables -t nat -A PREROUTING -i ens3 -p udp --dport 15636:15637 -j DNAT --to-destination 10.250.0.2
sudo iptables -t nat -A POSTROUTING -o wg0 -p udp -d 10.250.0.2 --dport 15636:15637 -j SNAT --to-source 10.250.0.1
sudo iptables -A FORWARD -i ens3 -o wg0 -p udp --dport 15636:15637 -d 10.250.0.2 -j ACCEPT
sudo iptables -A FORWARD -i wg0 -o ens3 -p udp --sport 15636:15637 -s 10.250.0.2 -j ACCEPT

sudo ufw allow 15636:15637/udp
```

Persist iptables rules only after the first smoke test passes. On the current VPS, persistence is through `/etc/ufw/before.rules`.

Required persistent snippets:

```text
# before *filter
*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
-A PREROUTING -i ens3 -p udp --dport 15636:15637 -j DNAT --to-destination 10.250.0.2
-A POSTROUTING -o wg0 -p udp -d 10.250.0.2 --dport 15636:15637 -j SNAT --to-source 10.250.0.1
COMMIT

# inside *filter before normal ufw-before-forward handling
-A ufw-before-forward -i ens3 -o wg0 -p udp -d 10.250.0.2 --dport 15636:15637 -j ACCEPT
-A ufw-before-forward -i wg0 -o ens3 -p udp -s 10.250.0.2 --sport 15636:15637 -j ACCEPT
```

Before reload:

```bash
sudo cp /etc/ufw/before.rules /etc/ufw/before.rules.nof-infra-wg-backup-<timestamp>
sudo iptables-restore --test < /etc/ufw/before.rules
sudo ufw reload
```

### 7. hbl: allow inbound game UDP on wg0

```bash
sudo ufw allow in on wg0 to any port 15636:15637 proto udp
```

### 8. Smoke test

From an external machine (not VPS, not hbl):
```bash
nc -u -z -w3 176.12.67.92 15637 && echo "UDP 15637 reachable"
```
Confirm an actual Enshrouded client can connect using `176.12.67.92` as the server address.

## Rollback

```bash
# VPS
sudo systemctl disable --now wg-quick@wg0
sudo iptables -t nat -D PREROUTING -i ens3 -p udp --dport 15636:15637 -j DNAT --to-destination 10.250.0.2
sudo iptables -t nat -D POSTROUTING -o wg0 -p udp -d 10.250.0.2 --dport 15636:15637 -j SNAT --to-source 10.250.0.1
sudo iptables -D FORWARD -i ens3 -o wg0 -p udp --dport 15636:15637 -d 10.250.0.2 -j ACCEPT
sudo iptables -D FORWARD -i wg0 -o ens3 -p udp --sport 15636:15637 -s 10.250.0.2 -j ACCEPT
sudo ufw delete allow 51820/udp
sudo ufw delete allow 15636:15637/udp

# hbl
sudo systemctl disable --now wg-quick@wg0
sudo ufw delete allow in on wg0 to any port 15636:15637 proto udp
```

Existing `nof-tunnel-hbl-vps.service` and Caddy/portal-gateway HTTP(S) routing are untouched by this change and untouched by rollback.

If persistence was enabled through `/etc/ufw/before.rules`, restore the recorded backup or remove the `NOF-INFRA WireGuard game UDP DNAT/SNAT` and `NOF-INFRA WireGuard game UDP forwarding` snippets, then run:

```bash
sudo iptables-restore --test < /etc/ufw/before.rules
sudo ufw reload
```

## Stop Conditions

- Any UFW command on VPS or hbl that would touch the default `22/tcp` (SSH) rule — do not modify, only add new rules.
- `wg show` shows no handshake after 2 minutes — stop and diagnose (NAT/firewall on hbl's home router may block outbound UDP 51820, unlikely but check) before retrying blindly.
- Forwarding rule changes that affect IP ranges used by Calico, docker0, or the existing reverse SSH tunnel.
- Need to print/paste a WireGuard private key value anywhere.
- Need to reuse the leftover 2026-05-29 keypairs instead of generating fresh keys.
- Game port `15636/udp` is not confirmed listening before apply, unless the owner explicitly accepts a query-port-only test window.
- The available firewall persistence mechanism cannot be identified before persistence is enabled.
