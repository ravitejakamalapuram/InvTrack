The app's default card: a translucent fill with a hairline border and a 20px radius, optionally tappable, with a 2px focus border.

Use it for every grouped block of content except the hero (`HeroCard`) and the bordered MetricTile. Stack cards 12px apart in lists and 24px apart between sections.

## Anatomy

- Fill: `glass-fill` (white at 90% in light, #171717 at 80% in dark); border 1px `glass-border`; radius `radius-xl` 20; padding 16 (`space-md`), 20 for large; no shadow in practice (the card shadow is computed and then removed in code).
- Blur: a 10px backdrop blur. List items pass blur 0, which skips the BackdropFilter and its offscreen pass; their fill is already solid.
- Tappable: the card becomes a button (ink ripple, light haptic on Enter or Space); focus replaces the border with a 2px `focus-ring` (`primary` in light, `primary-container` in dark). Give it a `label` when its text children would read poorly together: the card then reads the label alone.
- `GlassHeroCard` is the same widget on the hero gradient: see `HeroCard`.

## Consumer provides

The children, `padding`, `radius`, `flat` (blur 0), `tap` and `label`. A tappable card must have an accessible name.

## Rules

- No drop shadow; separate cards with spacing and the fill.
- Do not nest a GlassCard in a GlassCard.
- `gradient_card.dart` declares a second `GlassCard` (white 70% fill, 16px radius, shadow in light); `glass_card.dart`'s is the one the app imports. Prefer it.

## Contrast

The border is 1.12:1 (light) and 1.25:1 (dark) against the card: it is decoration, not the card's boundary. The focus border is 6.00:1 (light) and 8.99:1 (dark).

## Source

`lib/core/widgets/glass_card.dart` (`GlassCard`, `GlassHeroCard`).
