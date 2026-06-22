#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NOF_RELEASE_BUILDER_SOURCE_ONLY=1
export NOF_RELEASE_BUILDER_SOURCE_ONLY
# shellcheck source=../release-builder/nof-release-builder.sh
source "$repo_root/release-builder/nof-release-builder.sh"

if grep -Eq "Direct SSH.*not supported|direct SSH deploy impossible|make direct SSH deploy impossible" "$repo_root/docs/runbooks/github-runner-release-builder.md"; then
  echo "runbook must preserve emergency/manual SSH flow instead of saying direct SSH is impossible" >&2
  exit 1
fi

unset GITHUB_ACTIONS
unset NOF_RELEASE_MANUAL_OVERRIDE
unset NOF_RELEASE_APPROVAL_ID

set +e
output="$(require_release_invocation_context deploy 2>&1)"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  echo "expected manual deploy without override to be refused" >&2
  exit 1
fi

if [[ "$output" != *"Routine product-agent deploys must use the GitHub runner flow"* ]]; then
  echo "expected refusal to point agents to GitHub runner flow, got: $output" >&2
  exit 1
fi

GITHUB_ACTIONS=true
NOF_RELEASE_APPROVAL_ID=NOF-INFRA-16
export GITHUB_ACTIONS
export NOF_RELEASE_APPROVAL_ID

output="$(require_release_invocation_context deploy)"
if [[ "$output" != *"Release invocation: github-runner approval=NOF-INFRA-16"* ]]; then
  echo "expected GitHub runner path to be allowed with approval id, got: $output" >&2
  exit 1
fi

unset GITHUB_ACTIONS
NOF_RELEASE_MANUAL_OVERRIDE=1
NOF_RELEASE_APPROVAL_ID=NOF-INFRA-16
export NOF_RELEASE_MANUAL_OVERRIDE
export NOF_RELEASE_APPROVAL_ID

output="$(require_release_invocation_context sync)"
if [[ "$output" != *"Release invocation: manual/emergency approval=NOF-INFRA-16"* ]]; then
  echo "expected manual emergency path to be allowed with override and approval id, got: $output" >&2
  exit 1
fi

NOF_RELEASE_APPROVAL_ID=""
export NOF_RELEASE_APPROVAL_ID

set +e
output="$(require_release_invocation_context deploy 2>&1)"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  echo "expected manual override without approval id to be refused" >&2
  exit 1
fi

if [[ "$output" != *"NOF_RELEASE_APPROVAL_ID is required for manual/emergency"* ]]; then
  echo "expected manual approval-id error, got: $output" >&2
  exit 1
fi

echo "release-builder manual guardrails: ok"
