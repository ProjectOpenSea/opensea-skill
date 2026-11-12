# Hot/cold wallet pattern for agent budgets

None of the four managed providers (Privy, Turnkey, Fireblocks, Bankr) enforces an **aggregate** spend cap. They cap single transactions and allowlist destinations, but they do not track how much ETH or USDC left the wallet over a day or a week. The pattern here splits the budget across two wallets so that the agent wallet's balance is the aggregate cap.

## Why a cap the agent tracks itself does not work

A `dailyCapEth` that the agent tracks is an honor system. A compromised or prompt-injected agent ignores it. A cap is a security control only when something outside the agent's control enforces it: the provider (none supports cumulative caps today) or the amount of money the agent can reach.

The wallet balance is that limit. If the agent's wallet holds one budget period of funds, a fully compromised agent can lose one period's budget, not drain an open-ended amount.

## The pattern

Two wallets:

- The cold (funding) wallet belongs to the user, on a hardware wallet or other cold storage, and holds the long-term budget. The agent never signs with it. It can have its own per-tx policy with the same provider, but custody is what protects it.
- The hot (agent) wallet is the one whose credentials are in the agent's env. It has a per-tx Privy, Turnkey or TAP policy, and its balance is about one budget period.

The user refills the hot wallet from the cold wallet on a schedule they control, and that schedule is the aggregate cap. If the user adds 0.5 ETH every Monday, the agent cannot spend more than 0.5 ETH a week, whatever its `dailyCapEth` says.

Per-tx caps still limit the loss from a single transaction within the period. The aggregate cap is the wallet balance.

## Worked example

Goal: the agent swaps and buys NFTs for the user, at most 0.1 ETH per trade and about 0.5 ETH per week.

1. Per-tx cap, at the provider: apply a Privy policy with `value <= 100000000000000000` (0.1 ETH in wei) to the hot wallet. The template is in [wallet-policies.md](wallet-policies.md); the user applies it with [policy-administration.md](../../docs/policy-administration.md).
2. Aggregate cap, through the float: keep about 0.5 ETH in the hot wallet and refill it weekly from the cold wallet. `opensea wallet info` prints the hot wallet's `address` to send to.
3. Verify: `opensea wallet info` should show `policyIds: ["pol_..."]`, which confirms the per-tx cap. The CLI does not show the balance; check it on a block explorer or in the provider's dashboard.

A single 0.4 ETH transaction is denied by the Privy policy before signing. A compromised agent that sends five 0.1 ETH transactions in a row succeeds, and that is the bound: five 0.1 ETH transactions are the period's budget.

## Sizing the float

Keep the float slightly above one budget period, not several. The float is the cap, so a float 10x larger is a cap 10x larger.

A reasonable default is 1.5x one period's expected spend: enough to avoid mid-period top-ups for routine use, small enough to bound the worst case.

## Provider notes

- Privy: the hot wallet needs its own `policy_ids` and, as recommended, an `owner_id`, so the agent's env credentials cannot raise the cap. See the Privy section of [wallet-setup.md](wallet-setup.md).
- Turnkey: scope the agent's API user to sign-only activities for the hot wallet's address. Put the cold wallet in a different sub-org or behind a different policy.
- Fireblocks: put the cold wallet in a separate vault. The agent's Signer-role API key can sign only for the hot vault.
- Bankr: set the hot wallet key's `allowedRecipients` to the destinations the agent needs. The cold wallet is a separate Bankr account or an ordinary EOA the user controls.

## If a stateful approval webhook ships

If your provider adds a transaction-approval webhook (for example, Privy's planned stateful policy callbacks), it can enforce an aggregate cap directly: the webhook sums the wallet's recent onchain transfers against the cap and allows or denies. Until then, use the wallet float.
