#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

NOF_RELEASE_BUILDER_SOURCE_ONLY=1
export NOF_RELEASE_BUILDER_SOURCE_ONLY
# shellcheck source=../release-builder/nof-release-builder.sh
source "$repo_root/release-builder/nof-release-builder.sh"

unset NOF_RELEASE_SYNC_APPROVED_SERVICES
unset NOF_RELEASE_SYNC_REQUIRE_APPROVED_SERVICES
if ! sync_service_is_approved nof-mp; then
  echo "expected unset allowlist to allow existing broad-sync behavior" >&2
  exit 1
fi

NOF_RELEASE_SYNC_REQUIRE_APPROVED_SERVICES=1
export NOF_RELEASE_SYNC_REQUIRE_APPROVED_SERVICES

if sync_service_is_approved nof-mp; then
  echo "expected required allowlist mode to block unset allowlist" >&2
  exit 1
fi

NOF_RELEASE_SYNC_APPROVED_SERVICES=""
export NOF_RELEASE_SYNC_APPROVED_SERVICES

if sync_service_is_approved nof-mp; then
  echo "expected required allowlist mode to block empty allowlist" >&2
  exit 1
fi

NOF_RELEASE_SYNC_APPROVED_SERVICES="nof-mp,nof-tt"
export NOF_RELEASE_SYNC_APPROVED_SERVICES

if ! sync_service_is_approved nof-mp; then
  echo "expected nof-mp to be approved" >&2
  exit 1
fi

if ! sync_service_is_approved nof-tt; then
  echo "expected nof-tt to be approved" >&2
  exit 1
fi

if sync_service_is_approved nof-ht; then
  echo "expected nof-ht to be blocked by allowlist" >&2
  exit 1
fi

NOF_RELEASE_SYNC_APPROVED_SERVICES=" nof-mp "
export NOF_RELEASE_SYNC_APPROVED_SERVICES

if ! sync_service_is_approved nof-mp; then
  echo "expected whitespace-trimmed nof-mp to be approved" >&2
  exit 1
fi

if sync_service_is_approved nof-tt; then
  echo "expected nof-tt to be blocked by single-service allowlist" >&2
  exit 1
fi

echo "release-builder sync allowlist: ok"
