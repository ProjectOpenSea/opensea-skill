# Policy administration (user-only, off-agent)

These are the recipes for changing wallet policies, signers and roles on Privy, Turnkey, Fireblocks and Bankr. The file sits outside `opensea-wallet/`, so a loader that mounts only that skill folder does not load it, but an install that copies the whole repository does. What protects the wallet is the credential split described in [`opensea-wallet/SKILL.md`](../opensea-wallet/SKILL.md), not where this file lives. Agents must never build or run these requests. If asked, decline and point the user to this file.

Run these from a **trusted operator machine**: your laptop, a vault host, or a dedicated admin box. Never put the credentials below in the agent's environment. Administrative credentials live apart so that a leaked agent env cannot rewrite the agent's spending cap.

> Do not automate any of these from the agent. The point of the hardening is that the agent **cannot** run them, and any wrapper that lets it reopens the gap.

## Privy

### Apply or update a wallet policy

Update a wallet's policy with `PATCH /v1/wallets/{wallet_id}` and `policy_ids` in the body.

**If the wallet has an `owner_id`** (recommended; see "Register an authorization key" in [wallet-setup.md](../opensea-wallet/references/wallet-setup.md)), the request needs an authorization signature from the owner's key quorum. Build it with `@privy-io/node`:

```ts
// scripts/update-privy-policy.ts: RUN FROM A TRUSTED MACHINE
import { generateAuthorizationSignature } from "@privy-io/node"

const appId = process.env.PRIVY_APP_ID!
const appSecret = process.env.PRIVY_APP_SECRET!
const walletId = process.env.PRIVY_WALLET_ID!
// Base64 PKCS8 P-256 owner key. NEVER put this on an agent host.
const ownerKey = process.env.PRIVY_OWNER_PRIVATE_KEY!

const policyIds = ["pol_abc123"] // policy you authored separately
const url = `https://api.privy.io/v1/wallets/${walletId}`
const body = { policy_ids: policyIds }

const signature = generateAuthorizationSignature({
  authorizationPrivateKey: ownerKey,
  input: {
    version: 1,
    method: "PATCH",
    url,
    body,
    headers: { "privy-app-id": appId },
  },
})

const auth = Buffer.from(`${appId}:${appSecret}`).toString("base64")
const res = await fetch(url, {
  method: "PATCH",
  headers: {
    Authorization: `Basic ${auth}`,
    "privy-app-id": appId,
    "privy-authorization-signature": signature,
    "Content-Type": "application/json",
  },
  body: JSON.stringify(body),
})
console.log(res.status, await res.text())
```

**If the wallet has no `owner_id`** (unhardened; `opensea wallet info` warns about it), basic auth alone is enough for the `PATCH`. That is the gap the owner key closes. If your wallet is unhardened, register an owner key first. A policy applied without one can be swapped out by anyone holding the app credentials.

### Author a policy

Create it with `POST /v1/policies` and the policy body. Templates and the field reference are in [wallet-policies.md](../opensea-wallet/references/wallet-policies.md); the current schema is in the [Privy docs](https://docs.privy.io/controls/policies/create-a-policy).

### Register an authorization key (owner) on an existing wallet

Generate a P-256 keypair on your operator machine, register the public key as the wallet's `owner`, and store the private key in your password manager or vault. Step-by-step instructions are in step 3 of the Privy section of [wallet-setup.md](../opensea-wallet/references/wallet-setup.md).

## Turnkey

### Create a non-root, signer-only API user

From a Turnkey dashboard session as a root user:

1. **Create an API user** (Users → Add User → API user). Generate a new P-256 keypair on your operator machine, upload the public key, and save the private key in your password manager.
2. **Create a policy** that limits the new user to `ACTIVITY_TYPE_SIGN_TRANSACTION_V2` (and `ACTIVITY_TYPE_SIGN_RAW_PAYLOAD_V2` if EIP-712 is needed) for the wallet addresses the agent should sign for. Default-deny on everything else. Reference: [Turnkey policy examples](https://docs.turnkey.com/concepts/policies/examples).
3. **Set the agent's `TURNKEY_API_PUBLIC_KEY` and `TURNKEY_API_PRIVATE_KEY` to the new non-root key.** Check with `opensea wallet info`: `isRootUser` should be `false`.

### Update a policy

`CreatePolicy` and `UpdatePolicy` are Turnkey activities signed by a root user, or by a user whose policy allows policy-engine activity. Run them from the Turnkey dashboard or with `@turnkey/sdk-server` on your operator machine. Never expose them through the agent's adapter.

## Fireblocks

### Use a Signer-role API key, not Admin

From the Fireblocks Console (Settings → API Users):

1. Create a new API user. **Set the role to `Signer`** (or `NCW_SIGNER` for non-custodial wallets). Do not pick `Admin`, `Editor`, `Non-Signing Admin`, or any role with governance access.
2. The role is fixed when the user is created and cannot be downgraded. To change it, delete the user and create a new one.
3. The new API user needs admin quorum approval (per workspace settings). Once approved, copy the API key and RSA secret to the agent's env.

### Modify the Transaction Authorization Policy

Change the TAP in the Fireblocks Console, never through the agent. It needs admin quorum approval. **Never try to edit the TAP with an API key the agent signs with.** Fireblocks rejects the edit when the key has the `Signer` role, and that protection holds only if the key was scoped that way.

Reference: [Fireblocks TAP overview](https://developers.fireblocks.com/docs/set-transaction-authorization-policy).

## Bankr

Bankr key scope flags (`readOnly`, `walletApiEnabled`, `agentApiEnabled`, `allowedRecipients`, `allowedIps`, daily limits) are set at [bankr.bot/api](https://bankr.bot/api). By design, no API can change them. To re-scope a key:

1. Log in to bankr.bot/api on your operator machine.
2. Edit the key's flags. For a key the agent signs with, set `allowedRecipients` to the EVM and Solana addresses the agent may send to, `allowedIps` to your deploy CIDR, and a daily message limit.
3. A running agent keeps its cached credentials until it restarts. Rotate the key if the change must take effect immediately.

## After any change

Run `opensea wallet info` on the agent host. It should print no warnings, or only the standing reminder to check scope in the console for Fireblocks and Bankr. A remaining warning means the change did not apply; check the dashboard again.
