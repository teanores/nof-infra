#!/usr/bin/env bash
set -euo pipefail

RUNNER_URL="${RUNNER_URL:-https://github.com/teanores/nof-infra}"
RUNNER_NAME="${RUNNER_NAME:-hbl-nof-infra-runner}"
RUNNER_LABELS="${RUNNER_LABELS:-nof-infra,linux}"
RUNNER_DIR="${RUNNER_DIR:-$HOME/actions-runner-nof-infra}"
RUNNER_WORK_DIR="${RUNNER_WORK_DIR:-/tmp/actions-runner-nof-infra-work}"

usage() {
  cat <<'USAGE'
Install the dedicated nof-infra GitHub Actions runner on hbl.

Required environment variables from GitHub's official "New self-hosted runner" page:
  RUNNER_PACKAGE_URL       Official Linux x64 runner package URL.
  RUNNER_PACKAGE_SHA256    Official package SHA256.

Optional environment variables:
  RUNNER_URL               Default: https://github.com/teanores/nof-infra
  RUNNER_NAME              Default: hbl-nof-infra-runner
  RUNNER_LABELS            Default: nof-infra,linux
  RUNNER_DIR               Default: $HOME/actions-runner-nof-infra
  RUNNER_WORK_DIR          Default: /tmp/actions-runner-nof-infra-work

The short-lived registration token is read from a hidden prompt.
Do not pass the token as a command argument and do not paste it into chat/logs.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$(id -un)" != "nofadminhbl" ]]; then
  echo "Refusing install: run this script as nofadminhbl on hbl." >&2
  exit 64
fi

if [[ -z "${RUNNER_PACKAGE_URL:-}" || -z "${RUNNER_PACKAGE_SHA256:-}" ]]; then
  usage >&2
  echo "Missing RUNNER_PACKAGE_URL or RUNNER_PACKAGE_SHA256." >&2
  exit 64
fi

if [[ "$RUNNER_URL" != "https://github.com/teanores/nof-infra" ]]; then
  echo "Refusing install: RUNNER_URL must be https://github.com/teanores/nof-infra." >&2
  exit 64
fi

if [[ "$RUNNER_LABELS" != *"nof-infra"* || "$RUNNER_LABELS" != *"linux"* ]]; then
  echo "Refusing install: RUNNER_LABELS must include nof-infra and linux." >&2
  exit 64
fi

if systemctl list-units --type=service --all --no-pager | grep -q 'actions.runner.teanores-nof-infra'; then
  echo "Refusing install: a teanores-nof-infra runner service already exists." >&2
  systemctl list-units --type=service --all --no-pager | grep 'actions.runner.teanores-nof-infra' >&2
  exit 65
fi

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [[ -e ".runner" ]]; then
  echo "Refusing install: $RUNNER_DIR already contains a configured runner." >&2
  exit 65
fi

package_name="${RUNNER_PACKAGE_URL##*/}"
curl -fsSL "$RUNNER_PACKAGE_URL" -o "$package_name"

actual_sha="$(sha256sum "$package_name" | awk '{print $1}')"
if [[ "$actual_sha" != "$RUNNER_PACKAGE_SHA256" ]]; then
  echo "Refusing install: runner package SHA256 mismatch." >&2
  echo "expected=$RUNNER_PACKAGE_SHA256" >&2
  echo "actual=$actual_sha" >&2
  exit 66
fi

tar xzf "$package_name"

printf "Paste GitHub runner registration token for %s: " "$RUNNER_URL" >&2
IFS= read -r -s RUNNER_TOKEN
printf "\n" >&2

if [[ -z "$RUNNER_TOKEN" ]]; then
  echo "Refusing install: empty registration token." >&2
  exit 64
fi

./config.sh \
  --url "$RUNNER_URL" \
  --token "$RUNNER_TOKEN" \
  --name "$RUNNER_NAME" \
  --labels "$RUNNER_LABELS" \
  --work "$RUNNER_WORK_DIR" \
  --unattended

unset RUNNER_TOKEN

sudo ./svc.sh install nofadminhbl
sudo ./svc.sh start

systemctl list-units --type=service --all --no-pager | grep 'actions.runner.teanores-nof-infra' || {
  echo "Runner service was not found after install." >&2
  exit 67
}

echo "nof-infra GitHub runner installed. Verify labels in GitHub UI before first deploy."
