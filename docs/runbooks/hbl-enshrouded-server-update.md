# hbl Enshrouded Server Update

Status: draft, requires owner approval before use.
Date: 2026-06-21.
Owner: nof-infra / owner.

## Purpose

Update the Enshrouded dedicated server running on hbl without losing local
world state or silently breaking the Wine-based service.

This runbook records the 2026-06-21 production finding from `NOF-INFRA-6`:
Steam app `2278520` is Windows-only for the dedicated server. On a Linux/Wine
host, SteamCMD must be run with `+@sSteamCmdForcePlatformType windows`.
Without that override, `app_update 2278520 validate` can fetch an incomplete
depot and leave `enshrouded_server.exe` missing.

## Strict Boundary

Do not run the update section without explicit owner approval in the current
conversation.

This runbook must not:

- read or print game passwords;
- print private keys, tokens or secret values;
- change WireGuard, UFW, iptables, Caddy, Kubernetes or release-builder state;
- modify `nof-infra` desired-state;
- touch unrelated processes owned by the `enshrouded` user.

## Known hbl Shape

Read-only discovery on 2026-06-21 found:

- systemd unit: `enshrouded.service`;
- service user/group: `enshrouded`;
- working directory: `/home/enshrouded/enshroudedserver`;
- Wine prefix: `/home/enshrouded/.wine`;
- executable: `/home/enshrouded/enshroudedserver/enshrouded_server.exe`;
- Steam app id: `2278520`;
- public game endpoint through VPS/WireGuard: `176.12.67.92:15637/udp`;
- hbl listener after successful start: `0.0.0.0:15637/udp`.

## Read-Only Discovery

Run these before proposing an update:

```bash
systemctl is-active enshrouded.service
systemctl status enshrouded.service --no-pager -l
ps -u enshrouded -o pid,etimes,cmd | grep -Ei 'enshrouded_server|wine|winedevice|wineserver' || true
ss -lunp | grep -E ':(15636|15637)\b' || true
grep -E 'appid|buildid|LastUpdated|SizeOnDisk|StateFlags' \
  /home/enshrouded/enshroudedserver/steamapps/appmanifest_2278520.acf
stat -c '%n %y %s' \
  /home/enshrouded/enshroudedserver/enshrouded_server.exe \
  /home/enshrouded/enshroudedserver/steamapps/appmanifest_2278520.acf
command -v steamcmd
```

Expected:

- service state is understood before stopping anything;
- `steamcmd` is available;
- current build and file timestamps are recorded;
- no config file content is printed.

## Owner Approval Packet

Before update, brief the owner in chat:

```text
I will update the Enshrouded dedicated server on hbl.

Expected changes:
- create a backup of config, savegame and Steam manifest;
- stop enshrouded.service;
- run SteamCMD app_update 2278520 validate with Windows platform override;
- start enshrouded.service;
- verify service, UDP listener, Steam connection and owner UAT.

Expected downtime:
- game server unavailable during update and restart.

Rollback:
- restore the backup and restart enshrouded.service if the updated server does
  not start or the owner cannot connect.

Stop conditions:
- backup fails;
- SteamCMD fails;
- enshrouded_server.exe is missing after update;
- service does not reach game_server Run;
- UDP 15637 does not listen after startup.
```

Continue only after explicit owner approval in the current conversation.

## Backup

Create a backup without printing config contents:

```bash
sudo install -d -o enshrouded -g enshrouded -m 750 /home/enshrouded/backups
ts="$(date -u +%Y%m%dT%H%M%SZ)"
sudo tar -C /home/enshrouded/enshroudedserver \
  -czf "/home/enshrouded/backups/pre-update-$ts-config-savegame-manifest.tar.gz" \
  config \
  savegame \
  steamapps/appmanifest_2278520.acf \
  steam_appid.txt
sudo chown enshrouded:enshrouded \
  "/home/enshrouded/backups/pre-update-$ts-config-savegame-manifest.tar.gz"
sudo ls -lh "/home/enshrouded/backups/pre-update-$ts-config-savegame-manifest.tar.gz"
```

Record only the backup path and size in evidence.

## Update

Stop the service:

```bash
sudo systemctl stop enshrouded.service
```

Run SteamCMD with the Windows platform override:

```bash
sudo -u enshrouded /usr/games/steamcmd \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir /home/enshrouded/enshroudedserver \
  +login anonymous \
  +app_update 2278520 validate \
  +quit
```

Expected:

- SteamCMD exits successfully;
- output includes `Success! App '2278520' fully installed.`;
- `enshrouded_server.exe` exists after update;
- manifest `SizeOnDisk` should reflect the full Windows depot, not only a small
  runtime/common depot.

## Start And Smoke

Start the service:

```bash
sudo systemctl start enshrouded.service
sleep 30
systemctl is-active enshrouded.service
systemctl status enshrouded.service --no-pager -l
```

Check build and listener:

```bash
grep -E 'appid|buildid|LastUpdated|SizeOnDisk|StateFlags' \
  /home/enshrouded/enshroudedserver/steamapps/appmanifest_2278520.acf
stat -c '%n %y %s' \
  /home/enshrouded/enshroudedserver/enshrouded_server.exe \
  /home/enshrouded/enshroudedserver/steamapps/appmanifest_2278520.acf
ss -lunp | grep -E ':(15636|15637)\b'
grep -Ei 'Server connected to Steam successfully|game_server.*Run|error|fail' \
  /home/enshrouded/enshroudedserver/logs/enshrouded_server.log | tail -n 120
```

Expected:

- `enshrouded.service` is active;
- `enshrouded_server.exe` is running under Wine;
- log includes Steam connection and game server running state;
- UDP `0.0.0.0:15637` is listening.

If local external smoke is needed, capture on hbl `wg0` while sending one UDP
packet to the public VPS endpoint:

```bash
sudo timeout 10 tcpdump -ni wg0 udp port 15637 -c 1
```

Expected capture shape:

```text
IP 10.250.0.1.<source-port> > 10.250.0.2.15637: UDP
```

## Owner UAT

Ask the owner to connect from the Enshrouded client to:

```text
176.12.67.92
```

Expected:

- no game/server version mismatch;
- client connects to the server;
- existing world/save is available.

Fail if:

- client still reports version mismatch;
- server is unreachable;
- world/save is missing or appears reset.

## Troubleshooting

### Missing `enshrouded_server.exe`

Likely cause: SteamCMD ran without the Windows platform override.

Fix:

```bash
sudo -u enshrouded /usr/games/steamcmd \
  +@sSteamCmdForcePlatformType windows \
  +force_install_dir /home/enshrouded/enshroudedserver \
  +login anonymous \
  +app_update 2278520 validate \
  +quit
```

### Wine `c0000135`

First confirm whether the executable starts manually and whether another stale
Wine process is holding the log file:

```bash
sudo -u enshrouded bash -lc \
  'cd /home/enshrouded/enshroudedserver && WINEPREFIX=/home/enshrouded/.wine WINEDEBUG=+loaddll timeout 20s wine /home/enshrouded/enshroudedserver/enshrouded_server.exe' \
  2>&1 | tail -n 200
```

If the log reports a sharing violation for `logs/enshrouded_server.log`, stop
only Wine processes belonging to this game service, then restart:

```bash
sudo systemctl kill enshrouded.service || true
sudo pkill -u enshrouded -f 'wineserver|winedevice|enshrouded_server.exe|wine .*enshrouded_server.exe' || true
sudo systemctl reset-failed enshrouded.service || true
sudo systemctl start enshrouded.service
```

Do not kill unrelated non-Wine processes owned by `enshrouded`.

## Rollback

Use rollback if the service cannot start, the listener does not return, or owner
UAT fails in a way that points to update damage.

```bash
sudo systemctl stop enshrouded.service
sudo tar -C /home/enshrouded/enshroudedserver \
  -xzf "<backup-path>"
sudo chown -R enshrouded:enshrouded \
  /home/enshrouded/enshroudedserver/config \
  /home/enshrouded/enshroudedserver/savegame \
  /home/enshrouded/enshroudedserver/steamapps/appmanifest_2278520.acf \
  /home/enshrouded/enshroudedserver/steam_appid.txt
sudo systemctl start enshrouded.service
```

Then run the start and smoke checks again.

## Evidence

Record:

- owner approval text;
- pre-update build id and timestamp;
- backup path and size;
- SteamCMD success line;
- post-update build id and timestamp;
- service status;
- UDP listener;
- optional tcpdump smoke result;
- owner UAT result.

Do not record:

- game passwords;
- config file contents;
- private keys, tokens or secret values.
