Loading placeholders that mirror the real layout: hero, investment card, cash-flow row, stats cards, section cards, and the full-screen loading view.

Use a skeleton instead of a spinner when the shape of the content is known. Use the full-screen view only when nothing else is on screen.

## Anatomy

- Shimmer: `ShimmerEffect` paints its child with a base-highlight-base sweep every 1500 ms (`shimmer-base` and `shimmer-highlight`: light #e2e8f0 and #f8fafc, dark #1e293b and #334155) using `BlendMode.srcATop`, so the card fill and the bars take the same hue. This preview draws the bars slightly stronger than the app so the layout stays readable. The semantics label is "Loading content" (or "Loading investment", "Loading summary"). Stop the animation under `prefers-reduced-motion`.
- Boxes: radius = height / 3; colour `neutral-200-light` in light, white 15% in dark (white 15% on the hero).
- Investment card: 48px tile placeholder (12px radius) with lines 140x16 and 100x12, and 80x16 and 50x12 on the right. Cash flow row: 40px tile with 80x14 and 100x12 and a 70x18 box. Stats: three cards with a 36px tile and 60x20 and 50x12. Section card: a 140x16 title and a block of height minus 60.
- Full screen (`FullScreenLoading`): a pulsing 48px wallet icon on a gradient disc (`primary` 20% to 5%), a 32px spinner (stroke 3) in `primary`, and an optional 14px `text-muted` message.

## Consumer provides

`kind`, optional `height` and `message`.

## Rules

- A skeleton has the same outer size as the content it stands in for, so nothing jumps.
- Announce loading once (a live region), not per box.
- Never show a skeleton as data: no numbers, no 0.

## Contrast

Skeletons carry no information; they only need to be visible against the page (`shimmer-base` on `card` is 1.23:1 in both themes: visible, not readable, by design).

## Source

`loading_skeletons.dart`; `premium_animations.dart` (`ShimmerEffect`, `PulseAnimation`).
