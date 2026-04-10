#!/usr/bin/env bash
set -euo pipefail

# Swap tokens via OpenSea CLI with Privy wallet
# Usage: ./opensea-swap.sh <to_token_address> <amount> [chain] [from_token]
#
# Example:
#   ./opensea-swap.sh 0xb695559b26bb2c9703ef1935c37aeae9526bab07 0.02 base
#   ./opensea-swap.sh 0xToToken 100 base 0xFromToken
#
# Required env vars:
#   OPENSEA_API_KEY    — OpenSea API key
#   PRIVY_APP_ID       — Privy application ID
#   PRIVY_APP_SECRET   — Privy application secret
#   PRIVY_WALLET_ID    — Privy wallet ID to sign with

TO_TOKEN="${1:?Usage: $0 <to_token_address> <amount> [chain] [from_token]}"
AMOUNT="${2:?Amount required}"
CHAIN="${3:-base}"
FROM_TOKEN="${4:-0x0000000000000000000000000000000000000000}"

for var in OPENSEA_API_KEY PRIVY_APP_ID PRIVY_APP_SECRET PRIVY_WALLET_ID; do
  if [ -z "${!var:-}" ]; then
    echo "${var} environment variable is required" >&2
    exit 1
  fi
done

exec opensea swaps execute \
  --from-chain "$CHAIN" \
  --from-address "$FROM_TOKEN" \
  --to-chain "$CHAIN" \
  --to-address "$TO_TOKEN" \
  --quantity "$AMOUNT"
