# Contributing an Ecosystem Skill

This guide is for ecosystem partners adding skills to this repo.

## Curation principle

The ecosystem is **curated for complementary, non-overlapping capabilities**. Before you start, confirm your skill covers something OpenSea does not provide first-party.

We do **not** accept ecosystem skills that overlap with first-party OpenSea capabilities, including:

- NFT marketplace operations (listings, offers, fulfillment, Seaport)
- NFT and collection data queries
- Token swaps via OpenSea's DEX aggregator
- OpenSea MCP server tools
- OpenSea Tool Registry and tool-sdk operations

This is a statement about *which of a partner's skills we accept here*, not about partners themselves. A partner can have products that overlap with OpenSea in other parts of their catalog; we will accept their non-overlapping skills.

Why: agents route on `description` and `scope_in`. Two skills claiming the same capability create routing ambiguity that usually fails silently. A curated complementary catalog keeps routing deterministic.

If you're unsure whether your skill overlaps, open an issue and ask.

## Quick start

1. Confirm your skill is non-overlapping (see above)
2. Copy `ecosystem/TEMPLATE/` to `ecosystem/<vendor>-<skill-name>/`, then rename `SKILL.template.md` to `SKILL.md`
3. Fill in `SKILL.md` (instructions, scope contract, routing back to first-party skills)
4. Open a PR

## Skill contract

Every ecosystem `SKILL.md` must include the following frontmatter (matching the schema used by first-party skills):

```yaml
---
name: <your-skill>
description: <one paragraph; max 500 chars; what it does and when to use>
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
```

In the body, every ecosystem skill must include two routing sections:

- **`## When to use this skill (scope_in)`**: bullet list of what the skill covers
- **`## When NOT to use this skill (scope_out, handoff)`**: a `Need | Use instead` table that names the sibling skill an agent should hand off to for each non-coverage

### Standard handoffs to first-party OpenSea skills

| If the user needs... | Hand off to |
|---|---|
| NFT/token data, search, collection stats | `opensea-api` |
| Buy/sell NFTs, listings, offers, fulfillment | `opensea-marketplace` |
| ERC20 token swaps | `opensea-swaps` |
| Wallet signing setup | `opensea-wallet` |
| Build/register/gate AI agent tools | `opensea-tool-sdk` |

## File structure

```
ecosystem/<vendor>-<skill-name>/
├── SKILL.md           # Required: metadata + instructions + scope contract
├── LICENSE.txt         # Required: your license (typically MIT)
├── .upstream.json      # Optional: provenance stamp if synced from an upstream repo
├── references/         # Optional: reference docs (bot-maintained when .upstream.json is present)
└── agents/             # Optional: openai.yaml for Codex picker
```

## Keeping references fresh (optional)

If your skill's `references/` directory mirrors content from your own upstream repo, you can opt into automated weekly syncs by declaring your skill in [`sync.config.json`](./sync.config.json). The bot (`pnpm sync-ecosystem`, run by `.github/workflows/sync-ecosystem.yml`) will:

- Clone your upstream at the pinned `ref` (typically `main`)
- Copy `<your-upstream>/<from>/references/` into `ecosystem/<vendor>-<skill-name>/references/`
- Apply any declared string `rewrites` (e.g. renaming a sibling skill that has a vendor prefix in this repo but not in yours)
- Write `.upstream.json` with the upstream SHA and timestamp so reviewers can verify provenance
- Open a PR for human review — never auto-merges

The bot **does not touch** `SKILL.md`, `LICENSE.txt`, or `agents/`. Those stay human-curated (the description, handoff table, and frontmatter overlay are judgment calls that don't survive automation).

If you don't opt in, your skill is fully hand-maintained — no `sync.config.json` entry, no `.upstream.json` stamp.

## Review criteria

- Non-overlapping with first-party skills
- Clear scope contract with handoff routing
- Frontmatter follows the schema above
- `LICENSE.txt` present with partner's copyright
- No credentials, internal URLs, or sensitive data
