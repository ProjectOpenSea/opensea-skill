# @opensea/skill

## 2.15.2

### Patch Changes

- 6f7fd26: `opensea-tool-sdk`: document x402 v2 and GET tool calling. SKILL.md and the references now cover the `pay --method` flag, the GET auto-fallback, and the version-correct payment header (`X-PAYMENT` for v1, `PAYMENT-SIGNATURE` for v2).

## 2.15.1

### Patch Changes

- ef12e56: `opensea-tool-sdk`: correct the manifest-hashing guidance. The manifest is hashed as served (ERC-8257 §2, the full JCS document including namespaced extension fields), not the schema-stripped subset. Documents the open schema and the bare-extension-key warning.

## 2.15.0

### Minor Changes

- ef89be8: `opensea-api`: add `references/authentication.md` covering SIWE wallet authentication — getting a token via the SDK (`OpenSeaAuth`) or the CLI `auth` commands (login, status, refresh, revoke, tokens, scopes), available scopes, and manual cURL flows. Document auth scopes in `references/rest-api.md`.
- d4dff85: `opensea-tool-sdk`: update SKILL.md and `references/predicate-gating.md` for the unified 402 + X-Payment flow and the new `paidPredicateGate` (single 402 round trip for combined identity + payment). Remove the `--auth eip3009` flag from `pay` command docs.

## 2.14.0

### Minor Changes

- Remove the ecosystem partner skill suite. Deletes the `ecosystem/` directory (the Alchemy `alchemy-agentic-gateway`, `alchemy-api`, `alchemy-cli`, `alchemy-mcp` skills plus the template, `CONTRIBUTING.md`, and `sync.config.json`), the references-only sync bot (`scripts/sync-ecosystem.ts` + `.github/workflows/sync-ecosystem.yml` and the root `sync-ecosystem` package script), and all ecosystem references from `SKILL.md`, `README.md`, and `AGENTS.md`.

## 2.13.0

### Minor Changes

- 1185694: `opensea-api`: document the `opensea tools` CLI commands (`list`, `search`, `get`), the `client.tools` SDK methods, and the `search_tools` / `get_tool` / `get_wallet_tools` MCP tools for the `[Beta]` tool registry (ERC-8257) in SKILL.md.

## 2.12.0

### Minor Changes

- 61682fb: `opensea-tool-sdk` and `opensea-api`: document the list tools endpoint (`GET /api/v2/tools`, with `sort_by` and `type` filter) in the tool discovery sections and `references/rest-api.md`.

## 2.11.0

### Minor Changes

- af0d079: `opensea-tool-sdk`: document tool discovery endpoints (registry lookup and listing) in SKILL.md.
- f45c170: `opensea-api`: document the tools search endpoint.
- 73170a2: `opensea-tool-sdk`: migrate SIWE references to EIP-3009 across SKILL.md and `references/predicate-gating.md`, reflecting the predicate-gate and CLI auth switch.
- 1ce2300: `opensea-tool-sdk`: document `ERC20BalancePredicate` for token-balance-gated tool access, the `--erc20-gate` register helper, and canonical predicate addresses in `references/known-predicates.md`.
- f1636af: `opensea-tool-sdk`: document tool registry deployment on Shape and Abstract, plus Shape/Abstract chain support in the CLI.

## 2.10.0

### Minor Changes

- 8fa9fb5: `opensea-api`: add `tokens/opensea-token-holders.sh` and `tokens/opensea-token-liquidity-pools.sh` shell scripts wrapping the new `GET /api/v2/chain/{chain}/token/{address}/holders` and `/liquidity-pools` endpoints. Update `SKILL.md` (Investigation Scripts) and `references/rest-api.md` (Tokens) accordingly.

## 2.9.0

### Minor Changes

- 27a89da: `opensea-tool-sdk`: document canonical `SubscriptionPredicate` deployment on Ethereum mainnet + Base (`0xCBe0cd9B1d99d95Baa9c58f2767246C52e461f25`). `SubscriptionPredicateClient` constructor no longer requires `predicateAddress` — it defaults to the canonical multi-tenant deployment, matching the ERC721 / ERC1155 owner predicates. Self-hosted deployments are still supported by passing `predicateAddress` explicitly.
- 427e093: `opensea-tool-sdk`: update SKILL.md and `references/known-predicates.md` for the v0.2 registry redeploy on Ethereum mainnet + Base. New canonical addresses for `ToolRegistry`, `ERC721OwnerPredicate`, and `ERC1155OwnerPredicate`.
- 773adcd: `opensea-api`: document 3 new opensea-mcp tools.

## 2.8.0

### Minor Changes

- 0031a87: Add **Alchemy ecosystem skill suite** under `ecosystem/` — four curated, non-overlapping partner skills (`alchemy-agentic-gateway`, `alchemy-api`, `alchemy-cli`, `alchemy-mcp`) sourced from `alchemyplatform/skills`. Each routes back to first-party OpenSea skills for NFT marketplace, listings/offers, ERC20 swaps, wallet setup, and tool-sdk needs. Provenance is stamped per skill in `.upstream.json`.

  Adds a **references-only sync action** (`scripts/sync-ecosystem.ts` + `.github/workflows/sync-ecosystem.yml` in the monorepo) that runs Mondays 06:00 UTC. The bot clones each declared upstream, mirrors only `references/` and `rules/` (default + per-skill `dirs` override), applies declared string rewrites, refreshes `.upstream.json`, and opens a PR for human review. `SKILL.md`, `LICENSE.txt`, and `agents/` stay human-curated.

  Security hardening on the bot: file-type allowlist (`.md` only), diff-aware content scanner that flags newly-introduced ETH addresses, prompt-injection phrases, base64 blobs, and PEM private-key markers (rendered into the PR body), optional `pinned_sha` to disable HEAD tracking, and a pre-sync check that aborts loud (rather than wiping local content) if any declared upstream `from` path goes missing.

  Documents the bot in `ecosystem/CONTRIBUTING.md` so future partners know how to opt their `references/` directory in.

## 2.7.0

### Minor Changes

- _Phase 2 PR_: Add 22 new shell scripts wrapping the api-types 0.4.0 endpoints (Tokens/NFTs/Collections batch lookups, Listings actions, Drops deploy + receipt, Assets transfer, Collection offer aggregates / holders / floor prices, Token price history / OHLCV / activity, NFT owners / analytics, Account portfolio / portfolio history / offers / offers_received / listings / favorites / collections).
- **Breaking** — Scripts under `opensea-api/scripts/` reorganized into per-domain subdirectories (`accounts/`, `auth/`, `collections/`, `nfts/`, `tokens/`, `listings/`, `offers/`, `orders/`, `events/`, `drops/`, `assets/`, `stream/`). The shared utilities `opensea-get.sh`, `opensea-post.sh`, and `_response-markers.sh` remain at the scripts root. Any agent prompt or doc that hardcoded a flat path (e.g. `opensea-collection.sh`) needs to update to the new path (`collections/opensea-collection.sh`). `SKILL.md` and `references/rest-api.md` updated.

## 2.6.0

### Minor Changes

- 94dbf08: Refresh API references for the os2-core#40171 / #40190 sync.

  - `opensea-api/references/rest-api.md`: endpoint tables refreshed — removed deleted GET rows for `/orders/{chain}/seaport/{listings,offers}`, added `?maker=` annotations on the `/all` endpoints, added new rows for `listings/sweep`, per-NFT offers (`/offers/collection/{slug}/nfts/{token_id}`), `swap/execute`, and `transactions/receipt`.
  - `opensea-marketplace/references/marketplace-api.md`: replaced the "Get listings/offers for specific NFT" sections (which curled the removed endpoints) with the slug-based replacements (`/listings/collection/{slug}/nfts/{token_id}/best`, `/offers/collection/{slug}/nfts/{token_id}`).

  Also picks up `feat(skill): auto-publish to ClawHub on release [OS2-31827]` (#112) — adds a `clawhub-publish.yml` workflow to `packages/skill/.github/workflows/` that auto-publishes on release.

## 2.5.0

### Minor Changes

- 9ecf704: Provider-aware wallet hardening for Privy, Turnkey, Fireblocks, and Bankr.

  - `opensea-wallet/SKILL.md`: new "Security model" section documenting per-tx caps (provider-enforced), aggregate caps (universally not native — wallet float is the answer), and policy mutation (requires separately-held credential per provider).
  - `opensea-wallet/references/wallet-setup.md`: hardening is now part of the happy path for all four providers — Privy authorization-key registration, Turnkey non-root signer-only API user, Fireblocks `Signer`-role keys, Bankr key scope flags.
  - `opensea-wallet/references/wallet-policies.md`: stripped the `PUT /policy` curl; sharpened the TEE-cannot-be-bypassed claim (it's narrower than it sounds — TEE protects against signing through an applied policy, not against the same env credentials rewriting the policy first).
  - New `opensea-wallet/references/wallet-funding.md`: hot/cold wallet float pattern, the universal answer for aggregate caps.
  - New top-level `docs/policy-administration.md` (outside any individual skill mount path): user-only mutation recipes for all four providers, including a Node script for `PATCH /v1/wallets/{id}` with auth signature.

## 2.4.0

### Minor Changes

- 28dda97: Restructure skills into modular Agent Skills format. The monolithic `packages/skill/` is split into five focused skills following the Agent Skills spec (agentskills.io): `opensea-api`, `opensea-marketplace`, `opensea-swaps`, `opensea-wallet`, and `opensea-tool-sdk`. Each skill has its own SKILL.md with frontmatter, scope contracts, and handoff routing. Adds `ecosystem/` directory with CONTRIBUTING.md and partner onboarding scaffolding, and a root `skills/README.md` with a decision tree and routing table for skill selection.

## 2.3.0

### Minor Changes

- fc44d9f: feat: add cross-chain fulfillment script

  New `opensea-cross-chain-fulfill.sh` script for buying NFTs using tokens from a different chain (e.g., USDC on Base → ETH mainnet NFT). Supports same-chain different-token purchases and sweeping up to 50 listings in a single request, with input validation for fulfiller, protocol address, listing chain, recipient, and order hashes. SKILL.md updated with the cross-chain buying workflow and a marketplace-actions table entry.

## 2.2.3

### Patch Changes

- 4a76bc1: Document server-side trait filtering on the three collection-scoped endpoints (NFTs, best listings, events). Adds a "Server-side trait filtering" section with usage examples for the CLI and SDK plus the empty-result and >1000-match server behaviors agents need to know about.
