# Signals, social, agent accounts and saved tools

All writes here need a wallet JWT (see [authentication.md](authentication.md)). Reads of public data need only the API key.

## Signals

Public posts about one subject: a currency (`--chain` and `--contract`), an NFT (add `--token-id`: decimal on EVM, mint address on Solana), or a collection (`--collection`).

| Task | Command |
|---|---|
| List signals, newest first | `opensea signals list (--chain <c> --contract <addr> [--token-id <id>] \| --collection <slug>) [--limit <n>] [--next <cursor>]` |
| Get one | `opensea signals get <signal_id>` |
| Post | `opensea signals create --text <text> (<subject flags>) [--author-address <addr>]` |
| Delete your own | `opensea signals delete <signal_id>` |

- Posting and deleting need `write:posts`, which is in preview: `opensea auth scopes` does not list it and browser OAuth rejects it, so log in with `opensea login --private-key --scopes write:posts`.
- A page can be empty while `next` is set. Keep paging until `next` is null.
- IDs are opaque `sig_v1_...` strings. Pass them back unchanged.
- `create` is not idempotent. A retry after an unknown outcome can post twice once the per-subject cooldown passes; a post inside the cooldown returns 422. Signals cannot be edited.

## Follows, watches and watchlists

| Task | Command | Scope |
|---|---|---|
| Followers, following, relationship | `opensea accounts followers <who>`, `following <who>`, `relationship <who>` | `read:social` |
| Follow, unfollow, watch, unwatch | `opensea accounts follow <who>`, `unfollow`, `watch`, `unwatch` | `write:social` |
| Favorites and token watchlists | `opensea accounts favorites <addr>`, `token-watchlist`, `perpetual-watchlist` | `read:favorites` |
| Add to or remove from the watchlist | `opensea accounts watchlist-add --body <path>`, `watchlist-remove --body <path>` | `write:favorites` |
| Profile, username, PFP, shelves | `opensea profile --help` | `write:profile` |

## Agent accounts

Declare that an account is an agent and record who owns it. Ownership is a relationship both sides confirm. It is a self-reported declaration: it grants the counterparty no ability to act, creates no sub-account, and OpenSea does not verify it. An agent has zero or one confirmed owner. Either side can revoke at any time. Only confirmed relationships are public.

| Task | Command |
|---|---|
| Declare or withdraw | `opensea agent declare`, `opensea agent withdraw` |
| Propose, confirm, revoke | `opensea agent propose <addr> --role AGENT\|OWNER`, `confirm ...`, `revoke ...` |
| Your relationships, including pending | `opensea agent list` |
| Someone's public profile (API key only) | `opensea agent profile <address_or_username>` |

```bash
# Agent side
opensea login --private-key --scopes read:wallets,write:wallets
opensea agent declare
opensea agent propose 0xOWNER --role AGENT
opensea agent list            # PENDING_OWNER until the owner confirms

# Owner side: confirm, or propose the mirror image, which confirms it
opensea agent confirm 0xAGENT --role OWNER
```

- `--role` is your side: `--role AGENT` means you are the agent and the counterparty owns you. Your own account comes from the token.
- Writes need `write:wallets`; `agent list` needs `read:wallets`. Missing either returns 403.
- `declare` and `withdraw` return `changed`, `propose` and `confirm` return `created`, `revoke` returns `removed`. Each is false for a no-op, so a retry is distinguishable from a real change.

## Saved tools [Beta]

| Task | Command | Scope |
|---|---|---|
| List saved tools | `opensea tools saved list [--toolkit-name <name>]` | `read:tools` |
| Save or remove a tool | `opensea tools saved save <chain_id> <registry> <tool_id> [--toolkit-name <name>]`, `remove ...` | `write:tools` |

Finding tools to save is in [`opensea-tool-sdk`](../../opensea-tool-sdk/SKILL.md#tool-discovery-beta).
