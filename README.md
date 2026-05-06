# OpenSea Skills

Agent Skills for interacting with [OpenSea](https://opensea.io/): query NFT and token data, trade on the Seaport marketplace, swap ERC20 tokens, and build AI agent tools with onchain gating.

This repository follows the [Agent Skills specification](https://agentskills.io/specification).

## Decision tree

Pick the right skill in one question:

```
Want to use OpenSea?
├── Query NFT/token data, search, collection stats ──────── opensea-api
├── Buy/sell NFTs (listings, offers, fulfillment) ───────── opensea-marketplace
├── Swap ERC20 tokens (DEX aggregator) ──────────────────── opensea-swaps
├── Set up wallet signing for transactions ──────────────── opensea-wallet
└── Build/register/gate AI agent tools (proposed ERC) ────── opensea-tool-sdk
```

## Skills

### `opensea-api`

Query NFT and token data via the OpenSea CLI, MCP server, or shell scripts. Collections, NFTs, tokens, search, drops, events, and account lookups.

- **Auth**: `OPENSEA_API_KEY` environment variable
- **Setup**: Get a key at [opensea.io/settings/developer](https://opensea.io/settings/developer) or instantly via API
- **Entry point**: [`opensea-api/SKILL.md`](opensea-api/SKILL.md)

### `opensea-marketplace`

Buy and sell NFTs on the Seaport protocol. Create listings and offers, fulfill orders, cross-chain purchases, and sweep multiple listings.

- **Auth**: `OPENSEA_API_KEY` + wallet provider credentials
- **Entry point**: [`opensea-marketplace/SKILL.md`](opensea-marketplace/SKILL.md)

### `opensea-swaps`

Swap ERC20 tokens across supported chains via OpenSea's DEX aggregator. Get quotes, check balances, and execute swaps.

- **Auth**: `OPENSEA_API_KEY` + wallet provider credentials (for execution)
- **Entry point**: [`opensea-swaps/SKILL.md`](opensea-swaps/SKILL.md)

### `opensea-wallet`

Set up and configure wallet signing providers for OpenSea transactions. Supports Privy, Turnkey, Fireblocks, Bankr, and local private keys.

- **Entry point**: [`opensea-wallet/SKILL.md`](opensea-wallet/SKILL.md)

### `opensea-tool-sdk`

Build, register, and gate AI-callable tool endpoints using the OpenSea Tool Registry (proposed ERC) on Base. Supports x402 pay-per-call and NFT-gated access.

- **Auth**: Wallet credentials for onchain registration
- **Entry point**: [`opensea-tool-sdk/SKILL.md`](opensea-tool-sdk/SKILL.md)

## Ecosystem / partner skills

Skills contributed by ecosystem partners. See [`ecosystem/CONTRIBUTING.md`](ecosystem/CONTRIBUTING.md) for conventions and how to add a new partner skill.

No partner skills have been added yet. When partners contribute skills through the normal PR flow, they will appear here.

## Less-obvious routing

The tree above covers the common cases. These edge cases catch the easy-to-misroute ones:

| Scenario | Skill |
|---|---|
| Browse and mint NFT drops | `opensea-api` |
| Stream real-time marketplace events (WebSocket) | `opensea-api` |
| Cross-chain NFT purchase (pay from a different chain) | `opensea-marketplace` |
| Sweep multiple listings in one transaction | `opensea-marketplace` |
| Check token balances for a wallet | `opensea-swaps` |
| Configure wallet signing policies (caps, allowlists) | `opensea-wallet` |
| Gate a tool with NFT ownership or x402 payments | `opensea-tool-sdk` |

## Installation

All three paths install the router `SKILL.md` plus all five sub-skills:

```bash
# Auto-installs all five skills (recommended)
npx skills add ProjectOpenSea/opensea-skill --yes

# ClawHub (single slug, all skills bundled)
clawhub install opensea

# Manual (Claude Code / Cursor / Codex)
git clone https://github.com/ProjectOpenSea/opensea-skill.git ~/.claude/skills/opensea
```

After install, the consuming agent reads `SKILL.md` (the router), which directs it to the relevant sub-skill based on the task.

## Official Links

- [Developer docs](https://docs.opensea.io/)
- [OpenSea CLI](https://github.com/ProjectOpenSea/opensea-cli)
- [OpenSea MCP Server](https://mcp.opensea.io)
- [Get an API key](https://opensea.io/settings/developer)

## Specification

These skills follow the [Agent Skills specification](https://agentskills.io/specification).

## Publishing (maintainer notes)

### Repo layout

The root `SKILL.md` is a thin router that directs agents to the correct sub-skill. This ensures a single install (`npx skills add` or `clawhub install`) delivers all five skills with intelligent routing.

### ClawHub

Register one slug (`opensea`) and publish via `clawhub skill publish .`. The installed layout:

```
opensea/
├── SKILL.md                       # router; agent registers this
├── opensea-api/SKILL.md
├── opensea-marketplace/SKILL.md
├── opensea-swaps/SKILL.md
├── opensea-wallet/SKILL.md
├── opensea-tool-sdk/SKILL.md
└── ecosystem/...
```

Do **not** publish five separate ClawHub slugs.

### `npx skills add` behavior

The vercel-labs/skills CLI discovers both root `SKILL.md` and `skills/` subdirectories. With the router at root, `npx skills add ProjectOpenSea/opensea-skill` installs the router plus all sub-skills as a single directory tree. Verify this with `--dry-run` after any structural changes.

## License

MIT
