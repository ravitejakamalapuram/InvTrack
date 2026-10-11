InvTrack tracks alternative investments (fixed deposits, P2P lending, bonds, gold, chit funds, property, private equity, angel deals) as cash flows (`INVEST`, `RETURN`, `INCOME`, `FEE`) and turns them into XIRR, MOIC, goals and a FIRE number. It is an Android app (Flutter and Firebase), India first: the rupee, lakh and crore, the April to March financial year, with 40+ currencies supported. People enter real money here, so every screen answers to three things before looks: the number is right, the number can be hidden, and an unknown number is never shown as a made-up one.

Build with `tokens.json` for values, `components/` for the pieces, and the rules below for what each screen must do. Components are plain HTML/CSS equivalents of the Flutter widgets (`components/bundle.js` and `bundle.css`, global `InvTrack`), made for mock-ups and specs; the product itself is Flutter.

## Content fundamentals

**Voice.** Plain, calm and exact. Address the person as "you" or "your", never "we" for ordinary UI. State what is known and what is not; never hype a return.

- Real copy: "See Your Real Returns", "Your data is safe. Check your connection and try again.", "Add a payout or current value to calculate", "Platform fees and one defaulted loan cut 12% to 6.3% a year.", "Track investments. Grow wealth."
- Say what is unknown, then what fixes it: `Awaiting first payout`, `Awaiting current value`, `No current value yet`, "Add a payout or current value to calculate".

**Casing.** Title Case for buttons, screen and section titles and dialog titles: "Add Investment", "Get Started", "Try Sample Data", "Sort By", "Delete Investment?". Sentence case for messages and captions: "Archived goals will appear here". ALL CAPS only for state chips: `CLOSED`, `MATURED`, `MATURES TODAY`, `12d TO MATURITY`. Acronyms stay upper case: `XIRR`, `MOIC`, `FY`. Metric labels are short noun phrases: "Net cash flow so far", "Realised XIRR", "Expected XIRR", "Net Position".

**Spelling.** English with Indian conventions: "Realised XIRR" (`app_en.arb`), "annualised". hero_card.dart still hard-codes the US spelling "Realized" (title, toggle, semantics); use "Realised" in new copy.

**Errors and empty states.** Name what happened, say what is safe, say what to do: "Couldn't load your portfolio" / "Your data is safe. Check your connection and try again." / button `Retry`. Short, specific, no blame: "Could not save the current value. Try again." An empty state's title says what is missing ("No investments found"); its message says how it fills ("Investments you archive will appear here").

**Destructive actions** state the consequence in the dialog: "This will permanently delete this investment and all its transactions. This action cannot be undone." Name the verb on the button (`Delete`, `Archive`, `Unarchive`), never "OK".

**Emoji.** Not in product copy. Legacy only: the quick-template chips, the sample-data toast and some notification titles. Do not add more.

**Numbers.** The base-currency symbol goes only on base-currency amounts. Use the formatters in `lib/core/utils`, never hand-built strings.

| Kind | Format | Examples |
| --- | --- | --- |
| Full amount, INR | lakh grouping, symbol first, no decimals in lists | `₹1,00,000`, `₹8,70,000` |
| Exact amount | two decimals | `₹3,25,000.00` |
| Compact, INR | from one lakh: `L` (lakh) then `Cr` (crore), a space before the unit, at most two decimals, trailing zeros dropped | `₹99,999` · `₹1 L` · `₹99.95 L` · `₹1.05 Cr` · `₹1,000 Cr` |
| Compact, other currencies | K, M, B, T with no space, the locale's separators | `$1.23M` |
| Negative | sign before the symbol | `-₹5.5 L`, `+₹14,800` for a change |
| Percent | one decimal | `12.4%`, `+7.2%`; the large and small badges use two: `+12.40%` |
| XIRR | one decimal; above 1000% `>1000%`; approximate `7.2% approx.`; estimated `Expected XIRR` | `11.4%` |
| Short holding | absolute return with its span, annualised value second | `+2.0% in 3 days`, `annualised +31.0%` |
| MOIC | two decimals and `x` | `1.07x` |
| Duration | `1.1y`, `8mo`, `<1mo` | |
| Unknown | an em dash or a status, never `0%` | `—` |
| Date | `MMM d, y`; `19 Dec 2025` in day-first mode; no times; cash-flow dates are date-only | `Dec 19, 2025` |
| Relative | `today`, `yesterday`, `3 days ago`, `1 week ago`, `2 months ago` | |
| Financial year | the half-open range [1 Apr, next 1 Apr) | `FY 2025-26` |
| Counts | ICU plurals | `1 entry`, `9 entries`, `under a day`, `3 days` |

Screen readers hear the same figure as sighted users read it, in lakh and crore: `₹1,05,05,000` reads "1.05 crore rupees" and `₹99,999` reads "99,999 rupees" (`AccessibilityUtils.formatCurrencyForScreenReader`).

## Product rules that decide the UI

These come from the project's money and privacy rules; breaking one is a bug even if it looks right.

1. **Privacy mode hides every amount**, including return %, XIRR and the subtitle under a value, and also the screen-reader label ("Hidden amount"), notifications and share text. Wrap every amount in `PrivacyMask` or `MaskedAmountText` (`CompactAmountText` masks itself); percentages fade to opacity 0 but keep their space so the layout does not jump.
2. **An open investment with no value never shows 0% or -100%.** XIRR, MOIC and return % need a current value. Without one show the neutral status `Awaiting first payout` (nothing received yet) or `Awaiting current value` (some payouts, less than invested), in `text-secondary`, never red or green. On an investment card the status comes with what was invested and received ("₹4 L invested", "₹2.52 L received") and no net figure, minus sign or percent; elsewhere a figure that cannot be calculated shows `—`. The open-investment net is labelled "Net cash flow so far"; a closed one is "Net Position".
3. **One currency per figure.** Amounts are converted to the base currency before they are summed. Totals show only the base symbol and carry the disclosure "All amounts shown in ₹ (INR)". A foreign amount shows its own `CurrencyBadge`. Never default a missing currency to USD.
4. **One implementation per metric.** Invested, returned, net, XIRR, MOIC and current value come from `lib/core/calculations`. A screen formats them; it never re-derives them.
5. **Archived investments are not in totals, goals or FIRE, and the UI says so** where it matters: "Archived · not counted", "Archived investments are not counted in goal progress."
6. **Every tappable element is at least 48 x 48dp** (`touch-target-min`), and text meets 4.5:1 (3:1 for text 24px and larger, borders, focus rings and icons that carry meaning). Text scaled to 1.8x must not overflow at 320dp (the hero card tests pin this): use `Wrap` instead of a `Row` with a `Spacer`, `Flexible` with ellipsis for names, put long status text below the amount, never in the same row as it.
7. **Never colour alone.** Direction is an arrow, a sign or a word as well as green or red. Status chips carry text. Types carry an icon and a name (several share a colour).
8. **All user-facing text lives in `lib/l10n/app_en.arb`.** Several widgets still hard-code English ("Sort By", "Select All", "Hidden amount"); new text goes in the ARB file.

## Visual foundations

**Colour.** Warm stone neutrals (`neutral-*`) under one deep indigo-violet brand colour, `primary` (#5b4cdb in light, #8b7cf6 in dark). Status colours are emerald `success`, coral `danger`, amber `warning`; `accent` is sky blue. Light: `background` #fafaf9, `card` #ffffff, `surface` #f5f5f4, text `text` #1c1917. Dark: `background` and `surface` #0a0a0a, `card` #171717, `text` #fafaf9. Use role tokens (`text`, `text-muted`, `card`, `outline`) in components; the `neutral-*` ramps are for reference. The three text greys in light are `text-secondary` #57534e, `text-muted` #66615c and `text-subtle` #746e6a (7.63, 6.12 and 5.02:1 on `card`), each 1.2:1 or more from the next (about 5 apart in CIEDE2000 between muted and subtle), so size and weight carry the hierarchy as much as the grey. In dark, `text-muted` is `neutral-400-dark` #a8a29e and `text-subtle` is `neutral-500-dark` #89827c (5.23:1 on #0a0a0a); the light greys are no longer the same hex as their dark twins. The hero is the only large colour field: `gradient-hero` (violet) in light, `gradient-hero-dark` (deep indigo to plum) in dark. Gradients also fill the swipe actions (`gradient-danger`, `gradient-archive`, `gradient-success`) and the GradientButton.

**Light values in dark mode.** Text and icons on the investment card and detail screen, the Overview, the cash-flow rows, the text field (focus ring and error outline), the confirm dialog, the Cash In and Out chart (bars and legend), the "Copied to clipboard" snackbar fill, the status icons and text, snackbars and destructive buttons of the Settings, Data & Account, Goals and FIRE screens, and the MetricTile change line read the dark value in dark mode (`success`, `danger`, `warning`, `accent`, `primary`, `text-muted`); a tint made from the same colour follows it, and tints and fills that stand alone keep the Light value. Still painted in both themes: ChangeBadge (`#10b981` on `#d1fae5`, `#ef4444` on `#fee2e2`; no screen uses it; only an outlined zero badge, which has no fill, reads the theme and paints `neutral-500-dark` in dark), the GradientButton and filter-chip fills (a white label sits on them), `graph-emerald` profit text, the onboarding page gradients, the Success and Error swatches of the theme preview, the import-warnings snackbar (amber fill, fixed dark text), the goal status colours (`GoalStatusUI`: grey, slate, blue, emerald and amber) on the goal card's status line and the goal details status icon and text, the Settings tiles that pass no icon colour (they default to `primary`), and `primary` icons elsewhere (the add-investment form, the Overview analytics and quick-stat tiles, the sort and attach-document sheets). The other snackbars are themed (`success`, `error`, `primary`), but their message text is `card`-coloured: white in light, #171717 in dark. The components here reproduce that: `--it-*-l` values in `bundle.css` for what is still painted in both themes, the role tokens for what is themed. Fix it in the Dart widget first, then in the token.

**Type.** Plus Jakarta Sans for headings and numbers, Inter for text and controls (`type.groups`). Display, `h1` and `h2` use negative letter-spacing; `label` +0.1px, buttons +0.2px (`button-small` +0.3px), `tiny` +0.5px. Sizes: 48/36/28 display, 24/20/18/16 headings, 18/16/15 body, 14/13 labels, 12 small, 10 tiny. The repository bundles Inter at 400, 500 and 600 only (what golden tests and an offline start use); online `google_fonts` fetches the other weights, so 700 text in the app is real Inter Bold, while these previews render it at the nearest bundled weight. Plus Jakarta Sans is loaded from Google Fonts (the app does the same through `google_fonts`); the four `PlusJakartaSans-*.ttf` files in the repository are a saved GitHub "Page not found" page, not font data, so none is bundled here.

**Spacing.** An 8px grid with 4 and 12 and 20 as in-between steps: `space-xxs` 4, `space-xs` 8, `space-sm` 12, `space-md` 16, `space-lg` 20, `space-xl` 24, `space-xxl` 32. Forms pad 24 horizontally (`screen-padding-x`); Overview, Investments, Investment detail and Goals share one edge, `screen-edge` 16 (`screen-padding-compact` is its alias). Sections are 24 apart (`section-gap`), list cards 12 (`list-item-gap`), form fields 20 (`form-field-gap`).

**Screen edge and FAB clearance.** On Overview, Investments, Investment detail and Goals the app bar title, the first and last app bar chip, section headings, the hero, cards and notes all start on `screen-edge` (16), measured at 360 and 411dp and text sizes 1.0, 1.3 and 2.0. A widget placed in a screen body adds no horizontal margin of its own: the screen's `ScreenSliver` or `ScreenEdge` (`lib/core/widgets/screen_layout.dart`) owns the edge, so nothing is inset twice and a heading cannot sit at 32. App bar actions are 36px tonal chips (`tonal-action-chip`, `TonalIconAction`) in 48dp buttons, so the first and last chip sit on the edge and the transparent 48dp box hangs 6 into the gutter. Every screen with a floating action button ends its scroll with `fab-bottom-padding` (80: the 56px button, its 16px margin and 8) plus the bottom inset (`AppSpacing.fabClearance`), so the last item can be scrolled fully clear of the button. Insets are directional (`EdgeInsetsDirectional`) so they mirror in right-to-left layouts, and a heading and its badge use a `Wrap`, not a `Row`, so the badge drops below the title at large text sizes. Other screens (Settings, Reports, Goal details, FIRE, Portfolio health, the income screens) still set their own edge, mostly 16 and in places 20 or 24; moving them onto `ScreenEdge` is follow-up work, and forms keep `screen-padding-x` (24). Test-enforced: `test/layout/edge_guard_360_test.dart` and `edge_guard_411_test.dart` measure the four screens at text x1.0, x1.3 and x2.0; the 411dp file also measures their other states (new account, failed load, only archived investments, a deletion request, no goals, the archived goals tab, search and a type filter) and a run over a 48dp system bar. `test/repo/fab_clearance_scan_test.dart` fails any screen below `presentation/screens` that declares a floating action button without the clearance in the same class, or that `test/layout/guarded_screens.dart` does not list, and `test/repo/design_tokens_layout_test.dart` ties these tokens to the Dart constants.

**Radius.** Soft and consistent: `radius-badge` 6 for chips on cards, `radius-sm` 8, `radius-md` 12 for buttons and snackbars, `radius-field` 14 for inputs, `radius-lg` 16 for MetricTile and swipe backgrounds, `radius-xl` 20 for cards, sheets, dialogs and filter pills, `radius-xxl` 24 for the hero, `radius-full` for circles.

**Surfaces, borders, shadows.** Cards are "glass": `glass-fill` (white 90% or #171717 80%) with a hairline `glass-border`, 20px radius, 16px padding, no shadow (GlassCard strips the card shadow in code, so cards are flat; `shadow-card` exists but is not painted). Lists use blur 0. Elevation comes only from coloured glows: `shadow-hero` under the hero, `shadow-button-gradient` under the GradientButton, a type-coloured glow under a selected type chip. Hairlines are faint (about 1.2:1): separate cards by spacing and fill.

**Imagery and decoration.** No photographs or illustrations. Icons sit in tinted discs (`color @ 10%`). The hero carries two faint white glow circles (10% and 5% in light, 3% and 2% in dark). Do not add patterns, mascots or emoji.

**Motion.** Quick and quiet: 180 to 300 ms ease-out for chip, switch and privacy transitions, a 1.5 s shimmer on skeletons, haptics on select and toggle. Honour `prefers-reduced-motion` in HTML.

**Focus and states.** Focus is a 2px border: `focus-ring` on GlassCard (`primary` in light, `primary-container` in dark), the neutral-900 or white border on filter chips. Selected is filled (`primary` pill, type-coloured chip). Loading is a spinner in the button or a skeleton that mirrors the layout. A disabled GradientButton keeps its gradient in the source; do not rely on it to look disabled.

**Layout.** One column on a phone. Overview order, 24px apart: sample-data banner (when active), hero card, health score, goals, FIRE progress, quick stats, net-position breakdown, then the trend, type, year-on-year and recently-closed sections. Detail screens: Net Position card, Current value card, out/in strip, XIRR and MOIC pair, Maturity card, 10px apart. Bottom navigation has four destinations (Overview, Investments, Goals, Settings), five when the Reports tab flag is on, in a 70px NavigationBar.

## Iconography

Icons are Material icons from the Flutter SDK's `MaterialIcons` font, almost always the rounded set (`Icons.account_balance_rounded`); the bottom navigation uses the baseline set (`pie_chart_outline` / `pie_chart`) and the outlined set, and the sort sheet's option icons are baseline too (`schedule`, `payments`). They are font glyphs, not files in the repository. The previews load the same glyphs from Google Fonts (Material Icons Round, Outlined and baseline) by ligature name (`account_balance`, `trending_up`, `visibility_off`). Sizes come from `icon-xs` 16 to `icon-display` 64; the standard is `icon-md` 24 (12 inside a badge, 14 beside a stat, 28 in the net-position tile, 48 to 64 in empty states). Colour follows meaning (`text-muted` for chrome, `success` and `danger` for money in and out). Investment types:

| Type | Icon | Token |
| --- | --- | --- |
| P2P Lending | `handshake` | `inv-p2p-lending` |
| Fixed Deposit | `account_balance` | `inv-fixed-deposit` |
| Bonds/Debentures | `description` | `inv-bonds` |
| Real Estate | `home` | `inv-real-estate` |
| Private Equity | `business_center` | `inv-private-equity` |
| Angel Investing | `rocket_launch` | `inv-angel-investing` |
| Chit Funds | `group` | `inv-chit-funds` |
| Gold/Commodities | `monetization_on` | `inv-gold` |
| Crypto | `currency_bitcoin` | `inv-crypto` |
| Mutual Funds | `pie_chart` | `inv-mutual-funds` |
| Stocks | `show_chart` | `inv-stocks` |
| Invoice Discounting | `receipt_long` | `inv-invoice-discounting` |
| Financing | `payments` | `inv-financing` |
| Other | `attach_money` | `inv-other` |

**The app mark** is the "Portfolio ring", kept in `assets/icons` of the app repository (`app_icon.svg`, `app_icon_foreground.svg`, `app_icon_monochrome.svg` and their PNG exports); read `assets/Logos/README.md` before using it, because the copies in that group are the old mark. Never redraw, recolour or crop it.

## Using the components

- Load `tokens.css` (generated), `components/bundle.css` and `components/bundle.js`, then call `InvTrack.<Component>(props)`; each returns an HTML string. `InvTrack.fmt` mirrors the Dart formatters, `InvTrack.amount(text)` makes any figure privacy-aware.
- Set `data-theme="light"` or `"dark"` on an ancestor; set `data-privacy="on"` on an ancestor to mask amounts.
- Load Inter from `fonts/`, Plus Jakarta Sans and the Material icon fonts from Google Fonts (links are in every preview).
- The consumer supplies the display strings. Components format nothing and compute no metric.

## Contrast

Where the source's colours miss 4.5:1 they are kept as drawn and flagged in the token's usage note. The pairs that matter (light unless stated):

| Pair | Ratio | Where |
| --- | --- | --- |
| `success` on `card` · on `success-bg` | 2.54 · 2.24 | positive amounts, ChangeBadge |
| `danger` on `card` · on `danger-bg` | 3.76 · 3.08 | negative amounts, error text |
| `warning` / `accent` on own 15% tint | 1.91 / 2.39 | maturity chips |
| snackbar message on `success` · `danger` | white 2.54 · 3.76 in light; #171717 on the dark fills 9.33 · 6.48 | success and error snackbars |
| white snackbar icon on the dark `success` · `danger` · `primary` fills | 1.92 · 2.77 · 3.33 | icon only; the message carries the meaning |
| white on #8b7cf6 (`primary-container` light) | 3.33 | light primary container |
| type chip text on its 10% tint | 1.35 to 4.27 (dark 3.37 to 10.27) | investment card |
| white on a type colour | 1.40 to 4.83 | selected type chip, type tile |
| hero text white at 80% / 60% / 50% | 4.45 to 3.97 / 3.20 to 2.85 / 2.70 to 2.40 | hero title, notes, currency line |
| hero return badge `#ff5252` on red 30% | 1.62 to 1.83 | negative return on the hero |
| `field-border` / `outline` / `glass-border` | 1.26 / 1.49 / 1.12 | field and card edges (3:1 asked) |
| `primary` light value on dark #0a0a0a / #171717 | 3.30 / 2.99 | filter chips and GradientButton in dark (a white label sits on the fill, 6.00), icons and text on the Settings, Goals and onboarding screens, and icons in the add-investment form, the Overview analytics and quick-stat tiles, and the sort and attach-document sheets; the field focus ring and the card's View Details use `primary` dark, 5.95 / 5.39 |

Fixing a pair means changing the Dart widget and the token together; prefer adding a darker text tone to darkening the fill.

## Not in this system

Not built: swipe wrappers (`SwipeActions`, `SwipeToDelete`; their gradient backgrounds are in GradientCard), selection controls and action bar, `CurrencySelector`, the connectivity toast, the ads widgets (the SDK is being removed), the animation helpers other than the shimmer (counter, stagger, pulse, float, glow, gradient border), and the `InAppUpdate` and `CurrencyCache` initialisers (no UI).
