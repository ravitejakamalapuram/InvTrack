The Overview's headline card: net cash flow so far with its return badge, money out and in, and XIRR, on the violet hero gradient.

Use it once, at the top of the Overview. It is the only large colour field in the app. For any other stat use `StatTile`.

## Anatomy

- Surface: `GlassHeroCard`: `gradient-hero` (light) or `gradient-hero-dark`, `radius-xxl` 24, padding 20 (`space-lg`), `shadow-hero`, two faint white glow circles. All text on it is white at set opacities.
- Title row: "Net cash flow so far" ("Realized Net Position" in the realised scope; 14px, white 80%), the privacy eye (`PrivacyMask` toggle, 18px, in a 12px-radius frame), and the scope toggle "All" / "Realized" (a 16px-radius pill).
- Value: the amount in Inter 700 36px, a bare style that inherits line height 1.4 from the theme body text (compact, `formatSmart`: full below one lakh, then `L` / `Cr`), and the return badge (14px/600, 8px radius). The badge sits beside the amount on the amount's baseline when both fit on one line, and drops below it on the start edge when they do not, never half way: the app measures the amount as it would be written, so privacy mode, which draws dots, decides the same way. The badge is green (`#69f0ae` on green 30%) for a non-negative net, red (`#ff5252` on red 30%) for a negative one. When a status applies the badge becomes a neutral white-15% chip placed below the amount, so long localised text can never squeeze the amount out of its row; the chip fades out in privacy mode like the badge.
- Stats (`StatColumns`): equal columns of label over value inside the card padding, the labels on one baseline and the values on another although XIRR is larger: arrow-up with money out, arrow-down with money in (value 14px/600 white; "out" and "in" white 60% 12px), then XIRR (label 12px white 60%, value 16px/600), the last column ending on the padding like the buttons above it. With an estimated value the label reads "Expected XIRR" and "Realised XIRR" follows as a fourth column. A column is never narrower than `stat-column-min-width` (72) times the text scale: at 360dp the row holds 3 columns at text x1.0, 2 at x1.3 and 1 at x2.0 (3, 3 and 2 at 411dp); a column left alone on its row is one line, the label on the start edge and the value on the end edge, on one baseline. The label wraps upward, so a long label never moves its value.
- Notes: 11px white 60% for "Money out includes fees. Reinvested payouts count once in MOIC and return %." and the hint ("Based on 7% p.a.", "Add a payout or current value to calculate"); the base-currency line (info icon, 10px italic, white 50%): "All amounts shown in ₹ (INR)"; in the realised scope "Showing closed investments only".

## States

Return shown (badge and XIRR) · Expected (estimated value) · Awaiting first payout / Awaiting current value (status chip, XIRR `—`, never 0% or -100%) · Realised scope · Privacy mode (amounts become bullets, badge and XIRR hidden, space kept) · Loading (two translucent bars on the gradient).

## Consumer provides

Display strings only: `amount`, `returnText` or `status`, `positive`, `out`, `inn`, `xirr`, `xirrLabel`, `realisedXirr`, `note`, `hint`, `scope` (`'all'` or `'realized'`), `privacy`, `currencyLabel`, `loading`. The screen decides which of the three return states applies from `ReturnDisplay.resolve`; this card never computes one. Numbers must already be in the base currency.

## Rules

- Hide every amount in privacy mode, the semantics label too ("Hidden amount").
- A screen reader reads each stat column as one stop, "out:" then the amount ("in:", "XIRR:" the same), never the label and the amount as two; in privacy mode the stop is "out:" then "Hidden amount". The amount keeps its "Double tap and hold to copy" hint and action inside the stop.
- Never show a return badge or a % XIRR for an open investment without a value: show the status and `—`.
- Keep the currency disclosure line visible whenever amounts are shown.
- Stats stack and the title wraps, they are never truncated, at large text scale; only the amount may ellipsise, and its long-press shows the exact figure (`AmountText`).
- The badge shares the amount's baseline or drops below it; the last stat ends on the card padding. `test/layout/card_guard_360_test.dart` and `card_guard_411_test.dart` measure both on the real card.

## Contrast

White at 80% on the light gradient is 4.45:1 to 3.97:1 (title); white at 60% (notes, "out"/"in", XIRR label) is 3.20:1 to 2.85:1; the 10px currency line at 50% is 2.70:1 to 2.40:1; the negative badge (`#ff5252` on red 30%) is only 1.62:1 to 1.83:1 and the positive badge 3.59:1 to 3.69:1. On the dark gradient everything at 60% or more passes; white at 40% (the info icon) is 3.16:1 to 3.66:1. These are the source's values and are kept; the arrow, the sign and the words carry meaning, not colour.

## Source

`hero_card.dart` (`HeroCardWithToggle`, `HeroCardContent`, `LoadingHeroCard`); `stat_columns.dart` (`StatColumns`); `text_measure.dart`; `glass_card.dart` (`GlassHeroCard`); `privacy_toggle_button.dart`; `compact_amount_text.dart`; `return_display.dart` for the state decision.
