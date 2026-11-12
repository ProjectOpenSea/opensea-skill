# OpenSea Stream API (WebSocket)

## JavaScript/TypeScript client
Use the `@opensea/sdk/stream` client:

```ts
import { OpenSeaStreamClient } from "@opensea/sdk/stream"

const client = new OpenSeaStreamClient({ apiKey: "YOUR_API_KEY" })
client.onItemSold("your-collection-slug", event => console.log(event))
```

Shell clients such as `websocat` use the raw WebSocket flow below.

## Base endpoint
wss://stream-api.opensea.io/socket/websocket?token=YOUR_API_KEY

## Join a collection channel
Send a Phoenix join message:

{"topic":"collection:your-collection-slug","event":"phx_join","payload":{},"ref":1}

Use "collection:*" to subscribe globally.

## Heartbeat
Send every ~30 seconds:

{"topic":"phoenix","event":"heartbeat","payload":{},"ref":0}

## Event types
- item_metadata_updated
- item_listed
- item_sold
- item_transferred
- item_received_bid
- item_cancelled
- collection_offer
- trait_offer
- order_invalidate
- order_revalidate

## Notes
- The stream is WebSocket, not HTTP, so curl cannot read it.
- Use `scripts/stream/opensea-stream-collection.sh` (prefers websocat).
