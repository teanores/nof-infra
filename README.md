# nof-infra

Canonical infrastructure repository for the NOF ecosystem.

This repository stores infrastructure definitions and runbooks that are not service application code:

- Kubernetes and Helm definitions;
- release-builder and deploy automation definitions;
- hbl deployment discovery and desired-state;
- hbl edge target state for VPS Caddy and portal-gateway;
- local, hbl and future environment runbooks;
- migration plans for service keys, images, releases and public hostnames.

No secret values belong in this repository.

## Naming

Infrastructure identifiers must use service keys:

- `nof-mp`
- `nof-tt`
- `nof-ht`
- `nof-cb`

Public hostnames may use user-facing product names:

- `forgath.ru`
- `task-tracker.forgath.ru`
- `habit-tracker.forgath.ru`

Legacy identifiers such as `nof-platform` and `forge-tasks` are migration debt.

## Current Priority

1. Discover the actual hbl deploy mechanism after GitHub merge/tag/release.
2. Document whether it is GitHub Actions, hbl-runner, webhook receiver, cron, systemd, Kubernetes job or scripts.
3. Move non-secret deploy scripts and desired-state here after ownership is confirmed.
4. Prepare the OAuth release cutover for `nof-mp`, `nof-tt` and `nof-ht`.
