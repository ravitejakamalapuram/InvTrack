Selectable pills: the filter tabs above the investment list, the investment-type selector in forms (a wrapping grid, or one sideways row), the quick-template chips, and the Material chip theme.

Use filter chips to narrow a list (exactly one selected), the type selector to pick one value from a small set, template chips to start a form with defaults.

## Kinds (`InvTrack.Chip({ kind })`)

- `filter`: pill (`radius-xl`), padding 16 x 8, label `small` 12px/500 (600 when selected), a 2px transparent border that turns the focus colour on focus (`neutral-900-light` in light, white in dark), a count bubble (10px/600, 10px radius). Unselected: black or white 5% fill, `neutral-700-light` or white 70% text. Selected: the light-mode primary fill with white text in both themes.
- `type` (TypeSelector): 12px radius, padding 16 x 12 (12 x 10 compact), a 4px-padded 8px-radius icon holder with an 18px icon (16 compact), label 14px (13 compact), 10px gap. Unselected on `surface` with a 1.5px `field-border`; selected filled with the type colour, white text and icon, no border, a soft glow `0 6 16 -2` at 35%. Focus: a 2px border (light-mode primary or white) and a 1px spread glow. Wrap layout, a two-column grid (labels ellipsise) or the sideways row below.
- `typeRow` (TypeSelector with `scrollingRow`, the add-investment form behind the first investment flow): the compact `type` chips in one row that scrolls sideways, 10px apart, 24px in at the start (`rowPadding`) and running to the screen edge so the next chip peeks, 8px above and below for the selected chip's glow. Every chip is at least 48 x 48 (`touch-target-min`; the compact chip alone is 47 tall), its label is not cut, and the row is announced once as "Investment type, 14 choices. Scroll sideways to see all." (`rowSemanticsLabel`). The selected chip is scrolled to the middle when it is not wholly in view, on build and on change; a chip already in view does not move the row. `itemKeyBuilder` gives each chip a key in every layout, for tests and the integration robot.
- `template`: 20px radius, padding 12 x 8, a 16px emoji and a 14px/500 label, fill and border in the template colour at 10% and 30%.
- `theme` (ChipTheme): `radius-sm` 8, padding 12 x 8, 12px label, `neutral-100-light` or `neutral-800-dark` fill, selected `primary` at 15% (25% dark).

## Consumer provides

`label`, `count`, `selected`, `icon` (ligature), `color` (CSS colour, `var(--inv-...)`), `emoji`. Selection state is held by the app; one `selected` per group. Each chip is a button with `aria-pressed`; the filter chip reads "Open, 8 items".

## Rules

- Never rely on the fill alone: the selected chip also changes weight (and the checkmark or count where present).
- Keep 8px (`chip-gap`) between filter chips and 10px between type chips (`TypeSelector`'s default, kept by the add-investment screen). The source scrolls the filter row sideways; wrap rather than scroll when there are few. Use the `typeRow` when there are many (14 types) and the form needs the room.
- The filter chip is about 37px tall in the source (12px label at 1.4 line height, 8px padding above and below, a 2px border) with no extra hit area, below the 48dp minimum: add vertical tap area when you build one.

## Contrast

Selected type chips put white on the type colour (1.40:1 gold to 4.83:1 other, all but `other` below 4.5:1); the filter chip's unselected text is `neutral-700-light` on a 5% tint (8.85:1) and white 70% in dark (9.22:1), both on `background`; the dark selected ChipTheme label is 11.45:1. Kept as drawn.

## Source

`type_selector.dart`; `investment_list_filter_tabs.dart`; `overview_empty_state.dart` (`_TemplateChip`); `chipTheme` in `app_theme.dart`.
