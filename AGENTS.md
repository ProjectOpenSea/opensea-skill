# skill — Agent Conventions

Modular AI agent skills for interacting with OpenSea via Claude, Devin, and other AI assistants. Provides shell scripts, reference docs, and structured SKILL.md files for LLM consumption.

## Quick Reference

This package is **not a pnpm workspace member** and is **not published to npm**. It is synced to the public [opensea-skill](https://github.com/ProjectOpenSea/opensea-skill) mirror.

There is no build or test step. Changes are validated by reviewing the shell scripts and documentation manually.

## Architecture

| File / Directory | Role |
|------------------|------|
| `SKILL.md` | Router entry point — directs agents to the correct sub-skill based on task |
| `opensea-api/SKILL.md` | Read-only queries: collections, NFTs, tokens, search, drops, events |
| `opensea-marketplace/SKILL.md` | Write operations: buy/sell NFTs, Seaport fulfillment, sweeps |
| `opensea-swaps/SKILL.md` | ERC20 token swaps via DEX aggregator |
| `opensea-wallet/SKILL.md` | Wallet provider setup: Privy, Turnkey, Fireblocks, Bankr, private key |
| `opensea-tool-sdk/SKILL.md` | Build/register/gate AI agent tools (proposed ERC) |
| `ecosystem/` | Partner skill contributions (template + guide) |
| `package.json` | Metadata only (private, not published) |
| `.env.example` | Required and optional environment variables |

## Review Checklist

When reviewing changes to this package, verify:

1. **SKILL.md files are the source of truth for agents**. They must accurately reflect the current CLI commands, API endpoints, and shell scripts. Outdated examples cause agents to fail silently.

2. **No duplication across sub-skills**. The wallet provider table lives only in `opensea-wallet`. `opensea-post.sh` lives only in `opensea-api/scripts/`. Other skills link to these canonical locations.

3. **Shell scripts are self-contained**. Each script should work with just `OPENSEA_API_KEY` set and `curl` + `jq` available. Do not add dependencies on Node.js or other tools.

4. **Security**: This package is mirrored to a public repo. Never include API keys, internal URLs, or private infrastructure details. Treat all content as publicly visible.

5. **CLI parity**: The skills recommend `@opensea/cli` as the preferred interface. When CLI commands change in `packages/cli`, update the corresponding examples in the relevant sub-skill SKILL.md.

6. **Reference doc accuracy**: Files in sub-skill `references/` directories describe protocol details. Verify they match the current SDK and API behavior.

## Conventions

- All shell scripts use `#!/usr/bin/env bash` and read `OPENSEA_API_KEY` from the environment.
- Scripts output JSON by default (piped through `jq` when available).
- SKILL.md frontmatter declares required/optional env vars and dependencies.
- Changes to this package should use `/sync` (not `/release`) since it is not versioned on npm.
- **Never open PRs against the public `opensea-skill` repo** — all changes go through this monorepo.
