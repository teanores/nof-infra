# nof-infra Agent Session State

Updated: 2026-06-21.

## Current Status

- Active tracker goal: `NOF-INFRA-GOAL-RELEASE-AND-OPS-OWNERSHIP`.
- No active nof-infra sprint after closing `NOF-INFRA-SPRINT-3`.
- Latest integrated commit on `main`: `e77b088 docs: document enshrouded server update`.
- `origin/main` contains the Enshrouded update runbook:
  `docs/runbooks/hbl-enshrouded-server-update.md`.

## Completed Work

- `NOF-INFRA-SPRINT-2` closed:
  - `NOF-INFRA-4` applied and verified the WireGuard VPS-to-hbl game UDP tunnel.
  - `NOF-INFRA-6` updated the hbl Enshrouded dedicated server after owner saw
    game/server version mismatch.
  - Owner UAT passed: the owner connected from the game client to the server.
- `NOF-INFRA-SPRINT-3` closed:
  - `NOF-INFRA-7` documented the hbl Enshrouded update runbook.

## Production State Summary

- Public game endpoint: `176.12.67.92:15637/udp`.
- hbl game server listens on UDP `0.0.0.0:15637`.
- Traffic reaches hbl through the WireGuard VPS-to-hbl path.
- Firewall exposure is scoped to the game UDP ports; broad hbl `wg0` allow was
  removed during Sprint 2.
- Enshrouded dedicated server was updated to Steam build `23178631`.

## Important Operational Notes

- Enshrouded Steam app `2278520` is Windows-only for the dedicated server.
- On hbl Linux/Wine, SteamCMD update must include:
  `+@sSteamCmdForcePlatformType windows`.
- Without that override, SteamCMD can fetch an incomplete depot and leave
  `enshrouded_server.exe` missing.
- Do not run hbl/VPS/production-changing commands without explicit owner
  approval in the current conversation.
- Do not print or store game passwords, private keys, tokens, database URLs or
  Kubernetes secret values.

## Security Posture

The public game endpoint is acceptable for the current use case but not zero
risk:

- exposure is limited to the game UDP endpoint through VPS/WireGuard;
- no SSH, HTTP(S), Kubernetes or release-builder access was opened by the game
  work;
- residual risk remains from Enshrouded dedicated server/Wine vulnerabilities
  and UDP denial-of-service attempts.

Recommended future hardening:

- observe/rate-limit UDP traffic on VPS where practical;
- audit `enshrouded.service` systemd hardening options;
- add a periodic Enshrouded update/readiness check;
- keep owner UAT after every game server update.

## Next Candidate Sprint

No active sprint exists. Before continuing implementation, plan a focused
`NOF-INFRA-SPRINT-*` from owner priorities. Good candidates:

- game endpoint hardening and observability;
- nof-ht release-builder migration;
- infra-owned GitHub runner/release-builder path;
- desired-state and release preflight cleanup.
