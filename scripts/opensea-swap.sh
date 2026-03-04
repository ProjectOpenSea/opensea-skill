#!/usr/bin/env bash
set -euo pipefail

# Swap tokens via OpenSea MCP
# Usage: PRIVATE_KEY=0xYourKey ./opensea-swap.sh <to_token_address> <amount> <wallet_address> [chain] [from_token]
#
# Example:
#   PRIVATE_KEY=0xYourKey ./opensea-swap.sh 0xb695559b26bb2c9703ef1935c37aeae9526bab07 0.02 0xYourWallet base
#   PRIVATE_KEY=0xYourKey ./opensea-swap.sh 0xToToken 100 0xYourWallet base 0xFromToken
#
# Requires: OPENSEA_API_KEY env var, PRIVATE_KEY env var, mcporter, node with viem, jq

TO_TOKEN="${1:?Usage: PRIVATE_KEY=0x... $0 <to_token_address> <amount> <wallet_address> [chain] [from_token]}"
AMOUNT="${2:?Amount required}"
WALLET="${3:?Wallet address required}"
CHAIN="${4:-base}"
FROM_TOKEN="${5:-0x0000000000000000000000000000000000000000}"

if [ -z "${PRIVATE_KEY:-}" ]; then
  echo "❌ PRIVATE_KEY environment variable is required" >&2
  exit 1
fi

TMPFILE=$(mktemp /tmp/opensea_swap_quote.XXXXXX.json)
trap 'rm -f "$TMPFILE"' EXIT

echo "🔄 Getting swap quote: ${AMOUNT} tokens → token on ${CHAIN}..."

# Get swap quote via mcporter
if ! QUOTE=$(mcporter call opensea.get_token_swap_quote --args "{
  \"fromContractAddress\": \"${FROM_TOKEN}\",
  \"fromChain\": \"${CHAIN}\",
  \"toContractAddress\": \"${TO_TOKEN}\",
  \"toChain\": \"${CHAIN}\",
  \"fromQuantity\": \"${AMOUNT}\",
  \"address\": \"${WALLET}\"
}" --output raw 2>&1); then
  echo "❌ Failed to get quote: $QUOTE" >&2
  exit 1
fi

if ! echo "$QUOTE" | jq empty 2>/dev/null; then
  echo "❌ Invalid response (not JSON): $QUOTE" >&2
  exit 1
fi

if echo "$QUOTE" | jq -e '.error // .isError // empty' >/dev/null 2>&1; then
  echo "❌ Failed to get quote: $QUOTE" >&2
  exit 1
fi

# Save quote for parsing by node
echo "$QUOTE" > "$TMPFILE"

# Execute with node
node --input-type=module -e "
import { createPublicClient, createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { base, mainnet, polygon, arbitrum, optimism } from 'viem/chains';
import { readFileSync } from 'fs';

const chains = { base, ethereum: mainnet, mainnet, matic: polygon, polygon, arbitrum, optimism };
const chain = chains['${CHAIN}'] || base;

const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const wallet = createWalletClient({ account, chain, transport: http() });
const pub = createPublicClient({ chain, transport: http() });

// Parse the mcporter output (wrapped in content structure)
const raw = readFileSync('${TMPFILE}', 'utf8');
let quote;
try {
  const wrapper = JSON.parse(raw);
  quote = JSON.parse(wrapper.content[0].text);
} catch (e) {
  quote = JSON.parse(raw);
}

const txData = quote.swap.actions[0].transactionSubmissionData;
const toSymbol = quote.swapQuote.swapRoutes[0].toAsset.symbol;

console.log('📊 Quote received');
console.log('   To:', txData.to);
console.log('   Value:', txData.value, 'wei');
console.log('   Token:', toSymbol);

console.log('📤 Sending transaction...');

const hash = await wallet.sendTransaction({
  to: txData.to,
  data: txData.data,
  value: BigInt(txData.value)
});

console.log('TX: https://basescan.org/tx/' + hash);
console.log('⏳ Waiting for confirmation...');

const receipt = await pub.waitForTransactionReceipt({ hash });
console.log(receipt.status === 'success' ? '✅ Swap complete!' : '❌ Swap failed');
console.log('Gas used:', receipt.gasUsed.toString());
"
