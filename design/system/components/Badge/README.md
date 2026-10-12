Small labels: the percentage change badge, the status pill, the currency badge, and the maturity, type and closed chips drawn on cards.

Use a badge for one short fact beside a value. Use a `Chip` when the label can be selected.

## Kinds (`InvTrack.Badge({ kind })`)

- `change` (ChangeBadge): sizes small (10px, padding 6 x 2, 6px radius), medium (12px, 8 x 4), large (`percentage` 16px, 12 x 6, 10px radius). A leading arrow (10, 12, 16px) unless the value is zero; the text is the value to two decimals with a `+` for positive and the suffix `%`. Positive `success` on `success-bg`, negative `danger` on `danger-bg`, zero `neutral-600-light` on `neutral-200-light` (6.08:1). Outlined mode: transparent with a 30% border. The widget does not read the theme, so the pastel fills appear in dark mode too, with one exception: an outlined zero badge has no fill and sits on the page, so in dark its text is `neutral-500-dark` (5.23:1 on the page, 4.74:1 on `card`).
- `status` (StatusBadge): pill (20px radius), 10px/600 with +0.5 spacing, padding 10 x 4, the colour at 15% fill (outlined: a 50% border). Also the neutral chip that replaces a return % ("Awaiting first payout").
- `currency` (CurrencyBadge): compact is the code on `primary` 20% with a 30% border (4px radius, 11px/600, themed `primary`); full adds a separator and the rate, "USD | 1 $ = ₹83.12", rate to two decimals, on `input-fill` at 80% (50% in dark). Use it wherever a non-base currency appears.
- `maturity`: 6px radius, padding 8 x 2, an optional 10px icon, 12px/600 in the tone's text colour on its 15% tint: `MATURED`, `MATURES TODAY`, `7d TO MATURITY`. The text is `success`, `warning-text` or `accent-text`; the tint is `success-tint`, `warning` or `accent`.
- `type` and `closed`: the investment type name in its colour on 10%, and the grey `CLOSED`.

## Consumer provides

`value` (number) for `change`; `label`, `color` for the others; `code`, `rate`, `target` for `currency`.

## Rules

- Direction is the arrow and the sign, never colour alone.
- A return that cannot be calculated is not a badge with 0%; use the neutral status text.
- Show the currency badge on every amount not in the base currency; never show a native amount under the base symbol.
- Keep badge text short and upper-case only for state words.

## Contrast

`success` on `success-bg` 4.73:1, `danger` on `danger-bg` 4.60:1 (both pass); the maturity chips' `warning-text` on a 15% `warning` tint 4.64:1 and `accent-text` on `accent` 4.75:1 (pass); the grey `CLOSED` 2.27:1; the compact currency badge's `primary` on its 20% tint is 4.45:1. Kept as drawn; the arrow, the sign and the words carry the meaning. An outlined zero badge passes: `neutral-600-light` on the light page 7.30:1, `neutral-500-dark` on the dark page 5.23:1.

## Source

`change_badge.dart` (`ChangeBadge`, `StatusBadge`); `currency_badge.dart` (`CurrencyBadge`, `CompactCurrencyBadge`); `investment_card.dart` (maturity, type, closed chips).
