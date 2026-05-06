---
name: <your-skill>
description: One-paragraph description of what this skill does and when to use it. Max 500 characters. Include keywords agents will search for. Make non-coverage explicit (e.g. "NOT for X; use <other-skill> instead").
homepage: <https://github.com/your-org/your-repo>
repository: <https://github.com/your-org/your-repo>
license: MIT
env:
  YOUR_API_KEY:
    description: API key for your service
    required: true
    obtain: <https://your-service.com/api-keys>
dependencies:
  - node >= 18.0.0
metadata:
  author: <your-org>
  provider: <your-org>
  partner: "true"
---

# <Your Skill Title>

> **Replace this whole file** when you copy this template into `ecosystem/<your-skill>/`. Update the `name` (must match the parent directory name), the `description`, and every section below.

Brief intro to what this skill does in 1-2 sentences.

## When to use this skill (`scope_in`)

Use `<your-skill>` when:

- <bullet describing a capability>
- <bullet describing a capability>

## When NOT to use this skill (`scope_out`, handoff)

| Need | Use instead |
|---|---|
| NFT/token data, search, collection stats | `opensea-api` |
| Buy/sell NFTs, listings, offers, fulfillment | `opensea-marketplace` |
| ERC20 token swaps | `opensea-swaps` |
| Wallet signing setup | `opensea-wallet` |
| Build/register/gate AI agent tools | `opensea-tool-sdk` |
| <your-non-coverage> | `<other-skill>` |

## Setup

Document any auth, env vars, or dependencies a user needs before the skill works.

```bash
export YOUR_API_KEY=<your-key>
```

## Reference

Detailed coverage of each surface area, one file per topic, lives in [`./references/`](./references/).
