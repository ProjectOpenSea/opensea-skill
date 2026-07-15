# Authentication Reference

OpenSea uses two credentials:

| Credential | Header | What it identifies |
|---|---|---|
| API key | `X-API-KEY: <key>` | Your application |
| Scoped wallet token | `Authorization: Bearer <token>` | A wallet and its allowed actions |

Wallet-specific endpoints need both headers. Request only the scopes required for the task.

## Fastest path for agents

Set the API key and private key in the environment, then let the CLI handle SIWE, scoped-token creation, and exchange:

```bash
export OPENSEA_API_KEY="..."
export OPENSEA_PRIVATE_KEY="..."

opensea auth login --scopes read:eligibility,write:wallets
opensea auth status
```

The CLI stores credentials in `~/.opensea/auth.json` with mode `0600`. The private key is used locally to sign the SIWE message and is not stored there.

Refresh the short-lived JWT by exchanging the stored scoped token again:

```bash
opensea auth refresh
```

Revoke the scoped token and remove the local credential when the task is complete:

```bash
opensea auth revoke
```

## Discover the API after login

The live OpenAPI document is the simplest way for an agent to discover request and response shapes:

```text
https://api.opensea.io/api/v2/openapi.json
```

Use the operation's declared scope and send both credentials:

```bash
curl "https://api.opensea.io/api/v2/drops/example/eligibility" \
  -H "X-API-KEY: $OPENSEA_API_KEY" \
  -H "Authorization: Bearer $OPENSEA_AUTH_TOKEN"
```

## Manual token flow

Use this flow when the CLI is unavailable:

1. `POST /api/v2/auth/siwe/nonce` to obtain a single-use nonce.
2. Build and sign the exact SIWE message locally with the wallet private key.
3. `POST /api/v2/auth/siwe/verify` with the parsed message, signature, and `chainArch`.
4. Keep the session cookies returned by verification.
5. `POST /api/v2/auth/tokens` with those cookies, a label, the minimal scope list, and `expiresInDays`.
6. `POST /api/v2/auth/tokens/exchange` with the scoped token and `subjectTokenType: "ACCESS_TOKEN"`.
7. Use the returned `accessToken` as the Bearer token.

The scoped token is the durable credential. Keep it secret and use it to mint replacement short-lived JWTs. Revoke it with `DELETE /api/v2/auth/tokens/{id}` when finished.

## Wallet linking

Wallet linking uses the same API nonce endpoint. The authenticated account signs a fresh SIWX message with the wallet being linked:

```bash
export OPENSEA_AUTH_TOKEN="..."
export OPENSEA_API_KEY="..."
export OPENSEA_PRIVATE_KEY="..." # private key for the wallet being linked

opensea auth link-wallet --chain-arch EVM --chain-id 1
```

The Bearer token needs `write:wallets`. Unlinking also needs `write:wallets`; use the wallet DELETE operation described by the live OpenAPI document.

## Scopes

| Scope | Description |
|---|---|
| `read:eligibility` | Check drop eligibility for the authenticated wallet |
| `read:favorites` | View favorites and watchlists for the authenticated account |
| `write:favorites` | Add and remove favorites and watchlist entries |
| `write:orders` | Cancel orders for the authenticated account |
| `write:drops` | Manage Creator Studio drops |
| `write:collections` | Modify collection metadata, visibility, and images |
| `write:profile` | Modify profile settings, images, username, and shelves |
| `write:wallets` | Link and unlink wallets |

Run `opensea auth scopes` for the generated current scope metadata.

## Agent rules

- Never print, log, or send a private key to an API.
- Prefer the CLI login flow over hand-building SIWE requests.
- Request the smallest useful scope set.
- Treat both the scoped token and exchanged JWT as secrets.
- A `401` usually means the JWT is missing, invalid, or expired. Refresh it once.
- A `403` usually means the token lacks the required scope. Mint a new scoped token rather than retrying.
- Revoke task-specific credentials when the task is complete.
