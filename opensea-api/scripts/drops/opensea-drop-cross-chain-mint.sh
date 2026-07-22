#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 5 ]; then
  echo "Usage: opensea-drop-cross-chain-mint.sh <collection_slug> <payer> <minter> <payment_chain> <payment_token> [quantity]" >&2
  echo "Build ordered transactions for paying on one EVM chain and minting on another" >&2
  echo "Example: opensea-drop-cross-chain-mint.sh pyro-on-ape 0xPayer 0xMinter base 0x0000000000000000000000000000000000000000 1" >&2
  exit 1
fi

slug="$1"
payer="$2"
minter="$3"
payment_chain="$4"
payment_token="$5"
quantity="${6:-1}"
null_address="0x0000000000000000000000000000000000000000"

if [[ ! "$slug" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "opensea-drop-cross-chain-mint.sh: invalid collection slug" >&2
  exit 1
fi

if [[ ! "$payer" =~ ^0x[0-9a-fA-F]{40}$ ]] || [ "$payer" = "$null_address" ]; then
  echo "opensea-drop-cross-chain-mint.sh: payer must be a non-null Ethereum address" >&2
  exit 1
fi

if [[ ! "$minter" =~ ^0x[0-9a-fA-F]{40}$ ]] || [ "$minter" = "$null_address" ]; then
  echo "opensea-drop-cross-chain-mint.sh: minter must be a non-null Ethereum address" >&2
  exit 1
fi

if [[ ! "$payment_chain" =~ ^[a-z0-9_]+$ ]]; then
  echo "opensea-drop-cross-chain-mint.sh: invalid payment chain" >&2
  exit 1
fi

if [[ ! "$payment_token" =~ ^0x[0-9a-fA-F]{40}$ ]]; then
  echo "opensea-drop-cross-chain-mint.sh: payment token must be an Ethereum address" >&2
  exit 1
fi

if ! [[ "$quantity" =~ ^[1-9][0-9]*$ ]] || [ "$quantity" -gt 100 ]; then
  echo "opensea-drop-cross-chain-mint.sh: quantity must be between 1 and 100" >&2
  exit 1
fi

body=$(cat <<EOF
{
  "payer": "$payer",
  "minter": "$minter",
  "quantity": $quantity,
  "payment": {
    "chain": "$payment_chain",
    "token_address": "$payment_token"
  }
}
EOF
)

"$(dirname "$0")/../opensea-post.sh" "/api/v2/drops/${slug}/cross_chain_mint" "$body"
