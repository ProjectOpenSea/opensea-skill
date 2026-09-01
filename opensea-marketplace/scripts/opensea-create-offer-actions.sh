#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: opensea-create-offer-actions.sh [--start-time <iso>] [--end-time <iso>] [--use-creator-fee] <chain> <contract> <token_id> <maker> <quantity> <amount> <currency_address>" >&2
  echo "  currency_address is a token mint/contract address, not a symbol; native SOL uses 11111111111111111111111111111111" >&2
  exit 1
}

start_time=""
end_time=""
use_creator_fee=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --start-time)
      [ "$#" -ge 2 ] || usage
      start_time="$2"
      shift 2
      ;;
    --end-time)
      [ "$#" -ge 2 ] || usage
      end_time="$2"
      shift 2
      ;;
    --use-creator-fee)
      use_creator_fee=true
      shift
      ;;
    --*) usage ;;
    *) break ;;
  esac
done

[ "$#" -eq 7 ] || usage
chain="$1"
contract="$2"
token_id="$3"
maker="$4"
quantity="$5"
amount="$6"
currency_address="$7"

[[ "$chain" =~ ^[a-z0-9_]+$ ]] || {
  echo "opensea-create-offer-actions.sh: invalid chain '$chain'" >&2
  exit 1
}
[[ "$quantity" =~ ^[1-9][0-9]*$ ]] || {
  echo "opensea-create-offer-actions.sh: quantity must be a positive integer" >&2
  exit 1
}
command -v jq >/dev/null || {
  echo "opensea-create-offer-actions.sh: jq is required" >&2
  exit 1
}

key="${OPENSEA_API_KEY:-}"
[ -n "$key" ] || {
  echo "opensea-create-offer-actions.sh: OPENSEA_API_KEY is required" >&2
  exit 1
}

body=$(jq -n \
  --arg chain "$chain" \
  --arg contract "$contract" \
  --arg token_id "$token_id" \
  --arg maker "$maker" \
  --argjson quantity "$quantity" \
  --arg amount "$amount" \
  --arg currency "$currency_address" \
  --arg start_time "$start_time" \
  --arg end_time "$end_time" \
  --argjson use_creator_fee "$use_creator_fee" \
  '{
    item: {chain: $chain, contract: $contract, token_id: $token_id},
    address: $maker,
    quantity: $quantity,
    price: {amount: $amount, currency: $currency}
  }
  + (if $start_time == "" then {} else {start_time: $start_time} end)
  + (if $end_time == "" then {} else {end_time: $end_time} end)
  + (if $use_creator_fee then {use_creator_fee: true} else {} end)')

base="${OPENSEA_BASE_URL:-https://api.opensea.io}"
response_file=$(mktemp)
trap 'rm -f "$response_file"' EXIT
if ! http_code=$(curl -sS --connect-timeout 10 --max-time 30 \
  -X POST "$base/api/v2/offers/actions" \
  -H "x-api-key: $key" \
  -H "User-Agent: opensea-skill/1.0" \
  -H "Content-Type: application/json" \
  --data "$body" \
  -o "$response_file" \
  -w '%{http_code}'); then
  echo "opensea-create-offer-actions.sh: request failed" >&2
  exit 1
fi

if [[ ! "$http_code" =~ ^2 ]]; then
  echo "opensea-create-offer-actions.sh: HTTP $http_code error" >&2
  jq . "$response_file" >&2 || sed -n '1,120p' "$response_file" >&2
  exit 1
fi
jq . "$response_file"
