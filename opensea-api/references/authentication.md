# Wallet authentication

Use wallet auth when an operation acts as a wallet. Start with the [public auth guide](https://docs.opensea.io/reference/auth), and take current paths, schemas and scopes from the [live OpenAPI document](https://api.opensea.io/api/v2/openapi.json).

## Credential model

| Credential | Purpose | Where it goes |
|---|---|---|
| API key | Application access and quota | `X-API-KEY` on REST and MCP requests |
| SIWE session | Create, list, rotate, or revoke PATs | Session cookies; managed by the CLI or SDK |
| Scoped personal access token (PAT) | Durable credential used only to mint JWTs | Token exchange only |
| Wallet JWT | Short-lived wallet identity and scopes | `Authorization: Bearer <JWT>` on REST and MCP requests |

Wallet-scoped REST and MCP calls need both the API key and the wallet JWT. Never send a PAT to either.

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

The private key signs locally and is never stored. The CLI keeps the session, PAT and JWT in `~/.opensea/auth.json` (mode `0600`), and `api request` sends the stored JWT. Run `opensea auth refresh` after the JWT expires and `opensea auth scopes` to list current scopes. `auth revoke` invalidates the current PAT and removes that wallet login; `auth clear` only deletes local state.

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

Keep the same `OpenSeaAuth` instance through cleanup: it holds the SIWE session needed to revoke the PAT. After `getValidToken()` refreshes the token, create a new `OpenSeaAPI` with the latest `accessToken`. `revoke()` takes the current JWT as a guard, revokes the PAT behind it, and clears the SDK's in-memory auth state.

## REST

Send the application key and a short-lived wallet JWT from your own SIWE or OAuth flow. The CLI does not export its stored JWT; with the CLI, use `opensea api request` instead.

```bash
curl "https://api.opensea.io/api/v2/account/0xYOUR_WALLET/favorites?limit=1" \
  -H "X-API-KEY: $OPENSEA_API_KEY" \
  -H "Authorization: Bearer $OPENSEA_WALLET_JWT"
```

Do not guess paths or scopes; read them from the live OpenAPI document. Without the CLI or SDK, follow the public auth guide for the raw SIWE session, PAT creation and token exchange. PAT management is session-only; a Bearer JWT cannot create, list, rotate, or revoke PATs.

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

Keep the real values in the client's secret store, not in committed configuration. The CLI does not export its stored JWT, by design: use an OAuth-capable MCP client, or get a JWT with `OpenSeaAuth` and pass it to an in-process client. Reconnect after replacing an expired JWT. The server takes the wallet from the verified JWT; never pass a wallet address in place of authentication.

## Recovery and safety

- `401`: the API key or JWT is missing, invalid, or expired. Check the response, refresh the JWT once, and retry once.
- If PAT exchange or session refresh fails because the credential expired or was revoked, sign in with SIWE again instead of looping.
- `403`: the JWT lacks the required scope. Sign in again with that scope; an unchanged retry fails the same way.
- A read and its writes do not always share a scope. Agent relationships are the common case: every write takes `write:wallets`, but listing your own relationships takes `read:wallets`. A client that drives the whole handshake needs both, so sign in with `--scopes read:wallets,write:wallets`.
- `429`: respect `Retry-After` and back off.
- Load secrets from environment variables or a secret manager, not by typing them into shell history. Never print or transmit private keys, PATs, JWTs, cookies, signatures, or authorization headers.
- Request the smallest scope set that works, and revoke task-specific PATs when done.
