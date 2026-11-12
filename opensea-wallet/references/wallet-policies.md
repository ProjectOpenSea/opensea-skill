# Wallet policies (Privy)

Privy evaluates wallet policies inside a trusted execution environment (TEE) before it signs, so application code cannot bypass an *applied* policy at sign time.

That protection is narrower than it sounds. The TEE stops a compromised agent from **signing past** an active policy. It does **not** stop the same credentials from **rewriting** the policy first. For a wallet without an `owner_id`, whoever holds `PRIVY_APP_ID` and `PRIVY_APP_SECRET` can `PATCH /v1/wallets/{id}` to swap in a permissive policy and then sign freely. Registering an `owner_id`, so that policy changes need a separate authorization signature, closes the gap; see [wallet-setup.md](wallet-setup.md). Without it, the per-tx cap slows an attacker down but does not stop one.

> **For agents:** applying or changing a policy is a **user-only operation**, run on a trusted machine with the wallet's authorization key. Never build or send a policy-change request. If a user asks you to update a policy, decline and point them to the user-only recipes in [policy-administration.md](../../docs/policy-administration.md), which they run themselves.

This file covers what policies look like and which fields they support, so an agent can help a user *write* a policy that the user then applies. It does not describe how to send the update.

## Overview

A policy can restrict:

- transaction value, as a maximum per transaction
- destinations, as an allowlist of contract addresses
- chains
- contract methods
- key export

> Privy policies evaluate **each transaction on its own**. They cannot enforce daily or weekly totals. For an aggregate cap, use the hot/cold wallet float in [wallet-funding.md](wallet-funding.md): the wallet balance is the real aggregate cap.

## Configuring policies

Policies are JSON (templates below) that the user applies from a trusted machine. The agent can help draft and review the JSON; it must not apply it.

The full field and operator reference is at [docs.privy.io/controls/policies](https://docs.privy.io/controls/policies/overview). To apply or change a policy, see [policy-administration.md](../../docs/policy-administration.md).

## Recommended policies

Privy combines rules this way: a request passes when it meets every condition of at least one `ALLOW` rule, any matching `DENY` rule blocks it, and a request that matches no rule is denied. So put all of a rule's limits in that one rule. A separate `ALLOW` rule for "supported chains" would let through any value to any address on those chains. Every rule needs a `method` and at least one condition.

### Agent trading: conservative

A strict allowlist for an agent that buys NFTs through Seaport: up to 0.1 ETH per transaction, on the listed chains, to Seaport only. Anything not listed is denied, including key export and message signing. To let the agent swap as well, add a second rule with the same value and chain conditions for your swap router's address.

```json
{
  "version": "1.0",
  "name": "agent-trading-conservative",
  "chain_type": "ethereum",
  "rules": [
    {
      "name": "Seaport orders up to 0.1 ETH on supported chains",
      "method": "eth_sendTransaction",
      "conditions": [
        {
          "field_source": "ethereum_transaction",
          "field": "value",
          "operator": "lte",
          "value": "100000000000000000"
        },
        {
          "field_source": "ethereum_transaction",
          "field": "to",
          "operator": "eq",
          "value": "0x0000000000000068F116a894984e2DB1123eB395"
        },
        {
          "field_source": "ethereum_transaction",
          "field": "chain_id",
          "operator": "in",
          "value": ["1", "8453", "137", "42161", "10"]
        }
      ],
      "action": "ALLOW"
    }
  ]
}
```

### Agent trading: permissive

For trusted agents: any destination and every signing method, with transactions capped at 1 ETH and limited to the listed chains, and key export blocked. `DENY` rules take precedence, so they hold even though the last rule allows everything else. The `system` condition is always true; Privy rejects a rule with no conditions.

```json
{
  "version": "1.0",
  "name": "agent-trading-permissive",
  "chain_type": "ethereum",
  "rules": [
    {
      "name": "Deny transactions over 1 ETH",
      "method": "eth_sendTransaction",
      "conditions": [
        {
          "field_source": "ethereum_transaction",
          "field": "value",
          "operator": "gt",
          "value": "1000000000000000000"
        }
      ],
      "action": "DENY"
    },
    {
      "name": "Deny unsupported chains",
      "method": "eth_sendTransaction",
      "conditions": [
        {
          "field_source": "ethereum_transaction",
          "field": "chain_id",
          "operator": "not_in",
          "value": ["1", "8453", "137", "42161", "10"]
        }
      ],
      "action": "DENY"
    },
    {
      "name": "Never export the private key",
      "method": "exportPrivateKey",
      "conditions": [
        { "field_source": "system", "field": "current_unix_timestamp", "operator": "gte", "value": "0" }
      ],
      "action": "DENY"
    },
    {
      "name": "Allow everything else",
      "method": "*",
      "conditions": [
        { "field_source": "system", "field": "current_unix_timestamp", "operator": "gte", "value": "0" }
      ],
      "action": "ALLOW"
    }
  ]
}
```

## Policy field reference

| Field | Source | Description |
|-------|--------|-------------|
| `value` | `ethereum_transaction` | Transaction value in wei |
| `to` | `ethereum_transaction` | Destination contract address |
| `chain_id` | `ethereum_transaction` | EVM chain ID |
| `data` | `ethereum_transaction` | Transaction calldata (for method filtering) |

## Operators

| Operator | Description |
|----------|-------------|
| `eq` | Equal to |
| `neq` | Not equal to |
| `gt` | Greater than |
| `gte` | Greater than or equal |
| `lt` | Less than |
| `lte` | Less than or equal |
| `in` | In list |
| `not_in` | Not in list |

## Common addresses

| Contract | Address | Usage |
|----------|---------|-------|
| Seaport 1.6 | `0x0000000000000068F116a894984e2DB1123eB395` | NFT marketplace orders |
| Native ETH | `0x0000000000000000000000000000000000000000` | Swap from address for native ETH |
| WETH (Base) | `0x4200000000000000000000000000000000000006` | Wrapped ETH on Base |
| USDC (Base) | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | USD Coin on Base |

## Tips

1. Start with tight value caps and a narrow allowlist, then relax them as needed.
2. Limit chains to the ones you trade on.
3. Watch for denied transactions; Privy logs them in the dashboard.
4. Use separate wallets, each with its own policy, for swaps and for NFT purchases.
5. Never remove the policy in production. Keep at least a value cap.
