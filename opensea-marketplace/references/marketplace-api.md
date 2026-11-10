# OpenSea Marketplace API

This reference covers the marketplace endpoints for buying and selling NFTs and tokens on OpenSea.

## Overview

OpenSea uses **Seaport** for EVM marketplace orders and supports Solana-native order protocols through the action APIs. The API provides endpoints to:
- Query existing listings and offers
- Build new listings and offers (returns unsigned Seaport orders)
- Fulfill orders (accept listings or offers)
- Cancel orders

**Important**: Creating and fulfilling orders requires wallet signatures. The API returns order data that must be signed client-side before submission.

## Base URL and Authentication

```
Base URL: https://api.opensea.io/api/v2
Auth: x-api-key: $OPENSEA_API_KEY
```

## Supported Chains

The set of supported chains changes as new chains launch. Fetch the current list of chain identifiers from `GET /api/v2/chains` (see `opensea-api/scripts/opensea-get.sh`).

---

## Read Operations

Finding listings, offers and orders is covered by the `opensea-api` skill (`opensea listings best-for-nft`, `opensea offers best-for-nft`, `opensea orders get`). Each order response carries the `order_hash` (or `svm_order.id` on Solana) and `protocol_address` the write endpoints below need.

## Write Operations (POST)

### Submit a signed listing

`POST /api/v2/orders/{chain}/seaport/listings` (CLI: `opensea listings post <chain> --body signed.json`) submits an order you have already signed. Get the order to sign from `POST /api/v2/listings/actions` (`opensea listings actions`), or build it by hand as below.

**Request body:**
```json
{
  "protocol_address": "0x0000000000000068f116a894984e2db1123eb395",
  "parameters": {
    "offerer": "0xYourWalletAddress",
    "offer": [{
      "itemType": 2,
      "token": "0xContractAddress",
      "identifierOrCriteria": "1234",
      "startAmount": "1",
      "endAmount": "1"
    }],
    "consideration": [{
      "itemType": 0,
      "token": "0x0000000000000000000000000000000000000000",
      "identifierOrCriteria": "0",
      "startAmount": "1000000000000000000",
      "endAmount": "1000000000000000000",
      "recipient": "0xYourWalletAddress"
    }],
    "startTime": "1704067200",
    "endTime": "1735689600",
    "orderType": 0,
    "zone": "0x0000000000000000000000000000000000000000",
    "zoneHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "salt": "24446860302761739304752683030156737591518664810215442929805094493721949474548",
    "conduitKey": "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000",
    "totalOriginalConsiderationItems": 1,
    "counter": "0"
  },
  "signature": "0xSignedOrderSignature"
}
```

**Required top-level fields:** `protocol_address`, `parameters`, `signature`.

**Required `parameters` fields** (all must be present before signing): `offerer`, `zone`, `offer`, `consideration`, `startTime`, `endTime`, `orderType`, `zoneHash`, `salt`, `conduitKey`, `totalOriginalConsiderationItems`, `counter`.

**Field notes:**
- `counter`: Seaport nonce for the offerer. Fetch with `getCounter(address)` on the Seaport contract, or use `"0"` for accounts that have never canceled via `incrementCounter`. Order hashes and EIP-712 signatures are bound to this value.
- `salt`: uint256 as a decimal string (e.g. from `toString(randomBigInt(256))`). A hex string works too as long as it parses as uint256.
- `conduitKey`: `0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000` is OpenSea's conduit. Use `0x0000…0000` to transfer directly without a conduit.
- `zone` / `zoneHash`: use zero address / zero bytes32 unless you're integrating a custom zone. `zone` is part of the signed `OrderComponents` struct, so it must be present in `parameters` (even as the zero address) or signing will fail.
- See `### Signing Orders (EIP-712)` below for building the signature.

**Item Types:**
- `0`: Native currency (ETH, MATIC, etc.)
- `1`: ERC20 token
- `2`: ERC721 NFT
- `3`: ERC1155 NFT

**Example (curl):**
```bash
curl -X POST "https://api.opensea.io/api/v2/orders/ethereum/seaport/listings" \
  -H "x-api-key: $OPENSEA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"protocol_address": "0x0000000000000068f116a894984e2db1123eb395", "parameters": {...}, "signature": "0x..."}'
```

### Submit a signed offer

`POST /api/v2/orders/{chain}/seaport/offers` (CLI: `opensea offers post <chain> --body signed.json`) submits a signed offer. Get the order to sign from `POST /api/v2/offers/actions` (`opensea offers actions`).

```bash
POST /api/v2/orders/{chain}/seaport/offers
```

**Request body structure** (same shape as listings, with top-level `protocol_address`, `parameters`, `signature`, but `offer` contains payment and `consideration` contains the NFT):
```json
{
  "protocol_address": "0x0000000000000068f116a894984e2db1123eb395",
  "parameters": {
    "offerer": "0xBuyerWalletAddress",
    "offer": [{
      "itemType": 1,
      "token": "0xWETHAddress",
      "identifierOrCriteria": "0",
      "startAmount": "1000000000000000000",
      "endAmount": "1000000000000000000"
    }],
    "consideration": [{
      "itemType": 2,
      "token": "0xNFTContractAddress",
      "identifierOrCriteria": "1234",
      "startAmount": "1",
      "endAmount": "1",
      "recipient": "0xBuyerWalletAddress"
    }],
    "startTime": "1704067200",
    "endTime": "1735689600",
    "orderType": 0,
    "zone": "0x0000000000000000000000000000000000000000",
    "zoneHash": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "salt": "24446860302761739304752683030156737591518664810215442929805094493721949474548",
    "conduitKey": "0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000",
    "totalOriginalConsiderationItems": 1,
    "counter": "0"
  },
  "signature": "0x..."
}
```

Field requirements and notes are identical to **Submit a signed listing** (see above).

### Signing Orders (EIP-712)

Both listing and offer creation require an EIP-712 signature over the order parameters. The signer must be the `offerer`.

**Before signing**, fetch the offerer's current Seaport counter:

```bash
# Returns the uint256 counter. Use "0" for any account that has never called incrementCounter.
cast call 0x0000000000000068F116a894984e2DB1123eB395 \
  "getCounter(address)(uint256)" 0xYourWalletAddress \
  --rpc-url <chain-rpc-url>
```

**EIP-712 `domain`:**
```json
{
  "name": "Seaport",
  "version": "1.6",
  "chainId": 1,
  "verifyingContract": "0x0000000000000068F116a894984e2DB1123eB395"
}
```

Set `chainId` to the target chain ID (`1` for Ethereum, `8453` for Base, `137` for Polygon, etc.). `verifyingContract` is the Seaport 1.6 address (the same value as `protocol_address` in the request body).

**EIP-712 `types` (primary type `OrderComponents`):**
```json
{
  "OrderComponents": [
    { "name": "offerer", "type": "address" },
    { "name": "zone", "type": "address" },
    { "name": "offer", "type": "OfferItem[]" },
    { "name": "consideration", "type": "ConsiderationItem[]" },
    { "name": "orderType", "type": "uint8" },
    { "name": "startTime", "type": "uint256" },
    { "name": "endTime", "type": "uint256" },
    { "name": "zoneHash", "type": "bytes32" },
    { "name": "salt", "type": "uint256" },
    { "name": "conduitKey", "type": "bytes32" },
    { "name": "counter", "type": "uint256" }
  ],
  "OfferItem": [
    { "name": "itemType", "type": "uint8" },
    { "name": "token", "type": "address" },
    { "name": "identifierOrCriteria", "type": "uint256" },
    { "name": "startAmount", "type": "uint256" },
    { "name": "endAmount", "type": "uint256" }
  ],
  "ConsiderationItem": [
    { "name": "itemType", "type": "uint8" },
    { "name": "token", "type": "address" },
    { "name": "identifierOrCriteria", "type": "uint256" },
    { "name": "startAmount", "type": "uint256" },
    { "name": "endAmount", "type": "uint256" },
    { "name": "recipient", "type": "address" }
  ]
}
```

**`message`:** the `parameters` object from the request body, minus `totalOriginalConsiderationItems` (which is a submission-only field, not part of the signed struct). All uint256 values can stay as decimal strings; ethers/viem will coerce.

**Example with viem:**
```typescript
import { createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

const account = privateKeyToAccount(process.env.PRIVATE_KEY);
const client = createWalletClient({ account, transport: http() });

const { totalOriginalConsiderationItems, ...message } = parameters;

const signature = await client.signTypedData({
  domain: {
    name: 'Seaport',
    version: '1.6',
    chainId: 1,
    verifyingContract: '0x0000000000000068F116a894984e2DB1123eB395',
  },
  types: { OrderComponents, OfferItem, ConsiderationItem },
  primaryType: 'OrderComponents',
  message,
});

// POST { protocol_address, parameters, signature } to /api/v2/orders/{chain}/seaport/listings
```

After signing, submit with `protocol_address`, the full `parameters` object (including `totalOriginalConsiderationItems`), and `signature`.

---

### Fulfill a Listing (Buy NFT)

Accept an existing listing to purchase an NFT.

```bash
POST /api/v2/listings/fulfillment_data
```

**Request body:**
```json
{
  "listing": {
    "hash": "0xOrderHash",
    "chain": "ethereum",
    "protocol_address": "0x0000000000000068f116a894984e2db1123eb395"
  },
  "fulfiller": {
    "address": "0xBuyerWalletAddress"
  }
}
```

**Response:** Returns transaction data for the buyer to submit onchain.

### Fulfilling ERC20-denominated listings

Listings can be priced in an ERC20 token (stablecoins like USDG/USDC, WETH) instead of the native currency. The listing price and the fulfillment flow differ from native-priced listings in three ways:

**1. Prices are raw base units, so always use the `decimals` field.**

```json
"price": { "current": { "currency": "USDG", "decimals": 6, "value": "89000000" } }
```

Human-readable price = `value / 10^decimals` = 89 USDG here. Never divide by 10^18 unconditionally. Stablecoins commonly use 6 decimals, so assuming 18 understates the price by a factor of 10^12.

**2. The fulfillment transaction sends no native value.**

For an ERC20-priced listing, `fulfillment_data.transaction.value` is `"0"` and the consideration amounts are denominated in the ERC20 token (`itemType: 1`). Payment is pulled from the buyer with `transferFrom` when the transaction executes. Do not attach native value.

**3. The buyer needs both balance and an approval before submitting.**

The amount owed is the sum of every ERC20 consideration item, seller proceeds plus marketplace and creator fees, not just the first one. Before executing the returned transaction:

1. Check the buyer's `balanceOf` on the payment token covers that total.
2. Work out which address will pull the payment, and it is not always a conduit:
   - `fulfillerConduitKey` is `0x0000...0000` (`bytes32(0)`): Seaport transfers directly, so the buyer approves the Seaport contract in `transaction.to`.
   - `fulfillerConduitKey` is non-zero: resolve it with `getConduit(bytes32)` on the Seaport ConduitController, deployed at `0x00000000F9490004C11Cef243f5400493c00Ad63` on every chain, and approve the conduit it returns.
   ```bash
   cast call 0x00000000F9490004C11Cef243f5400493c00Ad63 \
     "getConduit(bytes32)(address,bool)" 0xFULFILLER_CONDUIT_KEY \
     --rpc-url <chain-rpc-url>
   ```
   The second return value is `exists`. If it is `false`, the key is not registered and the address is meaningless.
3. Check `allowance(buyer, spender)` on the payment token. If it is below the total, send an ERC20 `approve(spender, amount)` from the buyer first.

Insufficient allowance or balance is the most common cause of "execution reverted" when simulating or submitting ERC20-priced fulfillments. Native-priced listings skip all of this, because the payment travels as `transaction.value`.

Two ways to avoid doing this by hand:

- `POST /api/v2/listings/cross_chain_fulfillment_data` (see the cross-chain scripts) returns an ordered list of transactions that includes any required ERC20 approval, even for same-chain same-token purchases.
- `@opensea/sdk`'s `fulfillOrder` runs this check itself and throws with the spender and the exact `approve` amount before spending gas.

### Fulfill an Offer (Sell NFT)

Accept an existing offer to sell your NFT.

```bash
POST /api/v2/offers/fulfillment_data
```

**Request body:**
```json
{
  "offer": {
    "hash": "0xOfferOrderHash",
    "chain": "ethereum",
    "protocol_address": "0x0000000000000068f116a894984e2db1123eb395"
  },
  "fulfiller": {
    "address": "0xSellerWalletAddress"
  },
  "consideration": {
    "asset_contract_address": "0xNFTContract",
    "token_id": "1234"
  }
}
```

### Cancel an Order

Cancel an active listing or offer.

```bash
POST /api/v2/orders/chain/{chain}/protocol/{protocol_address}/{order_hash}/cancel
```

This endpoint is an offchain cancel for orders protected by OpenSea's SignedZone and needs a wallet JWT with `write:orders`. A fulfillment signature issued before the cancel stays valid for up to 5 minutes, so the order can still fill in that window. For an onchain cancel, use `POST /api/v2/orders/chain/{chain}/protocol/{protocol_address}/{order_hash}/cancel/actions` and execute the returned steps.

---

## Workflow: Buying an NFT

Steps 1 and 2 are read-only and live in the [`opensea-api`](../../opensea-api/SKILL.md) skill.

1. **Find the NFT** (opensea-api): `opensea nfts get <chain> <contract> <token_id>`
2. **Check listings** (opensea-api): `opensea listings best-for-nft <slug> <token_id>`
3. **Get fulfillment data** (this skill): POST to `/api/v2/listings/fulfillment_data`
4. **Execute transaction**: sign and submit the returned transaction data

```bash
# Step 1: Get NFT info (opensea-api skill)
opensea nfts get ethereum 0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d 1234

# Step 2: Get best listing (opensea-api skill)
opensea listings best-for-nft boredapeyachtclub 1234

# Step 3: Request fulfillment (this skill)
./scripts/opensea-fulfill-listing.sh ethereum 0x_order_hash 0x_your_wallet
```

## Workflow: Creating a Listing

1. **Get actions** - `POST /api/v2/listings/actions` returns any approval transactions plus the order to sign
2. **Send approvals** - Execute approval steps in order
3. **Sign the order** - EIP-712, see **Signing Orders** above
4. **Submit** - `POST /api/v2/orders/{chain}/seaport/listings` with `protocol_address`, `parameters` and `signature`

## Workflow: Making an Offer

1. **Get actions** - `POST /api/v2/offers/actions` returns any WETH approval plus the order to sign
2. **Send approvals**, **sign**, then **submit** to `/api/v2/orders/{chain}/seaport/offers`

## Workflow: Accepting an Offer

1. **View offers** (opensea-api): `opensea offers all <slug> --limit 50`
2. **Get fulfillment data** (this skill): POST to `/api/v2/offers/fulfillment_data`
3. **Execute**: submit the returned transaction

---

## Running steps yourself

`--send` on the action commands runs these steps for you. Run them by hand only for what it refuses (Solana, bulk orders, swap routes, collection offers). Each step is an object with one key naming the action:

- A transaction step (`buyItemAction`, `acceptOfferAction`, `cancelOrdersAction`, `itemApprovalAction`, `paymentApprovalAction`) holds `transaction.to.value`, `data`, `value` and `chainIdentifier.chainId`, ready to send from `transaction.from.value`.
- A creation step (`createListingsAction`, `createOfferAction`, `createOffersAction`) holds `signatureRequest.message`, a JSON string with the EIP-712 `domain`, `types`, `primaryType` and `message`. Parse it without rounding large integers (the `counter` can exceed 2^53), sign it, then post `{protocol_address, parameters, signature}` with `opensea listings post <chain>` or `opensea offers post <chain>`. `parameters` is the signed `message` plus `totalOriginalConsiderationItems`.

Check every transaction the way `--send` does. A non-approval transaction must call Seaport on its chain, with a fulfillment function selector for a buy or sale, or `cancel` for a cancel. An approval must be sent to the token or NFT contract it approves, and its spender must be Seaport or OpenSea's conduit on that chain; a conduit is never a valid `to`. Refuse a domain whose `verifyingContract` is not Seaport on the order's chain, and an order whose NFT, quantity, currency, total, fees (more than 11% to anyone but the offerer) or end time differ from what you requested. The API's ERC-20 approvals are for max uint256; approve only what the order spends unless the user agrees to more.

---

## Order Action Endpoints (EVM and Solana)

These endpoints return ordered `steps` instead of assuming a Seaport calldata response:

| Operation | Endpoint | Action script |
|---|---|---|
| Create offer | `POST /api/v2/offers/actions` | `opensea-create-offer-actions.sh` |
| Fulfill listing | `POST /api/v2/listings/fulfillment/actions` | `opensea-fulfill-listing-actions.sh` |
| Fulfill offer | `POST /api/v2/offers/fulfillment/actions` | `opensea-fulfill-offer-actions.sh` |
| Cancel order | `POST /api/v2/orders/chain/{chain}/protocol/{protocol_address}/{order_identifier}/cancel/actions` | `opensea-cancel-order-actions.sh` |

The CLI exposes the same endpoints:

```bash
opensea offers actions --body create-offer.json
opensea listings fulfillment-actions --body fulfill-listing.json
opensea offers fulfillment-actions --body fulfill-offer.json
opensea orders cancel-actions solana <protocol_address> <order_identifier> --body cancel.json
```

The create-offer request's `price.currency` is a token mint/contract address, not a ticker symbol.
For native SOL, pass the system-program address:

```json
{
  "item": {"chain": "solana", "contract": "<asset_id>", "token_id": "<asset_id>"},
  "address": "<maker>",
  "quantity": 1,
  "price": {"amount": "0.001", "currency": "11111111111111111111111111111111"}
}
```

Passing `"SOL"` as `price.currency` is invalid.

Request bodies use the API's JSON field names. Example Solana listing fulfillment:

```json
{
  "listing": {
    "hash": "<svm_order.id>",
    "chain": "solana",
    "protocol_address": "<protocol_address from the listing>"
  },
  "fulfiller": { "address": "<buyer base58 address>" },
  "include_optional_creator_fees": false
}
```

For a Solana listing or offer, use `svm_order.id` wherever the request calls for the order identifier. Do not substitute `order_hash`, and do not hardcode the Seaport address: pass through the order's returned `protocol_address`. Base58 identifiers are case-sensitive.

### Solana transaction submission

Process `steps` in array order. The Solana variants are:

- `svmCreateOfferAction` for offer creation;
- `svmBuyItemsAction` for listing fulfillment;
- `svmAcceptOfferAction` for offer fulfillment;
- `svmCancelOrdersAction` for cancellation.

Each action carries `transaction` submission data. Follow these fields literally:

- If `partiallySignedTransaction` is present, base64-decode and deserialize those exact transaction bytes, append the wallet's signature to the existing transaction, and broadcast it. Do not rebuild the message from `instructions`; rebuilding invalidates the existing cosigner signature.
- If `partiallySignedTransaction` is absent, build the transaction from `instructions`, `addressLookupTableAddresses`, and the requested wallet as signer.
- If `sponsoredFeePayer` is present, the OpenSea relayer pays network fees and rent; the wallet is a cosigner. If absent, the wallet pays.
- If `requiresJitoBundle` is `true`, submit through a Jito bundle. Do not send the transaction through public RPC, which would pay the tip without receiving the intended bundle protection.
- A successful partial fill increments the filled quantity but can leave the offer live. Do not assume fulfillment consumed the entire offer; inspect the requested quantity and re-query the order.

---

## Error Codes

| Code | Meaning |
|------|---------|
| 400 | Bad request - invalid parameters |
| 401 | Unauthorized - missing or invalid API key |
| 404 | Not found - order/NFT doesn't exist |
| 429 | Rate limited - too many requests |
| 500 | Server error |

## Rate Limits

Rate limits apply per-account across all API keys. See `references/rest-api.md` for full details.

**Default limits (Tier 1):** 120 read/min, 60 write/min, 60 fulfillment/min

Fulfillment endpoints (`/api/v2/listings/fulfillment_data`, `/api/v2/offers/fulfillment_data`) use the **fulfillment** rate bucket. Order creation endpoints use the **write** rate bucket. All other GET endpoints use the **read** rate bucket.

---

## Seaport Contract Addresses

| Chain | Seaport 1.6 Address |
|-------|---------------------|
| All EVM chains | `0x0000000000000068F116a894984e2DB1123eB395` |

Legacy Seaport 1.5: `0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC`. Conduit controller: `0x00000000F9490004C11Cef243f5400493c00Ad63`.

---

## Tips

1. **Always use WETH for offers** - Native ETH cannot be used for offers due to ERC20 approval requirements
2. **Check approval status** - Before creating listings, ensure Seaport has approval for your NFTs
3. **Test on Sepolia first** - Use testnet before mainnet transactions
4. **Handle expiration** - Orders have startTime/endTime - check these before fulfilling
5. **Monitor events** - Use Stream API for real-time order updates
