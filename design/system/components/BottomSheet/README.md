A modal bottom sheet: rounded top, a drag handle, a header with an icon, title and optional Reset, then a list of options.

Use it for a short list of choices that applies to the current screen (sort, pick a currency, pick a document action). Use a `Dialog` to confirm or to collect one value.

## Anatomy

- Surface: `white` in light, `surface` in dark, top corners `radius-xl` 20, over the Material modal barrier (black at 54%). Respect the bottom safe area; leave `space-md` below the list.
- Handle: 40 x 4, 2px radius, 12px from the top, black or white at 20%.
- Header (padding 20): a 24px icon (`neutral-700-light` in light, white in dark), the title in `h3` (18/600, Plus Jakarta Sans) and, when the choice differs from the default, a text button "Reset" in the light-mode primary 600.
- A hairline divider (black or white 10%).
- Options: list tiles (56px tall, 16px sides) with a leading 24px icon, a 16px label and, when selected, a check in the light-mode primary; the selected label is 600 in the same colour. The default option carries a "Default" tag (10px on a 10% fill, 4px radius). Tapping a tile selects it, gives selection haptics and closes the sheet. The Sort By sheet has 16 options (Last Activity; Name (A-Z) and (Z-A); Total Invested, Total Returns, Return %, XIRR and Net Position, each High and Low; Date Created, Newest and Oldest; Maturity Date (Soonest)); their icons come from the baseline Material set (`schedule`, `sort_by_alpha`, `payments`, `percent`, `show_chart`, `trending_up`, `calendar_today`), except `event_rounded`; the header's `sort_rounded` and the check are rounded.

## Consumer provides

`title`, `icon`, `options: [{ icon, label, selected, isDefault }]`, `reset`. The sheet calls back with the choice and closes itself.

## Rules

- A sheet is dismissible by tapping the barrier or the back gesture.
- Long lists scroll inside the sheet (`Flexible` with a scroll view).
- Titles are Title Case and short ("Sort By").
- Never put an irreversible action in a sheet: use a `Dialog`.

## Contrast

The selected label and check use the light-mode primary: 6.00:1 on white and only 3.30:1 on the dark `surface`; the "Default" tag text is `neutral-600-light` on a 10% tint. Kept as drawn. The text "Sort By" and "Reset" are hard-coded English in the source; new sheets must use ARB strings.

## Source

`sort_options_sheet.dart` (`showSortOptionsSheet`, `SortOptionsSheet`); other sheets (`currency_selector.dart`, document sheets) follow the same pattern.
