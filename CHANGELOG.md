# Changelog

## [Unreleased]

### ✨ Features

- **notifications**: Ask for notification permission after the first investment with a maturity date
- **offline**: Show an offline banner and name the real cause of load and export failures

### 🐛 Bug Fixes

- **reports**: Explain XIRR, MOIC and Net Position, show the real financial year
- **investments**: Let long investment names wrap to two lines on narrow phones
- **overview**: Show progress and failure feedback when retrying a failed load
- **accessibility**: Read the investment card's net cash, not a current value

## [3.84.4] - 2026-10-18

### 🐛 Bug Fixes

- **reports**: Leave holdings awaiting a value out of the FY and performance reports
- **a11y**: Screen readers say the holding period in words; fee-only holdings await first payout
- **goals**: Goals that fail to load now say so and offer Retry
- **backup**: Export and restore every investment field, matched by id
- **currency**: AED/SAR rates from USD pegs, safe rate parsing, keep FX cache on currency switch

## [3.84.3] - 2026-10-17

### 🐛 Bug Fixes

- **insights**: Stop raising a declining alert for open holdings from cash alone

## [3.84.2] - 2026-10-17

### 🐛 Bug Fixes

- **currency**: One missing exchange rate no longer blocks the other conversions
- **a11y**: Read hidden-amount screen-reader labels from translations

## [3.84.1] - 2026-10-17

### 🐛 Bug Fixes

- **accessibility**: Readable snackbar, archive swipe and hero info icons
- **accessibility**: Visible outlines on text fields, outlined buttons and chips
- **accessibility**: Readable hero card text and chart-coloured figures in light mode

## [3.84.0] - 2026-10-13

### ✨ Features

- **cash-flow**: Warn when a cash flow's currency differs from its investment's

### 🐛 Bug Fixes

- **currency**: Stop new investments, cash flows and goals defaulting to US dollars
- **goals**: Refuse goal targets of 16 digits or more, like every other amount
- Bundle the real headline font and let a worked-out maturity date be cleared

## [3.83.1] - 2026-10-12

### 🐛 Bug Fixes

- **backup**: Keep guessed currencies out of backups so old records restore in your own currency
- **accessibility**: Readable currency badge, buttons, goal status and portfolio health colours
- **investment**: Refuse amounts of 16 digits or more in cash flows and current values

## [3.83.0] - 2026-10-12

### ✨ Features

- **settings**: Unlock the feature flags screen in release builds by tapping the app version five times

### 🐛 Bug Fixes

- **valuations**: Remove dated valuations left behind by an offline investment delete
- **cash-flow**: Stop adding cash flow to an investment that was closed
- **settings**: Leaving Settings during a currency change no longer crashes the app
- **notifications**: Stop income reminders for FDs that pay no income before maturity

## [3.82.0] - 2026-10-12

### ✨ Features

- **investments**: Add an investment with an amount and start date in one step

### 🐛 Bug Fixes

- **help**: Stop calling Income Guardian AI-powered and lead the FAQ with FDs, P2P, bonds, chit funds, gold and property
- **reports**: Open the add investment form from an empty report
- **help**: Stop telling users to enable Portfolio Health in Debug Settings
- **accessibility**: Make investment-type colours readable in light and dark
- **accessibility**: Make blue and amber text readable in light mode
- **accessibility**: Make gain and loss colours readable in light mode

## [3.81.1] - 2026-10-11

### 🐛 Bug Fixes

- **accessibility**: Make grey captions and hints easier to read
- **theme**: Use the dark-mode colours on the Goals, FIRE, Settings and account screens
- **layout**: Line up the figures in the hero, goal cards and detail tiles
- **investments**: Stop templates filling in a rate and term you never typed

## [3.81.0] - 2026-10-11

### ✨ Features

- **investments**: Save an investment and its first cash flow together

### 🐛 Bug Fixes

- **theme**: Use the dark-mode colours where screens ignored the theme
- **layout**: One screen edge and a clear Add button on the main screens

## [3.80.0] - 2026-10-11

### ✨ Features

- **investment**: Show invested and received on a card awaiting its current value
- **brand**: Ship the Portfolio ring app icon

### 🐛 Bug Fixes

- **returns**: Label returns of an open investment with no current value as "so far"


