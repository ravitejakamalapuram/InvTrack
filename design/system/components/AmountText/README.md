A money amount in compact lakh/crore notation, with a long-press that shows and copies the exact figure and a screen-reader label that reads the same number aloud.

Use it for every amount that can be large: hero, cards, strips, tiles. For full-precision amounts on a detail screen use the full format (`₹3,25,000.00`).

## Formats (`InvTrack.fmt`)

- Below one lakh: the full amount with lakh grouping, `₹99,999`.
- From one lakh: `₹1 L`, `₹3.25 L`, `₹99.95 L`; up to two decimals, trailing zeros dropped, a space before the unit. A value that rounds to 100 L becomes `₹1 Cr` (never `100 L`, never `0.99 Cr`). Above that `₹1.05 Cr`, `₹1,000 Cr`.
- Other currencies: `K`, `M`, `B`, `T` with no space and the locale's separators (`$1.23M`).
- Sign: `-₹55 L`; an explicit `+` or `-` prefix (cards) replaces the automatic sign.
- Smart (hero, net position): full below one lakh, compact from one lakh.
- Spoken: `₹1,05,05,000` reads "1.05 crore rupees", `₹99,999` "99,999 rupees", negative amounts "negative 55 lakh rupees"; the screen-reader label uses the currency's locale (without it the amount is read with Western grouping).

## Behaviour

Press and hold shows the Exact Amount toast with a copy button (the Flutter widget offers the long-press and the screen-reader long-press action only; the HTML component also answers Enter and Space); the semantics hint is "Double tap and hold to copy exact amount". Copy shows "Copied to clipboard". In privacy mode the long-press is disabled and the label is "Hidden amount".

## Consumer provides

`amount` (a number already in the base currency), `symbol`, optional `prefix`. Format with the one shared formatter; never hand-build the string.

## Rules

- The currency symbol is the user's base currency, only on base-currency amounts.
- One decimal rule everywhere: compact amounts at most two decimals.
- Always make the exact figure reachable.

## Contrast

Inherits the text colour of its context; see `text` and `text-muted` in the tokens.

## Source

`compact_amount_text.dart`; `currency_utils.dart` (`formatCompactCurrency`, `formatSmartCurrency`, `indianCompactParts`); `accessibility_utils.dart`.
