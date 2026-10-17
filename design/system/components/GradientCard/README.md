A card filled with a gradient and a coloured glow, and the gradient backgrounds of the swipe actions.

Use it for a rare highlighted moment. At this commit no screen uses `GradientCard`; only a golden test does, and the Overview hero uses `GlassHeroCard`. The swipe-action backgrounds (delete, archive, unarchive) use the same gradient tokens.

## Anatomy

- Gradient: `gradient-hero` by default in both themes (the widget never reads the theme; `gradient-hero-dark` is `GlassHeroCard`'s dark gradient and reaches a GradientCard only when passed in), or any `gradient-*` token. Topleft to bottomright (use `135deg`).
- Glow (`showGlow`): the first gradient colour at 40% (blur 24, offset 0 8) plus the last colour at 20% (blur 40, offset 0 16): `shadow-glow-hero` for the hero gradient.
- Radius `radius-xl` 20, padding 20; tappable with an ink ripple.
- Swipe backgrounds: `gradient-danger` with a white trash icon at the right for swipe-to-delete, `gradient-archive` (or `gradient-success` for unarchive) with an archive icon at the left (`ink` on the amber, white on the green), `radius-lg` 16, 4px vertical margin.

## Consumer provides

The children, `gradient`, `glow`, `padding`. All text on it is white.

## Rules

- White text only, at 70% or more.
- At most one glowing card per screen.
- Swipe actions are also reachable without gestures: custom semantics actions "Delete" and "Archive" / "Unarchive", each confirmed in a `Dialog`.

## Contrast

White is 6.00:1 to 5.38:1 on `gradient-hero`; on `gradient-success` 3.77:1 to 3.74:1; on `gradient-danger` 4.83:1 to 3.56:1; on `gradient-archive` 2.15:1 (amber) to 3.56:1. The archive glyph sits at the amber start, so it is `ink` there (8.14:1); the trash glyph stays white (4.83:1 at the start of its gradient, 3.56:1 at the end).

## Source

`gradient_card.dart` (`GradientCard`, the duplicate `GlassCard`); `swipe_actions.dart`; `app_colors.dart` (gradients).
