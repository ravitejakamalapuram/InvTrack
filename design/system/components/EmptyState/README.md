The placeholder for a list or screen with nothing to show: a large icon, a title, one line of explanation and an optional action; plus the first-run cards on the Overview and the load-error state.

Use it when a list is empty, a filter has no matches, or loading failed. Do not use it for a single missing figure: show `—` or a status.

## Anatomy

- `basic` (EmptyStateWidget): centred column, padding 32 (16 compact). Icon 64px (40 compact) in `text-muted`, optionally on a gradient disc (padding 24 or 16). Title `h3` 18/600 (compact: `body` 16/600) in `text`, message `body` 16 (compact: `caption` 14) in `text-muted`; the title and message are one semantic group read as "Title. Message". Optional text button with a leading icon (default "add") 24px below.
- `demo` (Overview XIRR demo): GlassCard with a tinted disc and a 40px "insights" icon, `h2` title "See Your Real Returns", subtitle "P2P platforms advertise 12%. What did you really earn?", a comparison panel (Advertised `12.0%` then Your XIRR `6.3%`, arrow between, the second in `warning`), and an italic caption. The app animates 12.0% down to 6.3% over 2.5 s; the semantics label reads the final figures once.
- `quickstart`: "Get Started" with two tiles, "Add Manually / Step by step" (`primary`) and "Import CSV / Bulk upload" (`accent`).
- `sample`: a gradient banner: flask icon, "Try Sample Data", "Explore with realistic Indian investments", text button "Try It".
- `error` (OverviewLoadErrorState): a GlassCard with a cloud-off icon 48px in `error` (#ef4444 in light, #f87171 in dark), 12px below it a live-region title "Couldn't load your portfolio" (`h4`, in `text-secondary`), 8px below that "Your data is safe. Check your connection and try again." (12px, `neutral-500-light`; `neutral-500-dark` in dark), 16px below that a filled `Retry` button with a refresh icon. It deliberately offers no add, import or sample-data action: the account may hold data and sample data would be written into it.

## Consumer provides

`icon` (Material ligature), `title`, `message`, optional `actionLabel` and `actionIcon`, `compact`, `disc` (two colours). Copy comes from `app_en.arb`: say what is missing, then how it fills.

## Rules

- One primary action at most.
- The title names the absence ("No investments found"), the message names what will appear ("Investments you archive will appear here").
- An error state never offers actions that write data.

## Contrast

`text-muted` on `background` is 5.86:1 (light) and 7.85:1 (dark); the 12px error message is 6.12:1 on the light card and 4.74:1 on the dark card (#89827c); the `accent` "Try It" button is 2.77:1 on `card` in light. Kept as drawn.

## Source

`empty_state_widget.dart`; `overview_empty_state.dart` (`OverviewEmptyState`, `OverviewLoadErrorState`); `app_en.arb`.
