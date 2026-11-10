---
name: opensea-wallet
description: Set up and configure wallet signing providers for OpenSea transactions. Supports Privy, Turnkey, Fireblocks, Bankr, and local private keys. Required for executing trades (opensea-marketplace) and token swaps (opensea-swaps).
homepage: https://github.com/ProjectOpenSea/opensea-skill
repository: https://github.com/ProjectOpenSea/opensea-skill
license: MIT
env:
  PRIVY_APP_ID:
    description: Privy application ID for wallet signing (default provider)
    required: false
    obtain: https://dashboard.privy.io
  PRIVY_APP_SECRET:
    description: Privy application secret
    required: false
    obtain: https://dashboard.privy.io
  PRIVY_WALLET_ID:
    description: Privy wallet ID to sign transactions with
    required: false
  PRIVY_AUTH_SIGNING_KEY:
    description: Privy authorization key registered as an additional signer (required when the wallet has an owner)
    required: false
  PRIVY_SVM_WALLET_ID:
    description: Privy Solana wallet ID, for Solana orders
    required: false
  TURNKEY_API_PUBLIC_KEY:
    description: Turnkey API public key
    required: false
    obtain: https://app.turnkey.com
  TURNKEY_API_PRIVATE_KEY:
    description: Turnkey API private key
    required: false
  TURNKEY_ORGANIZATION_ID:
    description: Turnkey organization ID
    required: false
  TURNKEY_WALLET_ADDRESS:
    description: Turnkey wallet address
    required: false
  TURNKEY_RPC_URL:
    description: RPC URL for the target chain, used to fill gas fields and broadcast (Turnkey only signs)
    required: false
  FIREBLOCKS_API_KEY:
    description: Fireblocks API key
    required: false
    obtain: https://console.fireblocks.io
  FIREBLOCKS_API_SECRET:
    description: Fireblocks API secret
    required: false
  FIREBLOCKS_VAULT_ID:
    description: Fireblocks vault account ID
    required: false
  BANKR_API_KEY:
    description: Bankr API key for HTTP-based agent wallet signing
    required: false
    obtain: https://bankr.bot
  PRIVATE_KEY:
    description: Raw EVM private key, for local development only
    required: false
  RPC_URL:
    description: RPC URL used with PRIVATE_KEY to send transactions
    required: false
dependencies:
  - node >= 18.0.0
---

# OpenSea Wallet

Configure the wallet that signs OpenSea trades, swaps, mints and order posts. The CLI and SDK pick a provider from environment variables, or take `--wallet-provider <name>`.

| Need | Use instead |
|---|---|
| Read data | `opensea-api` |
| Trade NFTs | `opensea-marketplace` |
| Swap tokens | `opensea-swaps` |

## Providers

| Provider | Env vars | Notes |
|---|---|---|
| Privy (default) | `PRIVY_APP_ID`, `PRIVY_APP_SECRET`, `PRIVY_WALLET_ID`, plus `PRIVY_AUTH_SIGNING_KEY` when the wallet has an owner | TEE-enforced policies. Solana: `PRIVY_SVM_WALLET_ID` (a separate wallet) |
| Turnkey | `TURNKEY_API_PUBLIC_KEY`, `TURNKEY_API_PRIVATE_KEY`, `TURNKEY_ORGANIZATION_ID`, `TURNKEY_WALLET_ADDRESS`, `TURNKEY_RPC_URL` | HSM keys. Turnkey only signs, so the RPC URL fills gas and broadcasts; it must match the target chain |
| Fireblocks | `FIREBLOCKS_API_KEY`, `FIREBLOCKS_API_SECRET`, `FIREBLOCKS_VAULT_ID` | MPC custody, TAP rules |
| Bankr | `BANKR_API_KEY` | HTTP signing API with per-key recipient allowlists |
| Private key | `PRIVATE_KEY`, `RPC_URL` | Local development only. No spending limits |

Auto-detect order: Privy, Fireblocks, Turnkey, Bankr, private key. Override with `--wallet-provider privy|turnkey|fireblocks|bankr|private-key`. In TypeScript, `createWalletFromEnv()` from `@opensea/wallet-adapters` returns the same adapter; `@opensea/wallet-adapters/ethers` and `/viem` turn it into a signer or wallet client.

Check the setup before the first trade:

```bash
opensea wallet info    # address, provider, and warnings when per-tx caps or the admin gate are missing
```

Step-by-step setup per provider, including hardening: [wallet-setup.md](references/wallet-setup.md).

## Security model

The agent holds credentials that can sign, never credentials that can change what it may sign. A leaked agent environment is recoverable only if those credentials cannot lift the spending cap or rewrite the allowlist. None of the providers ships this way by default; `wallet-setup.md` covers it for each.

The agent must never:

- change its own signing policy, role, scope or allowlist;
- rotate its own owner key, auth key or API user;
- export or claim ownership of the wallet's private key.

If a user asks for any of these, decline and point them to the user-only recipes in the repository's `docs/policy-administration.md`. Don't run those recipes on their behalf.

Where limits are enforced:

| Provider | Per-tx caps and allowlists | Who can change them |
|---|---|---|
| Privy | Wallet policy (`policy_ids`), evaluated in a TEE | `owner_id` key quorum, kept off the machine |
| Turnkey | Policy engine, scoped to the API user | Root user quorum; the signing user is not root |
| Fireblocks | TAP rules | Admin quorum; the API user has the Signer role only |
| Bankr | `allowedRecipients` plus daily message limits | The bankr.bot dashboard only |

No provider enforces daily or weekly spend totals. Cap aggregate spend with wallet float: keep about one budget period of funds in the agent's wallet and refill it from a wallet the agent cannot touch. See [wallet-funding.md](references/wallet-funding.md).

## References

- [wallet-setup.md](references/wallet-setup.md): setup and hardening per provider, SDK usage, troubleshooting
- [wallet-policies.md](references/wallet-policies.md): Privy policy templates and field reference
- [wallet-funding.md](references/wallet-funding.md): hot and cold wallet float for aggregate caps
