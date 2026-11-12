# OpenSea Skills

[Agent Skills](https://agentskills.io/specification) for [OpenSea](https://opensea.io/): query NFT and token data, trade NFTs on Seaport, swap ERC20 tokens, and build AI agent tools with onchain gating.

## Installation

Each method installs the router `SKILL.md` and all five skills:

```bash
# Installs the router and all five skills (recommended)
npx skills add ProjectOpenSea/opensea-skill --yes

# ClawHub (single slug, all skills bundled)
clawhub install opensea-marketplace

# Manual (Claude Code / Cursor / Codex)
git clone https://github.com/ProjectOpenSea/opensea-skill.git ~/.claude/skills/opensea
```

The agent reads the root `SKILL.md` first, and it sends the agent to the right skill for the task.

## Choosing a skill

```
Want to use OpenSea?
├── Query NFT/token data, search, collection stats ──────── opensea-api
├── Buy/sell NFTs (listings, offers, fulfillment) ───────── opensea-marketplace
├── Swap ERC20 tokens (DEX aggregator) ──────────────────── opensea-swaps
├── Set up wallet signing for transactions ──────────────── opensea-wallet
└── Build/register/gate AI agent tools (ERC-8257) ───────── opensea-tool-sdk
```

Cases that are easy to send to the wrong skill:

| Scenario | Skill |
|---|---|
| Authenticate an agent for wallet-scoped REST or MCP | `opensea-api` |
| Browse and mint NFT drops | `opensea-api` |
| Stream real-time marketplace events (WebSocket) | `opensea-api` |
| Check token balances for a wallet | `opensea-api` |
| Cross-chain NFT purchase (pay from a different chain) | `opensea-marketplace` |
| Sweep multiple listings in one transaction | `opensea-marketplace` |
| Configure wallet signing policies (caps, allowlists) | `opensea-wallet` |
| Gate a tool with NFT ownership or x402 payments | `opensea-tool-sdk` |

## Skills

| Skill | What it does | Needs |
|---|---|---|
| [`opensea-api`](opensea-api/SKILL.md) | Queries collections, NFTs, tokens, search, drops, events, and accounts through the OpenSea CLI, SDK, MCP server, or shell scripts. Also covers wallet-scoped operations. | `OPENSEA_API_KEY` |
| [`opensea-marketplace`](opensea-marketplace/SKILL.md) | Buys and sells NFTs on Seaport: listings, offers, fulfillment, cross-chain purchases, and sweeps. | `OPENSEA_API_KEY` and wallet provider credentials |
| [`opensea-swaps`](opensea-swaps/SKILL.md) | Quotes and executes ERC20 swaps through OpenSea's DEX aggregator, and checks balances. | `OPENSEA_API_KEY`, plus wallet provider credentials to execute |
| [`opensea-wallet`](opensea-wallet/SKILL.md) | Sets up signing through Privy, Turnkey, Fireblocks, Bankr, or a local private key. | Provider credentials |
| [`opensea-tool-sdk`](opensea-tool-sdk/SKILL.md) | Builds, registers, and gates AI-callable tool endpoints with the OpenSea Tool Registry (ERC-8257) on Base, including x402 pay-per-call and NFT-gated access. | Wallet credentials for onchain registration |

Get an API key at [opensea.io/settings/developer](https://opensea.io/settings/developer), or request one through the API (the `opensea-api` skill explains how).

## Links

- [Developer docs](https://docs.opensea.io/)
- [OpenSea CLI](https://github.com/ProjectOpenSea/opensea-cli)
- [OpenSea MCP Server](https://mcp.opensea.io)
- [Get an API key](https://opensea.io/settings/developer)

## Publishing (maintainer notes)

The root `SKILL.md` is a thin router, so one install through `npx skills add` or `clawhub install` delivers all five skills.

### ClawHub

`.github/workflows/clawhub-publish.yml` publishes the bundle on each release under one slug, `opensea-marketplace` (owner `opensea`). The slug predates the router; we kept it so existing installs keep updating. Do not publish five separate slugs. The installed layout:

```
opensea/
├── SKILL.md                       # router; agent registers this
├── opensea-api/SKILL.md
├── opensea-marketplace/SKILL.md
├── opensea-swaps/SKILL.md
├── opensea-wallet/SKILL.md
└── opensea-tool-sdk/SKILL.md
```

### `npx skills add` behavior

The vercel-labs/skills CLI discovers both a root `SKILL.md` and `skills/` subdirectories. With the router at the root, `npx skills add ProjectOpenSea/opensea-skill` installs the router and every skill as one directory tree. Check with `--dry-run` after any structural change.

## Contributing

Read-only mirror of a private monorepo, updated on each release. Pull requests are welcome, and we bring accepted changes into the monorepo.

## Security

Found a vulnerability? Report it through OpenSea's Bugcrowd program at https://bugcrowd.com/engagements/opensea rather than opening a public issue. See [SECURITY.md](SECURITY.md).

## License

MIT
