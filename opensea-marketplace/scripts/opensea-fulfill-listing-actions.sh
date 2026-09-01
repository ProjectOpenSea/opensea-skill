#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: opensea-fulfill-listing-actions.sh [--recipient <address>] [--units-to-fill <n>] [--include-optional-creator-fees] <chain> <order_identifier> <protocol_address> <fulfiller>" >&2
  exit 1
}

recipient=""
units_to_fill=""
include_optional_creator_fees=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --recipient)
      [ "$#" -ge 2 ] || usage
      recipient="$2"
      shift 2
      ;;
    --units-to-fill)
      [ "$#" -ge 2 ] || usage
      units_to_fill="$2"
      shift 2
      ;;
    --include-optional-creator-fees)
      include_optional_creator_fees=true
      shift
      ;;
    --*) usage ;;
    *) break ;;
  esac
done

[ "$#" -eq 4 ] || usage
chain="$1"
order_identifier="$2"
protocol_address="$3"
fulfiller="$4"

[[ "$chain" =~ ^[a-z0-9_]+$ ]] || {
  echo "opensea-fulfill-listing-actions.sh: invalid chain '$chain'" >&2
  exit 1
}
if [ -n "$units_to_fill" ] && [[ ! "$units_to_fill" =~ ^[1-9][0-9]*$ ]]; then
  echo "opensea-fulfill-listing-actions.sh: units-to-fill must be a positive integer" >&2
  exit 1
fi
command -v jq >/dev/null || {
  echo "opensea-fulfill-listing-actions.sh: jq is required" >&2
  exit 1
}

key="${OPENSEA_API_KEY:-}"
[ -n "$key" ] || {
  echo "opensea-fulfill-listing-actions.sh: OPENSEA_API_KEY is required" >&2
  exit 1
}

body=$(jq -n \
  --arg hash "$order_identifier" \
  --arg chain "$chain" \
  --arg protocol_address "$protocol_address" \
  --arg fulfiller "$fulfiller" \
  --arg recipient "$recipient" \
  --arg units_to_fill "$units_to_fill" \
  --argjson include_optional_creator_fees "$include_optional_creator_fees" \
  '{
    listing: {hash: $hash, chain: $chain, protocol_address: $protocol_address},
    fulfiller: {address: $fulfiller},
    include_optional_creator_fees: $include_optional_creator_fees
  }
  + (if $recipient == "" then {} else {recipient: $recipient} end)
  + (if $units_to_fill == "" then {} else {units_to_fill: ($units_to_fill | tonumber)} end)')

base="${OPENSEA_BASE_URL:-https://api.opensea.io}"
response_file=$(mktemp)
trap 'rm -f "$response_file"' EXIT
if ! http_code=$(curl -sS --connect-timeout 10 --max-time 30 \
  -X POST "$base/api/v2/listings/fulfillment/actions" \
  -H "x-api-key: $key" \
  -H "User-Agent: opensea-skill/1.0" \
  -H "Content-Type: application/json" \
  --data "$body" \
  -o "$response_file" \
  -w '%{http_code}'); then
  echo "opensea-fulfill-listing-actions.sh: request failed" >&2
  exit 1
fi

if [[ ! "$http_code" =~ ^2 ]]; then
  echo "opensea-fulfill-listing-actions.sh: HTTP $http_code error" >&2
  jq . "$response_file" >&2 || sed -n '1,120p' "$response_file" >&2
  exit 1
fi
jq . "$response_file"
