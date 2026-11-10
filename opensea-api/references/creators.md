# Drops and collection pages

Creator operations. Writes need a wallet JWT (see [authentication.md](authentication.md)): `write:drops` for drops, `write:collections` from a collection editor for pages.

## Drops

| Task | Command |
|---|---|
| List drops | `opensea drops list [--type featured\|upcoming\|recently_minted] [--chains <c>]` |
| Drop details and stages | `opensea drops get <slug>` |
| Check the logged-in wallet's eligibility | `opensea drops eligibility <slug>` (`read:eligibility`) |
| Build a mint transaction | `opensea drops mint <slug> --minter <addr> [--quantity <n>]` |
| Build cross-chain mint transactions | `opensea drops cross-chain-mint <slug> --payer <addr> --minter <addr> --payment-chain <c> --payment-token <addr> [--quantity <n>]` |
| Deploy a SeaDrop contract, then wait for its collection | `opensea drops deploy --chain <c> --name <n> --symbol <s> --drop-type <t> --token-type <t> --sender <addr> [--send]`, `opensea drops deploy-receipt <chain> <tx_hash> --wait` |
| List a drop's saved items | `opensea drops items <slug>` |
| Upload a folder of item media and save it as the items | `opensea drops upload-items <slug> <dir> [--manifest <path>] [--concurrency <n>]` |
| Save an upload batch by filename | `opensea drops save-item-media-batch <slug> (--body <path> \| --upload-batch-id <uuid> --dir <path>)` |
| Upload media and metadata to IPFS | `opensea drops upload-metadata-ipfs <slug> [--wait] [--wait-timeout <s>]` |
| Check IPFS progress | `opensea drops metadata-ipfs-status <slug> <workflow-execution-id>` |
| Request a manifest CSV upload, then upload a file | `opensea drops create-manifest-upload <slug>`, `opensea drops upload-file --context <path\|-> --file <path> [--index <n>]` |
| Publish or unpublish (owner wallet) | `opensea drops publish <slug> [--send]`, `unpublish <slug> [--send]` |

Notes:

- `upload-items` replaces the drop's items. It uploads 50 files per request under one batch id, then saves by filename (natural order without a manifest).
- `upload-file` takes one upload context. For the array `create-item-media-upload` returns, pass `--index <n>`.
- `upload-metadata-ipfs --wait` exits 1 when the upload fails, is not found, or outlasts `--wait-timeout`.
- `publish --send` signs with the configured wallet (see `opensea-wallet`) and refuses a wallet that is not the contract owner, since the transaction would revert.
- For a cross-chain mint, submit every returned transaction in order, save `receipt_request` exactly as received, then poll `opensea transactions receipt --request receipt-request.json` until `SUCCESS` or `FAILED`.

## Collection pages

| Task | Command |
|---|---|
| Read the saved page and its preview URL | `opensea collections get-metadata <slug>` |
| Update the page | `opensea collections update-metadata <slug> --body <path>` |
| Edit description, links, banner, logo | `opensea collections modify <slug> --body <path>` |
| Upload a page image or MP4 and get its token | `opensea collections upload-page-media <slug> <placement> --content-type <mime> [--file <path>]` |
| Price secondary sales in USDG or the native currency | `opensea collections set-pricing-currency <slug> --stablecoin <true\|false>` |
| Read creator fee enforcement (API key only) | `opensea collections creator-fee-enforcement <slug>` |
| Turn enforcement on or off (owner wallet) | `opensea collections set-creator-fee-enforcement <slug> --enabled <true\|false> [--send]` |
| Refresh metadata from the contract | `opensea collections refresh <slug>` |

`get-metadata` returns the page in the `update-metadata` body shape. A field you leave out keeps what is saved. To keep a saved image or video, send its url back as the token; a `mux_video` has no url, so leave its field out. Pass an upload token as `{"image": {"token": ...}}` or `{"video": {"token": ...}}`.

Placements: `hero_desktop`, `hero_mobile`, `about_preview`, `about_section`, `overview`, `overview_background`, `team`.

To clear, send it empty:

| Clear | Send |
|---|---|
| Preview media | `"about": {"preview_media": []}` |
| All about sections | `"about": {"sections": []}` |
| One section's image | the section with its `id` and `"media": []` |
| A hero slot | `"hero": {"desktop_hero_media": {}}` |
| Every overview module | `"overview": {"modules": {}}` (sending `overview` replaces every module) |
| Description, website, Telegram, banner, logo | `""` in `collections modify` |

A cleared logo falls back to the contract image. `GET /collections/{slug}` can trail a `modify` by a minute or more; read page content back with `get-metadata`, which is fresh. `set-creator-fee-enforcement --send` signs every returned transaction in order and refuses a wallet that is not the contract owner.
