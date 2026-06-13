# hbl GitHub Runner Discovery

Generated: 2026-06-14

## Scope

Read-only discovery for GitHub Actions runner migration.

## Current Runner

Existing hbl runner:

```text
actions.runner.teanores-nof-ht.hbl-runner.service
```

Status at discovery:

```text
loaded, active, running
```

Repository scope from `.runner`:

```text
https://github.com/teanores/nof-ht
```

Runner install path:

```text
/home/nofadminhbl/actions-runner
```

## Decision

Do not reuse or reconfigure this runner for the target NOF release standard.

It is product-specific and belongs to the temporary nof-ht legacy path.

## Required Target

Create a separate infra-owned runner for:

```text
https://github.com/teanores/nof-infra
```

Required labels:

```text
self-hosted
linux
nof-infra
```

Recommended path:

```text
/home/nofadminhbl/actions-runner-nof-infra
```

## Blocker

Registration requires a short-lived GitHub runner registration token from the `teanores/nof-infra` repository settings.

Do not store or print that token in chat, Wiki, tracker, git, logs or shell history.

## Next Verification

After registration:

```bash
systemctl list-units --type=service --all --no-pager | grep -i actions.runner
systemctl status <new-nof-infra-runner-service> --no-pager -l
```

Then run the nof-infra GitHub workflow with:

```text
execute_deploy=false
```

Expected:

- validate job passes;
- deploy job is skipped;
- no hbl production command runs.
