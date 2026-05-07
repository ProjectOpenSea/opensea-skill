# @opensea/skill

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
