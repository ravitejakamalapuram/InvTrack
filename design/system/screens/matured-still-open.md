# Matured but still open (#1251)

Text mock of one extra line on the maturity card of the investment detail page. Built from existing parts: `GlassCard`, `TextButton`. No new token and no new shared widget.

```
Maturity Date                         Matured 42 days ago
12 Oct 2026
Matured on 12 Oct 2026. Still open?
[ Mark it closed ]  [ Record the payout ]
```

- Shown only for an open, not archived investment, more than 7 days after its maturity date. Never for closed or archived ones, or before maturity.
- "Mark it closed" runs the existing close flow, with its confirmation. "Record the payout" opens the existing add cash flow screen. Nothing closes by itself.
- Dates only, no amounts, so privacy mode needs no mask.
