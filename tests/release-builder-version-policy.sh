#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NOF_RELEASE_BUILDER_SOURCE_ONLY=1
export NOF_RELEASE_BUILDER_SOURCE_ONLY
# shellcheck source=../release-builder/nof-release-builder.sh
source "$repo_root/release-builder/nof-release-builder.sh"

actual="$(app_version_from_ref nof-mp v0.2.13)"
if [[ "$actual" != "0.2.13" ]]; then
  echo "expected semver app version 0.2.13, got $actual" >&2
  exit 1
fi

set +e
output="$(app_version_from_ref nof-mp 12ebee4 2>&1)"
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  echo "expected raw commit ref to fail for nof-mp" >&2
  exit 1
fi

if [[ "$output" != *"must use a semver tag ref"* ]]; then
  echo "expected semver policy error, got: $output" >&2
  exit 1
fi

echo "release-builder version policy: ok"
