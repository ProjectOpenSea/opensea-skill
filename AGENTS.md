# skill — Agent Conventions

AI agent skill for interacting with OpenSea via Claude, Devin, and other AI assistants. Provides shell scripts, reference docs, and a structured SKILL.md for LLM consumption.

## Quick Reference

This package is **not a pnpm workspace member** and is **not published to npm**. It is synced to the public [opensea-skill](https://github.com/ProjectOpenSea/opensea-skill) mirror.

There is no build or test step. Changes are validated by reviewing the shell scripts and documentation manually.

## Architecture

| File / Directory | Role |
|------------------|------|
| `SKILL.md` | Primary entry point for AI agents — full usage guide with CLI examples, shell script docs, and task walkthroughs |
| `scripts/` | Standalone shell scripts for REST API and Stream API access (curl + jq) |
| `references/` | Technical reference docs: Seaport protocol, marketplace API, stream API, token swaps, wallet setup |
| `package.json` | Metadata only (private, not published) |
| `.env.example` | Required and optional environment variables |

## Review Checklist

When reviewing changes to this package, verify:

1. **SKILL.md is the source of truth for agents**. It must accurately reflect the current CLI commands, API endpoints, and shell scripts. Outdated examples cause agents to fail silently.

2. **Shell scripts are self-contained**. Each script in `scripts/` should work with just `OPENSEA_API_KEY` set and `curl` + `jq` available. Do not add dependencies on Node.js or other tools.

3. **Security**: This package is mirrored to a public repo. Never include API keys, internal URLs, or private infrastructure details. Treat all content as publicly visible.

4. **CLI parity**: The skill recommends `@opensea/cli` as the preferred interface. When CLI commands change in `packages/cli`, update the corresponding examples in `SKILL.md`.

5. **Reference doc accuracy**: Files in `references/` describe protocol details (Seaport order structure, fulfillment data, wallet policies). Verify they match the current SDK and API behavior.

## Conventions

- All shell scripts use `#!/usr/bin/env bash` and read `OPENSEA_API_KEY` from the environment.
- Scripts output JSON by default (piped through `jq` when available).
- SKILL.md frontmatter declares required/optional env vars and dependencies.
- Changes to this package should use `/sync` (not `/release`) since it is not versioned on npm.
- **Never open PRs against the public `opensea-skill` repo** — all changes go through this monorepo.
