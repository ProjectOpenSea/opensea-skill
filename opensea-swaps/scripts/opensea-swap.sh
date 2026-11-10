#!/usr/bin/env bash
set -euo pipefail

# Swap tokens via OpenSea CLI with auto-detected wallet provider
# Usage: ./opensea-swap.sh <to_token_address> <amount> [chain] [from_token] [wallet_provider]
#
# Example:
#   ./opensea-swap.sh 0xb695559b26bb2c9703ef1935c37aeae9526bab07 0.02 base
#   ./opensea-swap.sh 0xToToken 100 base 0xFromToken
#   ./opensea-swap.sh 0xToToken 100 base 0x0000000000000000000000000000000000000000 turnkey
#
# Required env vars:
#   OPENSEA_API_KEY    OpenSea API key
#   Plus one wallet provider's credentials. Without [wallet_provider], the CLI
#   picks one from env vars (see the opensea-wallet skill):
#     Privy (default):  PRIVY_APP_ID, PRIVY_APP_SECRET, PRIVY_WALLET_ID
#     Turnkey:          TURNKEY_API_PUBLIC_KEY, TURNKEY_API_PRIVATE_KEY, TURNKEY_ORGANIZATION_ID, TURNKEY_WALLET_ADDRESS, TURNKEY_RPC_URL
#     Fireblocks:       FIREBLOCKS_API_KEY, FIREBLOCKS_API_SECRET, FIREBLOCKS_VAULT_ID
#     Bankr:            BANKR_API_KEY
#     Private Key:      PRIVATE_KEY, RPC_URL, WALLET_ADDRESS

TO_TOKEN_ADDRESS="${1:?Usage: $0 <to_token_address> <amount> [chain] [from_token] [wallet_provider]}"
AMOUNT="${2:?Amount required}"
CHAIN="${3:-base}"
FROM_TOKEN_ADDRESS="${4:-0x0000000000000000000000000000000000000000}"
WALLET_PROVIDER="${5:-}"

if [ -z "${OPENSEA_API_KEY:-}" ]; then
  echo "OPENSEA_API_KEY environment variable is required" >&2
  exit 1
fi

# Validate required env vars for the selected provider
case "$WALLET_PROVIDER" in
  "")
    ;;
  privy)
    for var in PRIVY_APP_ID PRIVY_APP_SECRET PRIVY_WALLET_ID; do
      if [ -z "${!var:-}" ]; then
        echo "${var} environment variable is required for Privy provider" >&2
        exit 1
      fi
    done
    ;;
  turnkey)
    for var in TURNKEY_API_PUBLIC_KEY TURNKEY_API_PRIVATE_KEY TURNKEY_ORGANIZATION_ID TURNKEY_WALLET_ADDRESS TURNKEY_RPC_URL; do
      if [ -z "${!var:-}" ]; then
        echo "${var} environment variable is required for Turnkey provider" >&2
        exit 1
      fi
    done
    ;;
  fireblocks)
    for var in FIREBLOCKS_API_KEY FIREBLOCKS_API_SECRET FIREBLOCKS_VAULT_ID; do
      if [ -z "${!var:-}" ]; then
        echo "${var} environment variable is required for Fireblocks provider" >&2
        exit 1
      fi
    done
    ;;
  bankr)
    if [ -z "${BANKR_API_KEY:-}" ]; then
      echo "BANKR_API_KEY environment variable is required for Bankr provider" >&2
      exit 1
    fi
    ;;
  private-key)
    for var in PRIVATE_KEY RPC_URL WALLET_ADDRESS; do
      if [ -z "${!var:-}" ]; then
        echo "${var} environment variable is required for Private Key provider" >&2
        exit 1
      fi
    done
    ;;
  *)
    echo "Unknown wallet provider: $WALLET_PROVIDER (expected: privy, turnkey, fireblocks, bankr, private-key)" >&2
    exit 1
    ;;
esac

provider_args=()
if [ -n "$WALLET_PROVIDER" ]; then
  provider_args=(--wallet-provider "$WALLET_PROVIDER")
fi

exec opensea swaps execute \
  ${provider_args[@]+"${provider_args[@]}"} \
  --from-chain "$CHAIN" \
  --from-address "$FROM_TOKEN_ADDRESS" \
  --to-chain "$CHAIN" \
  --to-address "$TO_TOKEN_ADDRESS" \
  --quantity "$AMOUNT"
