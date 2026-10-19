# Net worth (assets and liabilities): PARKED

> **Status: parked by Raviteja on 2026-10-18. Do not build anything from this until he confirms.** Research and plan only.


Date: 2026-10-18. Research and plan only, no code. Grounded in the repo at current main and `docs/review-2026-10/ACTION_PLAN.md`.

## Recommendation

Do not build a general net worth tracker. Build one thin slice, **Liabilities (loans) plus a net worth line**, and only after a cheap demand check. The slice fits what InvTrack is already good at (alternative investments, honest returns, privacy). A full tracker (bank accounts, cash, EPF, vehicles, bank linking) is a different product with free, well-funded competitors.

## Who it is for and the job

The user is an India-first self-directed investor holding FDs, P2P, chit funds, gold, property. Today InvTrack answers "how are my investments returning?". Net worth answers "am I getting richer, and is my debt costing more than my investments earn?". The second half is the one nobody serves well for alternative assets.

## What exists in the repo

- Each investment already has `currentValue` and `currentValueDate`, so the asset side of net worth is mostly there as "current value of open, non-archived investments" (`investment_entity.dart`).
- There is no liability concept anywhere (searched `lib/` and `docs/`: only an old roadmap line about a family net worth dashboard).
- Existing rules constrain the design: open investments without a current value show "—" (rule 4), archived ones are excluded and must be disclosed (rule 9), every amount converts to base currency (rule 2), every new Firestore collection needs account deletion plus export/import coverage (rule 6), privacy mode hides all amounts (rule 8).

## Competitors (limited evidence)

Web search returned mostly vendor marketing; treat these as indicative, not verified.

- India: INDmoney and Richify offer free net worth trackers; INDmoney asks users to link accounts. Free and bank-linked is the norm, so a paid net worth feature alone is a weak sell.
- US: Monarch about $99.99 a year, Empower free (monetised through advisory). No retention or user numbers were found for either.
- Gap: none of the India results show alternative assets (chit funds, P2P, private lending) with real XIRR. That is InvTrack's niche.

## Effort versus value

| Slice | Value | Effort (repo convention) | Verdict |
|---|---|---|---|
| Net worth line from existing investments only | Low alone (it is the portfolio total renamed) | S | Only as part of the slice below |
| Liabilities (loan: balance, rate, EMI, currency) plus net worth card | Medium: new reason to open the app, unique "loan rate vs your XIRR" insight | M to L (entity, Firestore, deletion, export/import, privacy, analytics, l10n, calc module, tests) | Recommended, behind a FeatureFlag |
| Monthly net worth snapshots and trend | Medium: a monthly habit | M | Phase 2, premium candidate |
| Bank/Account Aggregator linking, cash, EPF/PPF/NPS auto-sync | High but a different product | XL, regulatory and cost | No |

## Risks

- Focus: the plan is correctness first, then Premium before 15 March (A58 to A60). This must not displace that.
- Money rules: net worth mixes assets with and without current values, and currencies. A wrong or stale number here breaks trust faster than a missing feature. Show "—" or "Awaiting current value", never a guess.
- Stale data: liabilities are manual, so balances rot. Without a monthly "update balances" nudge the card becomes wrong and people stop opening it.
- Privacy and compliance: no bank linking, no credit data. Keep it manual and on-device-first.

## Adoption, retention, revenue (reasoned, not measured)

- Adoption: a "know your net worth" hook is searchable and shareable, but India has free incumbents, so it is a feature, not a headline.
- Retention: a monthly update habit is real, but only if updating takes seconds.
- Revenue: fits the A58 rule (Premium built from new features only). Candidates: net worth history and loan payoff insights. Nothing free today becomes paid.

## Phases

0. **Validate (days, almost no code):** check Play reviews and support mail for loan/net worth asks, and run a one-question in-app or store survey. Go only if clear demand.
1. **Liabilities and net worth card (flagged):** loan entity, net worth = open non-archived investment values minus liabilities, honest empty states, privacy mode, deletion and export/import, analytics with buckets only. Mock the UI in the design system first.
2. **Snapshots and trend:** monthly snapshot, chart, monthly "update balances" reminder. Premium candidate.
3. **Insights:** loan rate versus portfolio XIRR, FIRE number net of debt, prepay-or-invest nudge.

## Open decisions

1. Go, validate-first, or no-go on the slice (Founder Inbox card posted).
2. Timing: after the correctness wave and before or after the Premium launch.
3. Whether non-investment assets (cash, EPF/PPF) ever join, or the app stays "investments minus loans".
