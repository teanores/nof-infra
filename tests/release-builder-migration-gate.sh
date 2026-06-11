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
if [[ "$MIGRATION_COMMAND" != "npm run db:migrate:release" ]]; then
  echo "expected nof-ht release migration command, got $MIGRATION_COMMAND" >&2
  exit 1
fi
require_migration_gate_ready nof-ht "$MIGRATION_MODE"

redacted="$(printf '%s\n' 'DATABASE_URL=postgresql://user:password@example/db PASSWORD=secret TOKEN=token SECRET=value' | redact_secrets_from_stream)"
if [[ "$redacted" == *"password"* || "$redacted" == *"secret"* || "$redacted" == *"token" ]]; then
  echo "expected secret redaction, got: $redacted" >&2
  exit 1
fi

echo "release-builder migration gate: ok"
