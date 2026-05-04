# @opensea/skill

## 2.3.0

### Minor Changes

- fc44d9f: feat: add cross-chain fulfillment script

  New `opensea-cross-chain-fulfill.sh` script for buying NFTs using tokens from a different chain (e.g., USDC on Base → ETH mainnet NFT). Supports same-chain different-token purchases and sweeping up to 50 listings in a single request, with input validation for fulfiller, protocol address, listing chain, recipient, and order hashes. SKILL.md updated with the cross-chain buying workflow and a marketplace-actions table entry.

## 2.2.3

### Patch Changes

- 4a76bc1: Document server-side trait filtering on the three collection-scoped endpoints (NFTs, best listings, events). Adds a "Server-side trait filtering" section with usage examples for the CLI and SDK plus the empty-result and >1000-match server behaviors agents need to know about.
