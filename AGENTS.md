# skill — Agent Conventions

Modular AI agent skills for interacting with OpenSea. Shell scripts, reference docs, and SKILL.md files for LLM consumption.

## Quick commands

There is no build or test step. Validate shell scripts and docs manually.

```bash
# Syntax-check scripts (they live in per-domain subdirectories)
find . -name '*.sh' -exec bash -n {} +
# What CI runs: shellcheck, plus every opensea-*/scripts/*.sh must be executable
shellcheck $(find . -name '*.sh')
find . -name '*.sh' ! -perm -u+x
# Run the skill sync check, and check every `opensea ...` command in the docs exists in the CLI
../../scripts/check-skill-sync.sh
node ../../scripts/check-skill-cli-refs.mjs
```

## Responsibilities

- `SKILL.md` router and five sub-skills: `opensea-api`, `opensea-marketplace`, `opensea-swaps`, `opensea-wallet`, `opensea-tool-sdk`.
- Reference docs and standalone `curl`/`jq` scripts per sub-skill.
- Mirror `opensea-tool-sdk/` to `packages/tool-sdk/skill/`.

## Rules

1. **SKILL.md files are the source of truth for agents**. Keep CLI commands, API endpoints, and shell script examples current.
2. **No duplication across sub-skills**. Put wallet-provider tables in `opensea-wallet/` and shared scripts in `opensea-api/scripts/`; link elsewhere.
3. **Shell scripts are self-contained**. Each script should work with `OPENSEA_API_KEY` and `curl` + `jq` only.
4. **Security**. This package mirrors to a public repo; never include API keys, internal URLs, or private infra.
5. **Skill sync**. `packages/tool-sdk/skill/` and `packages/skill/opensea-tool-sdk/` must remain identical. Run `scripts/check-skill-sync.sh` locally.
6. **Releases**. `/release skill` is the full flow: bump `package.json` by hand, prepend `CHANGELOG.md`, tag `skill-vX.Y.Z`, and let the GitHub/ClawHub chain publish. Do not run `pnpm changeset` for skill — it is excluded from the pnpm workspace.

## Conventions

- Shell scripts use `#!/usr/bin/env bash` and read `OPENSEA_API_KEY`.
- Scripts output JSON by default (pipe through `jq` when available).
- SKILL.md frontmatter declares env vars and dependencies.
- Keep each SKILL.md short enough to read in one pass (roughly 150 lines) and complete for everyday tasks. Move specialized flows to `references/` and link them. Prefer the CLI and its `--help` over restating every flag, and never hand-copy MCP tool parameter schemas: the server publishes them.
- Bump `.grok-plugin/plugin.json` with `package.json` on release; CI fails when they differ.
