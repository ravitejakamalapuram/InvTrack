The Monthly recap screen ("October Recap"): what came in last month, what matures next month, and which open investments still need a current value. A monthly notification opens it.

It is a screen built from existing parts (GlassCard, StatTile styles, EmptyState, Button, Badge chips, PrivacyMask, AmountText); it adds no tokens.

## Layout

- App bar (64dp): a back `TonalIconAction` and the privacy `TonalIconAction` (selected while privacy mode is on; tooltips "Hide amounts" / "Show amounts"), both on `screen-edge` through `leadingWidth: appBarLeadingWidth` and `appBarTrailingGap`, as on Investment detail. The title "October Recap" (Title Case) is `h2` in `text`, with the date range "1 Oct – 31 Oct 2026" under it in `small` and `text-muted`.
- Body on `screen-edge` (16) through `ScreenEdge`, as on Overview and Investment detail. Sections are `section-gap` (24) apart, each with a `ScreenSectionHeader` (`h4`, Title Case) and its cards `list-item-gap` (12) apart. Cards are GlassCards, padding 16, radius 20.
- **Money In**: one card. Label "Payouts received" in `caption`, the total (`AppTypography.number`, Plus Jakarta Sans 28/700, in `text`, `formatSmart`), the caption "3 payouts from 2 investments", then the comparison line 12 below: arrow up and `+₹4,200 more than September` in `success`, arrow down and `-₹1,500 less than September` in `danger`, or a flat arrow and "Same as September" in `text-muted` with no amount. Empty: compact EmptyState "No payouts recorded in October" / "Payouts you add for October will appear here" with the text button "Add a Payout".
- **Coming Up In November**: one tappable card per investment maturing next month: type icon in its tinted 8px tile, name (one line, ellipsis), the type badge and the maturity chip (`MATURES 12 NOV`, ALL CAPS, accent tone, `event` icon), chevron. The tap opens the investment. Empty: one line "Nothing matures in November" in `text-muted`.
- **Needs A Value**: one card per open investment with no current value: hourglass in a `text-muted` icon on a `surface` tile (the same 8px tile as the Coming Up rows), name, "Add a current value to see its XIRR", text button "Update" (48dp target). Hidden when empty.
- Footer: caption "Archived investments are not included."

## Tokens

Spacing, type, radius and icon sizes come only from `AppSpacing`, `AppTypography` and `AppSizes` (tile `radius-sm` 8, tile icon 20, inline icons 16). Muted text is `text-muted` (`textSecondaryLight` / `textSecondaryDark`). In privacy mode the comparison wraps rather than forming one long row, so it does not overflow at 1.8x text on a 320dp screen.

## States

Full month (light and dark), privacy mode, quiet month (Money In empty, one line under Coming Up, Needs A Value hidden), and the notification. All are in `preview.html`.

## Notification

Title "Your October recap is ready". Body states counts only: "1 investment matures in November. 2 need a current value." With no fact to state: "See what came in last month." Never an amount, name or percentage, whatever the privacy setting.

## Privacy

- The total is a `MaskedAmountText` (six bullets at 28px) and the comparison amount is masked too.
- In privacy mode the comparison line becomes "Compared with September: •••••" with no arrow, colour or more/less, because direction reveals size.
- Counts, names, types and dates stay visible. The notification never carries amounts, so it does not change.

## Screen reader

- Headline, one stop: "Money in, October: 18,400 rupees. 3 payouts from 2 investments." In privacy mode: "Money in, October: Hidden amount. 3 payouts from 2 investments."
- Comparison: "Up 4,200 rupees from September", "Down 1,500 rupees from September", "Same as September"; in privacy mode "Compared with September: Hidden amount". Amounts read in lakh and crore (`formatCurrencyForScreenReader`).
- A maturing row: "Senior citizen FD, Fixed Deposit, matures 12 November. Opens the investment."

## Consumer provides

The month and its date range, the payout total and the change against the previous month in the base currency (every INCOME and RETURN cash flow converted with `batchConvert` before summing; totals and counts come from `lib/core/calculations`, never re-derived on the screen), the payout and investment counts, the maturing investments (name, type, maturity date) and the open investments with no current value. Archived investments are left out of every section. All copy comes from `app_en.arb`.

## Rules

- Positive and negative differ by arrow and sign as well as colour.
- No XIRR, return % or `0%` on this screen: an investment without a value is listed under Needs A Value, not given a figure.
- Dates are date-only; the month is [1st, 1st of next month).

## Source

`lib/features/digest/presentation/screens/monthly_recap_screen.dart` (behind the `monthly_recap` flag).
