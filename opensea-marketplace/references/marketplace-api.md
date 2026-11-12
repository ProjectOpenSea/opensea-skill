# OpenSea Marketplace API

Endpoints for buying and selling NFTs on OpenSea. EVM orders use **Seaport**; Solana-native order protocols go through the action endpoints. The API builds unsigned orders and transactions, fulfills listings and offers, and cancels orders. Your wallet signs everything client-side before it is submitted.

## Base URL and authentication

```
Base URL: https://api.opensea.io/api/v2
Auth: x-api-key: $OPENSEA_API_KEY
```

## Supported chains

The chain list changes as chains launch. Get the current identifiers from `GET /api/v2/chains` (`opensea chains list`, or `opensea-api/scripts/opensea-get.sh /api/v2/chains`).

---

## Reads

Finding listings, offers and orders is in the `opensea-api` skill (`opensea listings best-for-nft`, `opensea offers best-for-nft`, `opensea orders get`). Each order response carries the `order_hash` (`svm_order.id` on Solana) and `protocol_address` that the write endpoints below need.

## Writes (POST)

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

**Required `parameters` fields** (all present before signing): `offerer`, `zone`, `offer`, `consideration`, `startTime`, `endTime`, `orderType`, `zoneHash`, `salt`, `conduitKey`, `totalOriginalConsiderationItems`, `counter`.

**Field notes:**
- `counter`: the offerer's Seaport nonce. Read it with `getCounter(address)` on the Seaport contract, or use `"0"` for an account that has never called `incrementCounter`. Order hashes and EIP-712 signatures are bound to it.
- `salt`: a uint256 as a decimal string (for example `toString(randomBigInt(256))`). A hex string that parses as uint256 also works.
- `conduitKey`: `0x0000007b02230091a7ed01230072f7006a004d60a8d4e71d599b8104250f0000` is OpenSea's conduit. Use `0x0000…0000` to transfer directly, without a conduit.
- `zone` and `zoneHash`: the zero address and zero bytes32 unless you integrate a custom zone. `zone` is part of the signed `OrderComponents` struct, so it must be in `parameters` (even as the zero address) or signing fails.
- [Signing orders (EIP-712)](#signing-orders-eip-712) below covers the signature.

**Item types:**
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

**Request body** (the listing shape, with `offer` holding the payment and `consideration` holding the NFT):
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

Required fields and notes are the same as for a signed listing above.

### Signing orders (EIP-712)

Listings and offers need an EIP-712 signature over the order parameters, made by the `offerer`.

**Before signing**, read the offerer's current Seaport counter:

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

Set `chainId` to the target chain (`1` Ethereum, `8453` Base, `137` Polygon, and so on). `verifyingContract` is the Seaport 1.6 address, the same value as `protocol_address` in the request body.

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

**`message`:** the request body's `parameters` without `totalOriginalConsiderationItems`, which is submitted but not signed. uint256 values can stay decimal strings; ethers and viem convert them.

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

Then submit `protocol_address`, the full `parameters` (including `totalOriginalConsiderationItems`) and `signature`.

---

### Fulfill a listing (buy)

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

**Response:** transaction data for the buyer to submit onchain.

### Fulfilling ERC20-denominated listings

A listing can be priced in an ERC20 (a stablecoin such as USDG or USDC, or WETH) instead of the native currency. Three things differ from a native-priced listing:

**1. Prices are raw base units, so always use the `decimals` field.**

```json
"price": { "current": { "currency": "USDG", "decimals": 6, "value": "89000000" } }
```

Human-readable price = `value / 10^decimals`, 89 USDG here. Never assume 18 decimals: stablecoins often use 6, and dividing by 10^18 understates the price by 10^12.

**2. The fulfillment transaction sends no native value.**

`fulfillment_data.transaction.value` is `"0"`, and the consideration amounts are in the ERC20 (`itemType: 1`). The transaction pulls payment from the buyer with `transferFrom`. Do not attach native value.

**3. The buyer needs both balance and an approval before submitting.**

The buyer owes the sum of every ERC20 consideration item (seller proceeds plus marketplace and creator fees), not only the first. Before sending the returned transaction:

1. Check that the buyer's `balanceOf` on the payment token covers that total.
2. Find the address that pulls the payment. It is not always a conduit:
   - `fulfillerConduitKey` is `0x0000...0000` (`bytes32(0)`): Seaport transfers directly, so the buyer approves the Seaport contract in `transaction.to`.
   - `fulfillerConduitKey` is non-zero: resolve it with `getConduit(bytes32)` on the Seaport ConduitController, deployed at `0x00000000F9490004C11Cef243f5400493c00Ad63` on every chain, and approve the conduit it returns.
   ```bash
   cast call 0x00000000F9490004C11Cef243f5400493c00Ad63 \
     "getConduit(bytes32)(address,bool)" 0xFULFILLER_CONDUIT_KEY \
     --rpc-url <chain-rpc-url>
   ```
   The second return value is `exists`. If it is `false`, the key is not registered and the address is meaningless.
3. Check `allowance(buyer, spender)` on the payment token. If it is below the total, send an ERC20 `approve(spender, amount)` from the buyer first.

A missing allowance or balance is the most common cause of "execution reverted" on ERC20-priced fulfillments. Native-priced listings skip all of this, because payment travels as `transaction.value`.

Two ways to skip the manual steps:

- `POST /api/v2/listings/cross_chain_fulfillment_data` (see the cross-chain scripts) returns an ordered list of transactions that includes any required ERC20 approval, even for same-chain same-token purchases.
- `@opensea/sdk`'s `fulfillOrder` runs the check itself and, before spending gas, throws with the spender and the exact `approve` amount.

### Fulfill an offer (sell)

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

### Cancel an order

```bash
POST /api/v2/orders/chain/{chain}/protocol/{protocol_address}/{order_hash}/cancel
```

This is an offchain cancel for orders protected by OpenSea's SignedZone. It needs a wallet JWT with `write:orders`. A fulfillment signature issued before the cancel stays valid for up to 5 minutes, so the order can still fill in that window. For an onchain cancel, use `POST /api/v2/orders/chain/{chain}/protocol/{protocol_address}/{order_hash}/cancel/actions` and execute the returned steps.

---

## Workflow: buy an NFT

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

## Workflow: create a listing

1. `POST /api/v2/listings/actions` returns any approval transactions and the order to sign.
2. Send the approvals in order.
3. Sign the order (EIP-712, see [Signing orders](#signing-orders-eip-712)).
4. `POST /api/v2/orders/{chain}/seaport/listings` with `protocol_address`, `parameters` and `signature`.

## Workflow: make an offer

1. `POST /api/v2/offers/actions` returns any WETH approval and the order to sign.
2. Send the approvals, sign, then submit to `/api/v2/orders/{chain}/seaport/offers`.

## Workflow: accept an offer

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

## Order action endpoints (EVM and Solana)

These endpoints return ordered `steps` rather than raw Seaport calldata:

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

The create-offer request's `price.currency` is a token mint or contract address, never a ticker. For native SOL, pass the system-program address:

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

Each action carries `transaction` submission data. Follow its fields exactly:

- If `partiallySignedTransaction` is present, base64-decode and deserialize those exact transaction bytes, append the wallet's signature to the existing transaction, and broadcast it. Do not rebuild the message from `instructions`; rebuilding invalidates the existing cosigner signature.
- If `partiallySignedTransaction` is absent, build the transaction from `instructions`, `addressLookupTableAddresses`, and the requested wallet as signer.
- If `sponsoredFeePayer` is present, the OpenSea relayer pays network fees and rent; the wallet is a cosigner. If absent, the wallet pays.
- If `requiresJitoBundle` is `true`, submit through a Jito bundle. Sending it through public RPC pays the tip without the bundle's protection.
- A partial fill raises the filled quantity and can leave the offer live. Do not assume the whole offer was consumed; check the requested quantity and re-query the order.

---

## Error codes

| Code | Meaning |
|------|---------|
| 400 | Bad request: invalid parameters |
| 401 | Unauthorized: missing or invalid API key |
| 404 | Not found: the order or NFT does not exist |
| 429 | Rate limited |
| 500 | Server error |

## Rate limits

Limits apply per account, across all its API keys. Details are in [rest-api.md](../../opensea-api/references/rest-api.md#rate-limits).

**Default limits (Tier 1):** 120 read/min, 60 write/min, 60 fulfillment/min

The fulfillment endpoints (`/api/v2/listings/fulfillment_data`, `/api/v2/offers/fulfillment_data`) use the **fulfillment** bucket, order creation uses **write**, and every other GET uses **read**.

---

## Seaport contract addresses

| Chain | Seaport 1.6 address |
|-------|---------------------|
| All EVM chains | `0x0000000000000068F116a894984e2DB1123eB395` |

Legacy Seaport 1.5: `0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC`. Conduit controller: `0x00000000F9490004C11Cef243f5400493c00Ad63`.

---

## Tips

1. Pay offers in WETH or another ERC20. Native ETH cannot be used, because an offer is paid with an ERC20 approval.
2. Before listing, make sure Seaport (or OpenSea's conduit) is approved for your NFTs.
3. Test on Sepolia before sending mainnet transactions.
4. Check an order's `startTime` and `endTime` before fulfilling it.
5. Use the [Stream API](../../opensea-api/references/stream-api.md) for real-time order updates.
