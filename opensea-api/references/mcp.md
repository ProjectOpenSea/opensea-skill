# OpenSea MCP server

Hosted at `https://mcp.opensea.io/mcp` (streamable HTTP).

```json
{
  "mcpServers": {
    "opensea": {
      "url": "https://mcp.opensea.io/mcp",
      "headers": { "X-API-KEY": "<OPENSEA_API_KEY>" }
    }
  }
}
```

- Without a key the server lists only `get_instant_api_key`. Call it, save the key as described in the skill's Setup section, then reconnect with the header.
- Wallet-scoped tools also need `Authorization: Bearer <wallet JWT>`, or an OAuth 2.1 client signed in through `https://auth.opensea.io`. See [authentication.md](authentication.md). Keep both values in the client's secret store, not committed config.
- Each tool publishes its own input schema. Read it from `tools/list` instead of guessing parameters.

## Tools

| Area | Tools |
|---|---|
| Search | `search` (all types), `search_collections`, `search_items`, `search_tokens`, `search_tools`, `fetch` (full entity by id) |
| Collections | `get_collections`, `get_collection_stats`, `get_collection_floor_prices`, `get_trending_collections`, `get_top_collections` |
| NFTs and activity | `get_items`, `get_activity` |
| Tokens | `get_tokens`, `get_trending_tokens`, `get_top_tokens`, `get_token_swap_quote` |
| Wallets and accounts | `get_profile`, `account_lookup`, `get_nft_balances`, `get_token_balances`, `get_account_collections` |
| Drops | `get_upcoming_drops`, `get_drop_details`, `get_mint_action`, `deploy_seadrop_contract`, `get_deploy_receipt` |
| Tool registry | `search_tools`, `get_tool` |
| Utility | `get_chains`, `get_instant_api_key` |

`get_collections`, `get_items` and `get_tokens` accept a free-text `query` that resolves to one canonical entity, with `disambiguation` set to `first_verified` (default), `first` or `error`. Use them for a single known entity and `search_*` to browse candidates.

Transaction tools (`get_mint_action`, `deploy_seadrop_contract`, `get_token_swap_quote`) return unsigned transaction data. Sign and submit it with a wallet from `opensea-wallet`.

## Wallet-scoped tools

The server takes the wallet from the verified JWT and enforces the scope. Never pass a wallet address in place of authentication.

| Scope | Tool |
|---|---|
| `read:eligibility` | `check_drop_eligibility` |
| `read:favorites` | `get_favorites` |
| `read:wallets` | `get_agent_relationships` |
| `write:favorites` | `manage_watchlist` |
| `write:orders` | `cancel_orders` |
| `write:drops` | `manage_drops` |
| `write:collections` | `manage_collections` |
| `write:profile` | `manage_profile` |
| `write:wallets` | `manage_wallets`, `manage_agent_account` |

Social graph (`read:social`, `write:social`) and saved tools (`read:tools`, `write:tools`) have no MCP tools. Use the CLI commands in [social-and-agents.md](social-and-agents.md).

`Wallet identity required` means the `Authorization` header is missing, holds an API key or PAT instead of a JWT, or the JWT expired. A scope error means log in again with that scope; an unchanged retry will fail the same way.
