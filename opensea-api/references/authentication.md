# Wallet Authentication

Use wallet auth when an operation must act as a wallet. Start with the [public auth guide](https://docs.opensea.io/reference/auth); use the [live OpenAPI document](https://api.opensea.io/api/v2/openapi.json) for current paths, schemas, and scopes.

## Credential model

| Credential | Purpose | Where it goes |
|---|---|---|
| API key | Application access and quota | `X-API-KEY` on REST and MCP requests |
| SIWE session | Create, list, rotate, or revoke PATs | Session cookies; managed by the CLI or SDK |
| Scoped personal access token (PAT) | Durable credential used only to mint JWTs | Token exchange only |
| Wallet JWT | Short-lived wallet identity and scopes | `Authorization: Bearer <JWT>` on REST and MCP requests |

Wallet-scoped REST and MCP calls need both the API key and wallet JWT. Never send a PAT to either surface.

## CLI: wallet-scoped REST

```bash
export OPENSEA_API_KEY="..."
export OPENSEA_PRIVATE_KEY="..."

# Private-key login requires an explicit, least-privilege scope list.
opensea login --private-key --scopes read:favorites
WALLET=$(opensea --format json whoami | jq -r '.address')
opensea api request GET "/api/v2/account/$WALLET/favorites" --params '{"limit":1}'
opensea auth revoke
```

The private key signs locally and is not stored. The CLI stores the session, PAT, and JWT in `~/.opensea/auth.json` with mode `0600`; `api request` automatically sends the stored JWT. Use `opensea auth refresh` after the JWT expires and `opensea auth scopes` to discover current scopes. `auth revoke` invalidates the current PAT and removes that wallet login. `auth clear` only deletes local state.

## SDK: REST and in-process MCP

```typescript
import { Wallet } from "ethers"
import { OpenSeaAPI, OpenSeaAuth } from "@opensea/sdk"

const signer = new Wallet(process.env.OPENSEA_PRIVATE_KEY!)
const auth = new OpenSeaAuth()
let token = await auth.authenticate(signer, { scopes: ["read:favorites"] })

try {
  token = await auth.getValidToken()
  const api = new OpenSeaAPI({
    apiKey: process.env.OPENSEA_API_KEY,
    authToken: token.accessToken,
  })
  await api.walletAuth.getFavorites(await signer.getAddress(), { limit: 1 })
} finally {
  await auth.revoke(token.accessToken)
}
```

Keep the same `OpenSeaAuth` instance through cleanup: it holds the SIWE session required to revoke the PAT. Create a new `OpenSeaAPI` with the latest `accessToken` after `getValidToken()` refreshes it. `revoke()` accepts the current JWT as a guard, revokes its backing PAT, and clears the SDK's in-memory auth state.

## REST

Send the application key and short-lived wallet JWT:

```bash
curl "https://api.opensea.io/api/v2/account/0xYOUR_WALLET/favorites?limit=1" \
  -H "X-API-KEY: $OPENSEA_API_KEY" \
  -H "Authorization: Bearer $OPENSEA_WALLET_JWT"
```

Do not guess paths or scopes. Read them from the live OpenAPI document. If the CLI and SDK are unavailable, follow the public auth guide for the raw SIWE session, PAT creation, and token-exchange flow. PAT management is session-only; a Bearer JWT cannot create, list, rotate, or revoke PATs.

## MCP

Every data tool needs the application key. Wallet-scoped tools also need the wallet JWT:

```json
{
  "mcpServers": {
    "opensea": {
      "url": "https://mcp.opensea.io/mcp",
      "headers": {
        "X-API-KEY": "<OPENSEA_API_KEY>",
        "Authorization": "Bearer <SHORT_LIVED_WALLET_JWT>"
      }
    }
  }
}
```

Keep the resolved values in the client's secret store, not committed configuration. The CLI intentionally does not print stored tokens; use an OAuth-capable MCP client or obtain a JWT with `OpenSeaAuth` and pass it to an in-process client. Reconnect after replacing an expired JWT. The server derives the wallet from the verified JWT; do not pass an arbitrary wallet as a substitute for authentication.

## Recovery and safety

- `401`: the API key or JWT is missing, invalid, or expired. Check the response, refresh the JWT once, and retry once.
- If PAT exchange or session refresh fails because the credential expired or was revoked, run SIWE authentication again instead of looping.
- `403`: the JWT lacks the required scope. Sign in again with that scope; unchanged retries will not help.
- A read and its matching writes do not always share one scope. Agent relationships are the case to watch: every write takes `write:wallets`, but listing your own relationships takes `read:wallets`. A client that drives the whole handshake needs both, so sign in with `--scopes read:wallets,write:wallets` rather than assuming the write scope covers the read.
- `429`: respect `Retry-After` and back off.
- Load secrets from environment variables or a secret manager instead of typing them into shell history. Never print or transmit private keys, PATs, JWTs, cookies, signatures, or authorization headers.
- Request the smallest useful scope set and revoke task-specific PATs when finished.
