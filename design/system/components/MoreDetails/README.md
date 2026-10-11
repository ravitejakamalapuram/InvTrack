The collapsed tile that holds a form's optional fields (`MoreDetailsTile`). Add Investment asks for the type, the name, the amount and the date; currency, rate, term, notes and the rest wait behind this tile.

Use it to keep a long form short. Everything inside is optional: the form saves without opening it.

## Anatomy

- Header: a `glass` card at least 64px tall, 16 x 12 padding. A 40px disc (`radius-md` 12, `primary` at 10%) with a 24px `tune` icon, the title (`label` 14/600 in `text`), a one-line summary (`small` 12 in `text-muted`) and a 24px expand arrow in `text-muted` (`expand_less` while open).
- Body: mounted only while open, one form gap (`form-field-gap` 20px) below the header; each field brings its own spacing. It opens and closes with a 200 ms size animation.
- The summary says what is inside ("Currency, rate, term, notes and more"). It never repeats a number the user did not type: no rate, no term.

## Behaviour

- The page owns whether it is open, so the answer survives a rebuild; it also owns the controllers of the fields inside, so closing the tile loses nothing the user typed.
- The header is one button for a screen reader: label = the title, hint = the summary, and the expanded or collapsed state.
- At 320dp and text 1.8x the summary wraps; nothing overflows.

## Consumer provides

`title`, `summary`, `open`, `body`.

## Source

`more_details_tile.dart` (`lib/core/widgets`).
