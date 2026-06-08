#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="${NOF_EDGE_AUDIT_LOG_FILE:-/var/log/caddy/forgath-access.log}"
STATE_FILE="${NOF_EDGE_AUDIT_STATE_FILE:-/var/lib/nof-edge-audit/offset}"
ENDPOINT="${NOF_EDGE_AUDIT_ENDPOINT:-https://forgath.ru/api/admin/security/edge-events}"
TOKEN="${NOF_EDGE_AUDIT_TOKEN:-}"
MAX_BYTES="${NOF_EDGE_AUDIT_MAX_BYTES:-262144}"

if [[ -z "$TOKEN" ]]; then
  echo "ERROR: NOF_EDGE_AUDIT_TOKEN is not set." >&2
  exit 2
fi

if [[ ! -f "$LOG_FILE" ]]; then
  exit 0
fi

mkdir -p "$(dirname "$STATE_FILE")"

current_size="$(wc -c < "$LOG_FILE" | tr -d ' ')"
offset="0"
if [[ -f "$STATE_FILE" ]]; then
  offset="$(cat "$STATE_FILE")"
fi

if ! [[ "$offset" =~ ^[0-9]+$ ]]; then
  offset="0"
fi

if (( current_size < offset )); then
  offset="0"
fi

if (( current_size == offset )); then
  exit 0
fi

bytes_to_send=$((current_size - offset))
if (( bytes_to_send > MAX_BYTES )); then
  offset=$((current_size - MAX_BYTES))
  bytes_to_send="$MAX_BYTES"
fi

tmp_payload="$(mktemp)"
trap 'rm -f "$tmp_payload"' EXIT

tail -c +"$((offset + 1))" "$LOG_FILE" | head -c "$bytes_to_send" > "$tmp_payload"

if [[ ! -s "$tmp_payload" ]]; then
  printf '%s\n' "$current_size" > "$STATE_FILE"
  exit 0
fi

curl --fail --silent --show-error \
  --request POST \
  --header "Authorization: Bearer $TOKEN" \
  --header "Content-Type: application/x-ndjson" \
  --data-binary "@$tmp_payload" \
  "$ENDPOINT" >/dev/null

printf '%s\n' "$current_size" > "$STATE_FILE"
