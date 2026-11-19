---
name: opensea
description: Query NFT and token data, trade NFTs on Seaport, swap ERC20 tokens via DEX aggregator, configure wallet signing providers, and build/register/gate AI agent tools on Base. Covers the full OpenSea developer surface across CLI, MCP server, shell scripts, and SDK. Pick the right sub-skill using the routing table below, then read that sub-skill's SKILL.md for operational detail.
homepage: https://github.com/ProjectOpenSea/opensea-skill
repository: https://github.com/ProjectOpenSea/opensea-skill
license: MIT
env:
  OPENSEA_API_KEY:
    description: API key for all OpenSea services. The SDK and MCP server need it set; the CLI and scripts fall back to the key cached in ~/.opensea/api_key
    required: true
    obtain: https://docs.opensea.io/reference/api-keys#instant-api-key-for-agents
dependencies:
  - node >= 18.0.0
  - curl
  - jq (recommended)
---

# OpenSea (router)

Entry point for OpenSea agent skills. Pick the sub-skill based on task, then read its `SKILL.md`:

| Task | Sub-skill |
|---|---|
| Query NFT/token data, search, drops, events | [`opensea-api/SKILL.md`](opensea-api/SKILL.md) |
| Buy/sell NFTs on Seaport, sweeps, cross-chain | [`opensea-marketplace/SKILL.md`](opensea-marketplace/SKILL.md) |
| Swap ERC20 tokens via DEX aggregator | [`opensea-swaps/SKILL.md`](opensea-swaps/SKILL.md) |
| Configure wallet signing (Privy/Turnkey/Fireblocks/Bankr) | [`opensea-wallet/SKILL.md`](opensea-wallet/SKILL.md) |
| Build/register/gate AI agent tools (ERC-8257) | [`opensea-tool-sdk/SKILL.md`](opensea-tool-sdk/SKILL.md) |
| Authenticate a wallet for scoped REST or MCP | [`opensea-api/SKILL.md`](opensea-api/SKILL.md) |
| Read what a store says a purchase earns (Open Bounty) | [`opensea-api/references/bounty.md`](opensea-api/references/bounty.md) |

Always read the sub-skill `SKILL.md` before executing. This router intentionally has no operational detail.

Wallet setup comes before any write. Token balances and other reads are `opensea-api`.
