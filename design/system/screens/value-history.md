# Value history and the weight line (#946)

Mock of the dated values of one investment, and the one new line on the current value card. Built from existing parts: `GlassCard`, `ListTile`, `FilledButton`, the current value dialog (`CurrentValueDialog`, see `current-value-by-weight.md`). No new token and no new shared widget.

Visual mock: https://claude.ai/artifact/Y9BAt8VVCF5EAtYUWApU52 (screens 2 and 3).

## Current value card (investment detail)

```
Current value                         [History] [Update]
₹64,500
10 gram × ₹6,450.00                   <- only when the value was typed as weight x price
Updated 12 Nov 2026
```

- "History" appears only while dated values are on, for an open investment.
- The weight line is masked in privacy mode like the amount, and is not read out in the card's screen reader label.

## Value history screen

```
< Value history
The latest value counts for your totals. Older ones show how it moved.
12 Nov 2026   10 gram × ₹6,450.00        ₹64,500.00
 3 Nov 2026                              ₹60,000.00
[ Add a value ]
```

- Newest first. The amount is in the investment's own currency with its own symbol, never the base currency's.
- Tap a row: the same editor as "Update", opened on that value, its date and its weight and price. Its remove button says "Remove" and removes that value; a snackbar offers "Undo".
- Empty: "No values yet. Add one to see how this investment moved." with "Add a value".
- Row label for screen readers: "12 Nov 2026, INR 64,500.00". In privacy mode: "12 Nov 2026, value hidden".
- In privacy mode the editor opens without the saved amount, weight or price (the date stays); the user types the new value.
- Weight and price are offered for gold only.
