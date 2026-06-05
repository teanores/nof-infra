# AGENTS.md - NOF Infrastructure

This repository owns NOF infrastructure code and deployment documentation.

Rules:

- Do not store, print or commit secret values.
- Keep service application code in service repositories: `nof-mp`, `nof-tt`, `nof-ht`, `nof-cb`.
- Use NOF service keys for infrastructure identifiers: `nof-mp`, `nof-tt`, `nof-ht`, `nof-cb`.
- Public hostnames may use product names, for example `task-tracker.forgath.ru`.
- Production and hbl changes require explicit owner approval in the current conversation and a runbook.
- Prefer read-only discovery before changing hbl, Kubernetes, Helm or release-builder state.

Canonical sources:

- Root workspace standard: `../AGENTS.md`.
- Naming standard: `../docs/naming-standard.md`.
- Tracker/Wiki ownership: `nof-tt`.
