#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NOF_RELEASE_BUILDER_SOURCE_ONLY=1
export NOF_RELEASE_BUILDER_SOURCE_ONLY
# shellcheck source=../release-builder/nof-release-builder.sh
source "$repo_root/release-builder/nof-release-builder.sh"

service_config nof-mp
if [[ "$MIGRATION_MODE" != "none" ]]; then
  echo "expected nof-mp migration mode none, got $MIGRATION_MODE" >&2
  exit 1
fi
require_migration_gate_ready nof-mp "$MIGRATION_MODE"

service_config nof-tt
if [[ "$MIGRATION_MODE" != "none" ]]; then
  echo "expected nof-tt migration mode none, got $MIGRATION_MODE" >&2
  exit 1
fi
require_migration_gate_ready nof-tt "$MIGRATION_MODE"

service_config nof-ht
if [[ "$MIGRATION_MODE" != "job" ]]; then
  echo "expected nof-ht migration mode job, got $MIGRATION_MODE" >&2
  exit 1
fi

set +e
output="$(require_migration_gate_ready nof-ht "$MIGRATION_MODE" 2>&1)"
status=$?
set -e

if [[ "$status" -ne 78 ]]; then
  echo "expected nof-ht migration gate to fail with exit 78, got $status" >&2
  exit 1
fi

if [[ "$output" != *"MIGRATION_MODE=job"* || "$output" != *"refusing to continue before build/push/Helm"* ]]; then
  echo "expected fail-closed migration gate message, got: $output" >&2
  exit 1
fi

echo "release-builder migration gate: ok"
