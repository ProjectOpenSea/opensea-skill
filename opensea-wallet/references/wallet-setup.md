# Wallet setup

The OpenSea CLI and SDK sign through a `WalletAdapter`. Four managed providers are built in, plus a raw private key for local development.

| Provider | Best for | Docs |
|----------|----------|------|
| **Privy** (default) | TEE-enforced policies, embedded wallets | [privy.io](https://privy.io) |
| **Turnkey** | HSM-backed keys, multi-party approval | [turnkey.com](https://www.turnkey.com) |
| **Fireblocks** | Enterprise MPC custody, institutional use | [fireblocks.com](https://www.fireblocks.com) |
| **Bankr** | Agent wallets via HTTP signing API | [bankr.bot](https://bankr.bot) |
| **Private key** (not recommended) | Local dev/testing only | (none) |

Use a managed provider (Privy, Turnkey, Fireblocks) rather than a raw private key. They enforce spending limits, destination allowlists and policies; a raw key enforces nothing.

The CLI picks the provider from whichever environment variables are set. Override it with `--wallet-provider privy|turnkey|fireblocks|bankr|private-key`.

---

## Privy setup

### Prerequisites

- A Privy account ([privy.io](https://privy.io))
- An OpenSea API key (`OPENSEA_API_KEY`)
- A trusted operator machine (your laptop, a vault host) separate from the machine that runs the agent. You generate the wallet's authorization key here, and its private key never reaches the agent.

### 1. Create a Privy app

1. Create an app at [dashboard.privy.io](https://dashboard.privy.io).
2. Copy the **App ID** and **App Secret** from the app settings page.

### 2. Create a server wallet

```bash
curl -X POST https://api.privy.io/v1/wallets \
  -H "Authorization: Basic $(printf "%s:%s" "$PRIVY_APP_ID" "$PRIVY_APP_SECRET" | base64)" \
  -H "privy-app-id: $PRIVY_APP_ID" \
  -H "Content-Type: application/json" \
  -d '{ "chain_type": "ethereum" }'
```

> Build the basic-auth header with `printf %s`, not `echo`. The trailing newline `echo` adds corrupts the base64 credentials and returns a 401 with a misleading "Invalid app ID or app secret" body.

Save the wallet `id` from the response as `PRIVY_WALLET_ID`.

### 3. Register an authorization key on the wallet

Do this step; it is not optional hardening. Without it, the `PRIVY_APP_ID` and `PRIVY_APP_SECRET` the agent signs with can also rewrite the wallet's policy on their own, including raising the spending cap you set in step 6.

**On your operator machine** (not the agent host), generate a P-256 keypair:

```bash
# Generates a base64-encoded PKCS8 P-256 private key + the matching public key.
node -e '
  const { generateKeyPairSync } = require("crypto");
  const { publicKey, privateKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const pkcs8 = privateKey.export({ type: "pkcs8", format: "der" }).toString("base64");
  const spki  = publicKey.export({ type: "spki", format: "der" }).toString("base64");
  console.log("PRIVATE (keep on operator machine):", pkcs8);
  console.log("PUBLIC  (register with Privy):     ", spki);
'
```

Register the public key as the wallet's **owner** by following [Privy's authorization key guide](https://docs.privy.io/controls/authorization-keys/overview). Store the private key in your password manager or vault. **Never put the owner private key in the agent's env.**

For the agent to sign while the owner key stays off the machine, register a *second* P-256 keypair as an `additional_signer` on the wallet, with `override_policy_ids` set to the policy you create in step 6. That signer's private key goes in the agent's `PRIVY_AUTH_SIGNING_KEY`. It can sign transactions the policy allows; it cannot change the policy or the signers.

### 4. Set environment variables

```bash
export OPENSEA_API_KEY="your-opensea-api-key"
export PRIVY_APP_ID="your-privy-app-id"
export PRIVY_APP_SECRET="your-privy-app-secret"
export PRIVY_WALLET_ID="your-privy-wallet-id"

# Required when the wallet has owner_id set (recommended). Base64-encoded
# PKCS8 P-256 private key for an additional_signer registered on the
# wallet. NEVER set this to the OWNER private key.
export PRIVY_AUTH_SIGNING_KEY="..."
```

### 5. Verify

```bash
opensea wallet info
```

It prints JSON with the wallet address, policy IDs, owner key ID and `ownerEnforcesAuthKey: true`. A warning on stderr means a hardening step is missing. Fix it before funding the wallet.

<details>
<summary>Fallback: verify via curl</summary>

```bash
curl -s "https://api.privy.io/v1/wallets/$PRIVY_WALLET_ID" \
  -H "Authorization: Basic $(printf "%s:%s" "$PRIVY_APP_ID" "$PRIVY_APP_SECRET" | base64)" \
  -H "privy-app-id: $PRIVY_APP_ID" | jq .
```

> Use `printf %s` here, not `echo`. The trailing newline `echo` adds breaks the basic-auth header.

</details>

### 6. Configure a per-tx policy

Templates and the field reference are in [wallet-policies.md](wallet-policies.md). The user applies the policy with the user-only recipe in [policy-administration.md](../../docs/policy-administration.md). The agent never builds or sends the policy-update request.

Privy policies cannot enforce daily or weekly totals. For an aggregate cap, use the wallet float in [wallet-funding.md](wallet-funding.md).

---

## Turnkey setup

### Prerequisites

- A Turnkey account ([turnkey.com](https://www.turnkey.com))
- An OpenSea API key (`OPENSEA_API_KEY`)

### 1. Create an organization and a non-root, signer-only API user

1. Sign up at [app.turnkey.com](https://app.turnkey.com).
2. Create an organization. Its bootstrap user is a **root** user. Keep that account's credentials on your operator machine and never use it as the agent's API key.
3. Create a **second** API user (Users → Add User → API user). This is the agent's user.
4. Generate a fresh P-256 keypair on your operator machine and upload the public key to the new user. The private key is what goes in `TURNKEY_API_PRIVATE_KEY` on the agent host.
5. Create a policy that scopes the agent user to **only** `ACTIVITY_TYPE_SIGN_TRANSACTION_V2` (and `ACTIVITY_TYPE_SIGN_RAW_PAYLOAD_V2` if EIP-712 is needed) for the wallet addresses the agent should sign for. Turnkey denies everything else by default, so this is mostly an allowlist. Reference: [Turnkey policy examples](https://docs.turnkey.com/concepts/policies/examples).

> Turnkey root users **bypass the policy engine entirely**. A leaked root API key is as dangerous as a raw private key: it can sign anything, change any policy, create wallets and export keys. A non-root, policy-scoped agent key means even a fully compromised agent cannot escalate.

### 2. Create a wallet

Create a wallet in the Turnkey dashboard or through the API and note its Ethereum address. Confirm the step 1 policy lets the agent user sign for that address.

### 3. Set environment variables

```bash
export OPENSEA_API_KEY="your-opensea-api-key"
export TURNKEY_API_PUBLIC_KEY="your-turnkey-public-key"
export TURNKEY_API_PRIVATE_KEY="your-turnkey-private-key"  # hex-encoded P-256 private key
export TURNKEY_ORGANIZATION_ID="your-turnkey-org-id"
export TURNKEY_WALLET_ADDRESS="0xYourTurnkeyWalletAddress"
export TURNKEY_RPC_URL="https://mainnet.infura.io/v3/YOUR_KEY"  # required
# Optional:
# export TURNKEY_PRIVATE_KEY_ID="your-turnkey-private-key-id"  # if signing with a specific key
# export TURNKEY_API_BASE_URL="https://api.turnkey.com"  # override API base URL
```

> `TURNKEY_RPC_URL` is **required**. Turnkey only signs; it does not estimate gas or broadcast. The adapter uses `TURNKEY_RPC_URL` to populate gas fields (nonce, gasLimit, maxFeePerGas, maxPriorityFeePerGas) via `eth_getTransactionCount`, `eth_estimateGas`, and `eth_feeHistory`, then broadcasts the signed transaction via `eth_sendRawTransaction`. The RPC endpoint must match the target chain.

### 4. Verify

```bash
opensea wallet info
```

Confirm `isRootUser: false`. `isRootUser: true` means the agent runs as a root user and the hardening does nothing. Go back to step 1 and create a non-root user.

### 5. Fund

Send ETH to `TURNKEY_WALLET_ADDRESS`, then execute a swap:

```bash
opensea swaps execute \
  --wallet-provider turnkey \
  --from-chain base \
  --from-address 0x0000000000000000000000000000000000000000 \
  --to-chain base \
  --to-address 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  --quantity 0.001
```

Turnkey policies evaluate each activity on its own and cannot enforce daily or weekly totals. For an aggregate cap, use the wallet float in [wallet-funding.md](wallet-funding.md).

---

## Fireblocks setup

### Prerequisites

- A Fireblocks account ([fireblocks.com](https://www.fireblocks.com))
- An OpenSea API key (`OPENSEA_API_KEY`)

### 1. Create a Signer-role API user

1. In the Fireblocks console, go to **Settings → API Users**.
2. Create a new API user. **Set the role to `Signer`** (or `NCW_SIGNER` for non-custodial wallets). **Do not pick `Admin`, `Editor`, `Non-Signing Admin`, or any role with governance access.**
3. The role is fixed when the user is created and cannot be downgraded. To change it, delete the user and create a new one.
4. The new API user needs admin quorum approval (per workspace settings). Once approved, download the **API secret** (RSA private key PEM file) and copy the **API key**.

> Fireblocks has no API that returns an API user's role (no `/v1/users/me`), so `opensea wallet info` cannot check it and only prints a reminder. **You must confirm the key has the `Signer` role and nothing broader**, and confirm again after every rotation.
>
> TAP edits need quorum only when the agent's key is scoped correctly. An `Admin` key can edit TAP on its own; a `Signer` key cannot.

### 2. Create a vault account

Create a vault account with an ETH (or other EVM) wallet and note the **vault account ID**.

### 3. Set environment variables

```bash
export OPENSEA_API_KEY="your-opensea-api-key"
export FIREBLOCKS_API_KEY="your-fireblocks-api-key"
export FIREBLOCKS_API_SECRET="$(cat /path/to/fireblocks-secret.pem)"
export FIREBLOCKS_VAULT_ID="your-vault-account-id"
# Optional: override asset ID (default: auto-detected from chain)
# export FIREBLOCKS_ASSET_ID="ETH"
# Optional: override max polling attempts for async transactions (default: 60 = 120s)
# export FIREBLOCKS_MAX_POLL_ATTEMPTS="120"  # 240s for multi-party approval workflows
```

> Fireblocks signs asynchronously (MPC). The adapter polls for completion for up to 120 seconds by default (60 attempts, 2s apart). Raise `FIREBLOCKS_MAX_POLL_ATTEMPTS` for transactions that need multi-party approval.

### 4. Fund and verify

Fund the vault account from the Fireblocks console or an external transfer, then run a swap:

```bash
opensea swaps execute \
  --wallet-provider fireblocks \
  --from-chain base \
  --from-address 0x0000000000000000000000000000000000000000 \
  --to-chain base \
  --to-address 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  --quantity 0.001
```

---

## Bankr setup

Bankr is an HTTP signing service for agent wallets. The adapter calls Bankr's API to sign instead of holding a key locally.

### Prerequisites

- A Bankr account ([bankr.bot](https://bankr.bot))
- An OpenSea API key (`OPENSEA_API_KEY`)

### 1. Create an API key with scope flags

Sign up at [bankr.bot](https://bankr.bot) and create a key at [bankr.bot/api](https://bankr.bot/api). Set its scope flags now; they are not optional hardening:

- A monitoring-only agent gets `readOnly`. It can call read endpoints (prices, balances, analytics), and `/wallet/sign` and `/wallet/submit` return 403.
- A signing agent's key needs:
  - `allowedRecipients`, an allowlist of EVM (and, if needed, Solana) addresses the agent may send to. An empty list means no allowlist, which allows any destination.
  - `allowedIps`, the CIDR ranges of the agent's deploy environment, so the key works only from there.
  - A daily message limit, set on the key page.
  - `agentApiEnabled` off unless the agent needs Bankr's prompt API, and `walletApiEnabled` on only if it signs.

> Bankr has no API that returns a key's scope flags, so `opensea wallet info` cannot check them and only prints a reminder. **Set them correctly in the dashboard yourself, and confirm again after every key rotation.**

### 2. Set environment variables

```bash
export OPENSEA_API_KEY="your-opensea-api-key"
export BANKR_API_KEY="your-bankr-api-key"
```

### 3. Verify

```bash
opensea wallet info
```

This confirms the key reaches Bankr and prints the wallet address. The output always includes a reminder to check the scope flags at bankr.bot/api.

### 4. Run a swap

```bash
opensea swaps execute \
  --wallet-provider bankr \
  --from-chain base \
  --from-address 0x0000000000000000000000000000000000000000 \
  --to-chain base \
  --to-address 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  --quantity 0.001
```

### SDK usage

For swaps and trades, use `BankrAdapter.fromEnv()` (or `createWalletFromEnv()`) as in [SDK (TypeScript)](#sdk-typescript). For ERC-8257 tool payments, `@opensea/tool-sdk` wraps the same key in a viem account:

```typescript
import { createBankrAccount } from '@opensea/tool-sdk';

const account = await createBankrAccount(process.env.BANKR_API_KEY);
// Use with eip3009AuthenticatedFetch or paidAuthenticatedFetch
```

---

## Private key setup (not recommended)

> **Warning:** a raw private key has no spending limits, no destination allowlist and no human approval. Use a managed provider (Privy, Turnkey, Fireblocks) for anything beyond local development.

### Set environment variables

```bash
export OPENSEA_API_KEY="your-opensea-api-key"
export PRIVATE_KEY="<dev-private-key>"          # required: 64 hex characters, 0x prefix optional
export RPC_URL="https://mainnet.base.org"      # required to send: an RPC for the chain you transact on
# export WALLET_ADDRESS="0xYourWalletAddress"  # optional: skips address derivation; leave unset
```

`PRIVATE_KEY` is the only required variable. `RPC_URL` is needed only to send: without it, message and typed-data signing still work, and `sendTransaction` throws `RPC_URL is required for sending transactions`.

`WALLET_ADDRESS` is optional. When set, the adapter reports it as the wallet address and uses it for nonce and gas lookups instead of deriving the address from the key, and never checks that the two match. It does not change the sender: the transaction is signed with `PRIVATE_KEY` and always comes from the key's account. A mismatched value sends those lookups to the wrong account, and the result is unpredictable: the send can fail, sit pending behind a nonce gap, or go through and spend from the key's account while the adapter reports the other address. Leave it unset, or set it only to the address derived from `PRIVATE_KEY`.

### Run a swap

```bash
opensea swaps execute \
  --wallet-provider private-key \
  --from-chain base \
  --from-address 0x0000000000000000000000000000000000000000 \
  --to-chain base \
  --to-address 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913 \
  --quantity 0.001
```

The private-key adapter signs locally. It reads the nonce (`eth_getTransactionCount`, pending), estimates gas (`eth_estimateGas`, plus a 20% buffer) and reads fees (`eth_feeHistory`) from `RPC_URL`, builds an EIP-1559 transaction, signs it with `PRIVATE_KEY`, and broadcasts it with `eth_sendRawTransaction`. The RPC node never sees the key, so any standard public or provider RPC works (for example `https://mainnet.base.org`), as long as it serves the chain the transaction targets. The adapter does not check the RPC's chain ID against the transaction's.

---

## Using the wallet

### CLI

```bash
# Auto-detect provider from env vars (Privy checked first)
opensea swaps execute \
  --from-chain base \
  --from-address 0x0000000000000000000000000000000000000000 \
  --to-chain base \
  --to-address 0xb695559b26bb2c9703ef1935c37aeae9526bab07 \
  --quantity 0.02

# Explicitly specify provider
opensea swaps execute --wallet-provider turnkey ...
opensea swaps execute --wallet-provider fireblocks ...
opensea swaps execute --wallet-provider bankr ...
opensea swaps execute --wallet-provider private-key ...  # not recommended
```

### SDK (TypeScript)

```typescript
import {
  OpenSeaCLI,
  PrivyAdapter,
  TurnkeyAdapter,
  FireblocksAdapter,
  BankrAdapter,
  PrivateKeyAdapter,
  createWalletFromEnv,
} from '@opensea/cli';

const sdk = new OpenSeaCLI({ apiKey: process.env.OPENSEA_API_KEY });

// Auto-detect from env vars
const wallet = createWalletFromEnv();

// Or use a specific provider
// const wallet = PrivyAdapter.fromEnv();
// const wallet = TurnkeyAdapter.fromEnv();
// const wallet = FireblocksAdapter.fromEnv();
// const wallet = BankrAdapter.fromEnv();
// const wallet = PrivateKeyAdapter.fromEnv();  // not recommended

const results = await sdk.swaps.execute({
  fromChain: 'base',
  fromAddress: '0x0000000000000000000000000000000000000000',
  toChain: 'base',
  toAddress: '0xb695559b26bb2c9703ef1935c37aeae9526bab07',
  quantity: '0.02',
}, wallet);
```

### Shell script

```bash
./scripts/opensea-swap.sh 0xb695559b26bb2c9703ef1935c37aeae9526bab07 0.02 base
```

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `PRIVY_APP_ID environment variable is required` | Missing Privy env var | Set Privy credentials or use `--wallet-provider` to pick another provider |
| `Privy getAddress failed (401)` | Bad Privy credentials | Check `PRIVY_APP_ID` and `PRIVY_APP_SECRET` |
| `Privy getAddress failed (401): Invalid app ID or app secret` with creds confirmed correct in env | Usually `echo` instead of `printf %s` when building the header for curl. `echo` adds a trailing newline that breaks basic auth. | Use `opensea wallet info` instead, or build the header with `printf %s "$PRIVY_APP_ID:$PRIVY_APP_SECRET" \| base64`. |
| `Privy sendTransaction failed (403)` | Policy violation | Review wallet policies (see `wallet-policies.md`) |
| `TURNKEY_API_PUBLIC_KEY environment variable is required` | Missing Turnkey env var | Set Turnkey credentials |
| `Turnkey sendTransaction failed` | Turnkey API error | Check API keys and organization ID |
| `FIREBLOCKS_API_KEY environment variable is required` | Missing Fireblocks env var | Set Fireblocks credentials |
| `No Fireblocks asset ID mapping for chain` | Unsupported chain | Set `FIREBLOCKS_ASSET_ID` explicitly |
| `Fireblocks transaction ended with status: REJECTED` | Policy rejection | Review Fireblocks TAP rules |
| `BANKR_API_KEY environment variable is required` | Missing Bankr env var | Set `BANKR_API_KEY` |
| `Bankr getAddress failed (401)` | Bad Bankr API key | Verify the key at [bankr.bot](https://bankr.bot) |
| `PRIVATE_KEY environment variable is required` | Missing private key env var | Set `PRIVATE_KEY`, plus `RPC_URL` to send transactions |
| `RPC_URL is required for sending transactions` | Missing RPC URL (private-key adapter) | Set `RPC_URL` to an RPC for the target chain |
| `insufficient funds` | Wallet not funded | Send ETH to the wallet address |
