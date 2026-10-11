A goal's progress: the list card on the Goals screen and the compact card in the Overview carousel.

Use the list card for one goal in a scrolling list, the carousel card for the Overview. For the numbers behind a goal use the goal details screen, which shows the long chip text.

## Anatomy (list card)

- Surface: `GlassCard`, zero padding, tappable, 12px below (`list-item-gap`).
- Main row (padding 16): optional checkbox (selection mode), a 48px goal tile (14px radius, gradient of the goal colour, the goal's emoji at 24px), the info column, and the progress ring (56px, stroke 5, the percent inside; in privacy mode the ring is replaced by "••%" at the same edge).
- Info: the goal name (Inter 600 16px, one line, ellipsis: it is a name), the progress text (12px `text-muted`, "₹2.5 L of ₹10 L" or "₹5,353/mo of ₹50,000/mo", masked in privacy mode), and, when other goals count the same investments, the chip "Also in 2 goals".
- Footer (padding 16 x 12, 3% fill, rounded bottom corners): the status icon and label on the start edge (14px icon, label 12px/500 in the status colour), the status message on the end edge (12px `text-muted`: "Goal achieved!", "On track for Jun 2057", "Behind schedule - needs attention").

## Alignment

- The ring, the footer message and the carousel badge and bar all end on the same content edge, the card padding inside the 1px border. The footer is `CardFooterRow`: the message is end-aligned to that edge and wraps onto more lines, it is never cut with an ellipsis; a Row of `Spacer()` and `Flexible(Text)` left it 22 to 48dp short, and `test/repo/card_alignment_scan_test.dart` fails that pattern.
- The chip wraps or is shortened, never cut in the middle of a word. On a card it is the plural-aware "Also in 1 goal" / "Also in 12 goals"; the goal details screen has room for "Also counted in 2 other goals". A screen reader always hears the long sentence (on a list card the card's own label, "View details for ...", is what it reads).
- Nothing in the footer or the chip holds an amount, so privacy mode leaves them as they are.

## Carousel card

A `GlassCard` (radius 16, flat) with padding 16 x 10: the 48px goal tile, the name with the percent badge ("🎉 Completed" once achieved) at the end of the same line, the progress amount (11px, one line, ellipsis: a last resort), and a 6px progress bar. It has no footer. Its slot in the carousel is `GoalCarouselCard.heightFor`: 41dp + 45dp per unit of text scale, at least 110dp, because the card's three lines grow with the text size and a fixed 110dp overflowed by 19dp at x2.0. `test/layout/goal_carousel_height_test.dart` sweeps 1.0x to 2.0x text.

## States

Achieved · On track (with a projected month, or "Making steady progress") · Ahead · Behind (with or without a target date) · In progress (corpus or income goal) · Not started · Archived · With the chip (1, 2, 12 other goals) · Selection mode · Privacy mode · Loading and error (a spinner; "Error loading progress").

## Consumer provides

Display strings and the status key: `name`, `emoji`, `color`, `status`, `progress`, `percent`, `message`, `others`, `privacy`, `kind` (`'list'` or `'carousel'`). The screen derives the status and the message from `GoalProgress`; this card never computes one. Amounts must already be in the base currency.

## Rules

- Hide every amount in privacy mode, the semantics label too.
- Footer text and chip wrap; nothing is truncated except the goal name and the carousel's progress line.
- Every card is tappable with a 48dp target (the card itself).

## Source

`goal_card.dart` (`GoalCard`), `goal_carousel_card.dart` (`GoalCarouselCard`), `goals_dashboard_card.dart`, `shared_goals_chip.dart` (`SharedGoalsChip`, `compact`), `card_footer_row.dart` (`CardFooterRow`), `goal_progress_ring.dart`; `goal_type_ui.dart` for the status icon, colour, label and message.
