Small cards that show one figure with its label: the bordered MetricTile, the Overview QuickStatCard, the investment-detail mini stat, and the detail screen's net-position, current-value, out/in and maturity cards.

Use a tile for a single headline number. Use `HeroCard` for the Overview headline and `EmptyState` when there is no number yet.

## Kinds (`InvTrack.StatTile({ kind })`)

- `metric` (MetricTile): `card` fill, 1px `field-border`, `radius-lg` 16, padding 16; optional 16px icon in a tinted 8px-radius chip; label `caption` 14 in `text-secondary`; value `number-small` (Plus Jakarta Sans 20/600); optional trend line (14px trend icon, 12px/500, `success` up or `danger` down, the dark value in dark mode) which the screen reader hears as "Trending up +17.6%".
- `quick` (QuickStatCard): two of them side by side (MOIC and Cash flows) sit in a `TileRow` and share a top and a height, whatever the subtitle of one of them needs. A GlassCard, padding 16: a 24px icon in a tinted 12px-radius tile, label 12px (`#757575`), value 18px bold in the inherited body colour (`text-secondary`, not `text`), subtitle 11px (`#9e9e9e`, up to three lines). The subtitle fades out in privacy mode; sensitive values are masked.
- `mini` (detail screen XIRR / MOIC, `StatColumns`): two tiles in one row, GlassCard, content inset 12, centred: label 11px `text-muted`, value 15px/700 in the metric colour (`graph-cyan` XIRR, `graph-purple` MOIC, `text-muted` when unknown), subtitle 10px `text-subtle`. The tiles share a top and a height, the two values share one baseline, and the subtitle sits below the value, so a subtitle on one tile (MOIC's "1.9y") or a label that wraps on the other ("Expected XIRR so far") never moves a value. Put the two in one `.it-two.it-two--stats` so the CSS can share the label, value and subtitle rows.
- `net`: the detail screen's first card: a 28px trend or hourglass icon in a tinted 14px tile, label 12px, value 20px/700 (compact, `formatSmart`), and on the right the return badge or a neutral status chip.
- `current`: label "Current value", the amount, its basis ("Updated Oct 11, 2026", "Estimated at 7% p.a.", "No current value yet") and a text button ("Add current value" / "Update").
- `flows`: arrow-up money out, arrow-down money in, then "N txns" at the end.
- `maturity`: a status icon, "Maturity Date", the date, and a status pill ("Matured 296 days ago", "Matures today!", "21 days until maturity").
- `hero` (HeroMetric): white label 14px, `number-large` 40px value, caption, for use on a gradient.

## Detail-screen arrangement

Net Position card, then (open investments only) the Current value card, then the out/in strip with "Money out includes fees." (or "...Reinvested payouts count once in MOIC and return %."), then XIRR and MOIC side by side, then the Maturity card; 10px apart. With no value yet: the net card shows the neutral hourglass and `Awaiting first payout`, XIRR and MOIC show `—`, the XIRR subtitle gives the hint, and the amount colour is `text-muted`.

## Consumer provides

Formatted strings and colours (`color` as a CSS colour). Never pass an unconverted amount under the base-currency symbol.

## Rules

- Mask the value and subtitle in privacy mode; the label may stay.
- A mini stat (XIRR / MOIC) is one screen reader stop per tile, "XIRR:" then the value then the subtitle ("MOIC:", "1.28x", "2.2y"), or the one sentence a "so far" figure needs; in privacy mode the value reads "Hidden amount".
- Positive and negative differ by icon and sign as well as colour.
- A value that cannot be calculated is `—`, never `0`.

## Contrast

The metric colours used as text on `card` are low in light: `graph-cyan` 2.43:1, `graph-emerald` 2.54:1, `graph-purple` 3.96:1 (dark 4.53:1); `text-subtle` subtitles 2.52:1; the QuickStat subtitle (`#9e9e9e`) 2.68:1 and its label (`#757575`) 3.89:1 on the dark card. Kept as drawn.

## Source

`metric_tile.dart` (`MetricTile`, `HeroMetric`); `quick_stat_card.dart`; `investment_detail_stats_section.dart` (the XIRR / MOIC tiles built on `stat_columns.dart`, net position, current value, cash flow summary, maturity; the current-value, cash-flow and maturity lines drop their last item below at large text instead of overflowing).
