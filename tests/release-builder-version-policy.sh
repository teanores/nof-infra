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

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
mkdir -p "$tmp_dir/chart"
cat > "$tmp_dir/chart/Chart.yaml" <<'EOF'
apiVersion: v2
name: nof-mp
description: fixture
type: application
version: 0.1.0
appVersion: "0.2.0"
EOF

set_chart_app_version "$tmp_dir/chart" "0.2.47"

if ! grep -qx 'appVersion: "0.2.47"' "$tmp_dir/chart/Chart.yaml"; then
  echo "expected Chart.yaml appVersion to be rewritten for Helm history" >&2
  cat "$tmp_dir/chart/Chart.yaml" >&2
  exit 1
fi

echo "release-builder version policy: ok"
