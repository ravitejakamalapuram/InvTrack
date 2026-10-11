A list card for one investment: type tile, name, type and state chips, net cash flow with its return badge (or, while it awaits a value, what was invested and received with a status chip), and a strip with last activity, entry count and the invested amount.

Use it in the investment list, search results and selection mode. For a summary of many investments use `HeroCard`.

## Anatomy

- Surface: `GlassCard` with blur 0 (`glass-fill`, `radius-xl`), zero padding, tappable, 12px (`list-item-gap`) below.
- Main row (padding 16, children hang from the top edge): optional checkbox (selection mode), a 32px type tile (14px radius, gradient from the type colour `inv-*` to 70%, a 24px white icon, soft glow; grey `#9e9e9e` when closed), the info column, and the value column. In selection mode the tile is centred on the checkbox's 48dp target while the name and figures stay on the top edge.
- Stacking is decided by measurement, not by the card's width: the app measures the value column as drawn (its widest line, with the same styles and text scale; the dots in privacy mode, so privacy mode lays out the same whatever the amounts). The name must keep at least 96dp at normal text size (about eleven characters including the ellipsis, 5.3 em of the 18px name), scaled with the text size so it keeps as many characters at 200% text. When it would get less, the value column drops under the name, still on the right edge. A wide figure ("₹12.35 Cr invested") stacks where a short one ("₹4 L invested") stays beside the name. The preview does this with a wrapping flex row and a 96px minimum for the name.
- Info: name (Inter 600 18px, one line, ellipsis), then a wrap of chips 8px apart: the type chip (type colour on its 10% tint), `CLOSED` (grey), or a maturity chip: `MATURED` (success), `MATURES TODAY` and `7d TO MATURITY` or fewer (warning), `8d` to `30d TO MATURITY` (accent). The maturity chip is the icon and the label; on a narrow card or with large text the label wraps to a second line, as the type chip does, and is never shortened or cut (WCAG 1.4.4). Only where a card is narrower than the word itself (selection mode at 280dp with 130% text, or 320dp with 200%) does "MATURITY" break across lines, whole.
- Value column: net cash flow (600 18px) with a `+` or `-` prefix and a compact amount, then the return badge, 10px/600 on its 10% tint: "+7.2% IRR", "+8.1% Expected XIRR" when the value is an estimate, "+2.0% in 3 days" for a short holding. The badge fades out in privacy mode but keeps its space.
- Value column while the investment awaits a value (open, `Awaiting first payout` or `Awaiting current value`): no net, no sign, no percent. A two-row ledger, then the status chip 4px below it, all on one right edge. Row 1 is what was put in (`text` 600 18px, "₹4 L" then "invested"), row 2 what came back ("₹2.52 L" then "received", 500 12px `text-secondary`). The amounts are right-aligned in one column and each word (400 12px `text-secondary`, 4px from its amount) sits on its amount's baseline; the first row has the name's line box, so the name and the invested figure share a baseline. The chip is 12px/600 `text-secondary` on its 10% tint, at most 104dp wide (it wraps to two lines, right-aligned, rather than widen the column). Stacked under the name, the ledger is as wide as its widest line and nothing else limits it, so the app scales it down to the room (on the right edge) rather than let the card clip a figure: a Cr-scale amount in a long symbol ("Rp123,5M", "CHF 123.5M") at 280dp and 200% text draws at about 0.8x. The preview does not scale it. Once received reaches invested the card is no longer awaiting and shows the net and a "so far" badge instead.
- Strip (padding 16 x 12, black or white 3%, rounded bottom corners): "update" icon with the relative last activity, "receipt" icon with "4 entries", 16px apart (4px between lines when they wrap), then at the end "Invested: " and the compact amount; with nothing invested it shows "View Details" in the light-mode primary. A card awaiting a value leaves the invested group out, because the main row shows it. With little room the group joins the flow instead of squeezing it, and its amount scales down to the space rather than wrapping or running past the strip, because a wrapped figure ("CHF 123" over ".5M") reads as another amount.

## States

Closed · Open awaiting first payout · Open awaiting current value · Maturity chips · Selection mode · Privacy mode · No cash flows yet. A positive net cash flow and a positive return badge are `graph-emerald`; a negative net cash flow while a value exists is the light `danger` (#ef4444) in both themes. While the investment awaits a value there is no net to colour: money still invested is not a loss, so the card shows invested and received in `text` and `text-secondary`. With no cash flows yet (`empty`) the value column is a `chevron_right` in `neutral-400-light`: no amount, no badge, and the strip offers View Details.

## Consumer provides

`type` (key of `InvTrack.types`), `name`, `typeName` (custom label), `closed`, `net` (already formatted, base currency), `positive`, `status` (set it while the investment awaits a value; then `invested` and `received` are the main figures and `net` is not used), `received`, `badge: { text, positive }`, `maturity: { tone, icon, label }`, `last`, `entries`, `invested`, `empty`, `selectionMode`, `selected`.

## Rules

- The semantics label reads state, name, type, current value, invested, return (or the status), last activity and maturity, with "Hidden amount" in privacy mode (`AccessibilityUtils.investmentCardLabel`). While the investment awaits a value it has no current value to read: it reads invested, then "Received: ...", then the status ("Open investment: P2P loan pool A. Type: P2P Lending. Invested: 4 lakh rupees. Received: 2.52 lakh rupees. Returns: Awaiting current value. Last activity: ..."), with "Hidden amount" for both amounts in privacy mode.
- Alignment: amounts share one right edge on every card, each word shares its amount's baseline, and gaps come from the spacing scale only (16, 12, 4). The card is one button (48dp minimum); the checkbox keeps its 48dp target. At 320dp and 2x text nothing clips or overflows, with Cr-scale amounts, a maturity chip, selection mode and privacy mode too.
- Privacy mode hides both ledger amounts. The words "invested" and "received" and the status chip are not amounts and stay.
- Type is told by icon and name as well as colour; several types share a hex.
- The tile and chips are decoration for sighted users; the card itself is one button.

## Contrast

Type chip text on its 10% tint fails in light for every type (1.35:1 gold to 4.27:1 other) and for P2P, Mutual Funds, Private Equity, Crypto and Other in dark (3.37:1 to 4.35:1); white on the type tile is 1.40:1 to 4.83:1; the closed chip (`#9e9e9e` on grey 20%) is 2.27:1 in light; maturity chips on their tint are 1.91:1 (warning), 2.19:1 (success) and 2.39:1 (accent) in light; "View Details" is the light-mode primary, 2.99:1 on the dark card. Kept as drawn; the labels carry the meaning.

## Source

`investment_card.dart`; `investment_ui.dart` (type icon and colour); `glass_card.dart`; `change_badge.dart`; `privacy_mask.dart`; `compact_amount_text.dart`; `return_display.dart`.
