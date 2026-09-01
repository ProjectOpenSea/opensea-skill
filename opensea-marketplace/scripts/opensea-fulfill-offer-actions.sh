#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: opensea-fulfill-offer-actions.sh [--contract <address> --token-id <id>] [--units-to-fill <n>] [--include-optional-creator-fees] <chain> <order_identifier> <protocol_address> <fulfiller>" >&2
  exit 1
}

contract=""
token_id=""
units_to_fill=""
include_optional_creator_fees=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --contract)
      [ "$#" -ge 2 ] || usage
      contract="$2"
      shift 2
      ;;
    --token-id)
      [ "$#" -ge 2 ] || usage
      token_id="$2"
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
  echo "opensea-fulfill-offer-actions.sh: invalid chain '$chain'" >&2
  exit 1
}
if { [ -n "$contract" ] && [ -z "$token_id" ]; } ||
  { [ -z "$contract" ] && [ -n "$token_id" ]; }; then
  echo "opensea-fulfill-offer-actions.sh: --contract and --token-id must be provided together" >&2
  exit 1
fi
if [ -n "$units_to_fill" ] && [[ ! "$units_to_fill" =~ ^[1-9][0-9]*$ ]]; then
  echo "opensea-fulfill-offer-actions.sh: units-to-fill must be a positive integer" >&2
  exit 1
fi
command -v jq >/dev/null || {
  echo "opensea-fulfill-offer-actions.sh: jq is required" >&2
  exit 1
}

key="${OPENSEA_API_KEY:-}"
[ -n "$key" ] || {
  echo "opensea-fulfill-offer-actions.sh: OPENSEA_API_KEY is required" >&2
  exit 1
}

body=$(jq -n \
  --arg hash "$order_identifier" \
  --arg chain "$chain" \
  --arg protocol_address "$protocol_address" \
  --arg fulfiller "$fulfiller" \
  --arg contract "$contract" \
  --arg token_id "$token_id" \
  --arg units_to_fill "$units_to_fill" \
  --argjson include_optional_creator_fees "$include_optional_creator_fees" \
  '{
    offer: {hash: $hash, chain: $chain, protocol_address: $protocol_address},
    fulfiller: {address: $fulfiller},
    include_optional_creator_fees: $include_optional_creator_fees
  }
  + (if $contract == "" then {} else {consideration: {asset_contract_address: $contract, token_id: $token_id}} end)
  + (if $units_to_fill == "" then {} else {units_to_fill: ($units_to_fill | tonumber)} end)')

base="${OPENSEA_BASE_URL:-https://api.opensea.io}"
response_file=$(mktemp)
trap 'rm -f "$response_file"' EXIT
if ! http_code=$(curl -sS --connect-timeout 10 --max-time 30 \
  -X POST "$base/api/v2/offers/fulfillment/actions" \
  -H "x-api-key: $key" \
  -H "User-Agent: opensea-skill/1.0" \
  -H "Content-Type: application/json" \
  --data "$body" \
  -o "$response_file" \
  -w '%{http_code}'); then
  echo "opensea-fulfill-offer-actions.sh: request failed" >&2
  exit 1
fi

if [[ ! "$http_code" =~ ^2 ]]; then
  echo "opensea-fulfill-offer-actions.sh: HTTP $http_code error" >&2
  jq . "$response_file" >&2 || sed -n '1,120p' "$response_file" >&2
  exit 1
fi
jq . "$response_file"
