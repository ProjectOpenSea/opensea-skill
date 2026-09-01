#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 4 ]; then
  echo "Usage: opensea-cancel-order-actions.sh <chain> <protocol_address> <order_identifier> <maker>" >&2
  exit 1
fi

chain="$1"
protocol_address="$2"
order_identifier="$3"
maker="$4"

[[ "$chain" =~ ^[a-z0-9_]+$ ]] || {
  echo "opensea-cancel-order-actions.sh: invalid chain '$chain'" >&2
  exit 1
}
command -v jq >/dev/null || {
  echo "opensea-cancel-order-actions.sh: jq is required" >&2
  exit 1
}

key="${OPENSEA_API_KEY:-}"
[ -n "$key" ] || {
  echo "opensea-cancel-order-actions.sh: OPENSEA_API_KEY is required" >&2
  exit 1
}

body=$(jq -n --arg maker "$maker" '{address: $maker}')
base="${OPENSEA_BASE_URL:-https://api.opensea.io}"
path="/api/v2/orders/chain/$chain/protocol/$protocol_address/$order_identifier/cancel/actions"
response_file=$(mktemp)
trap 'rm -f "$response_file"' EXIT
if ! http_code=$(curl -sS --connect-timeout 10 --max-time 30 \
  -X POST "$base$path" \
  -H "x-api-key: $key" \
  -H "User-Agent: opensea-skill/1.0" \
  -H "Content-Type: application/json" \
  --data "$body" \
  -o "$response_file" \
  -w '%{http_code}'); then
  echo "opensea-cancel-order-actions.sh: request failed" >&2
  exit 1
fi

if [[ ! "$http_code" =~ ^2 ]]; then
  echo "opensea-cancel-order-actions.sh: HTTP $http_code error" >&2
  jq . "$response_file" >&2 || sed -n '1,120p' "$response_file" >&2
  exit 1
fi
jq . "$response_file"
