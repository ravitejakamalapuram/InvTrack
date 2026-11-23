# Today's metal rate on a metal investment's page

Mock of an addition to the existing investment page (`InvestmentDetailScreen`), under the "Gold held" line. No new screen, token or shared widget: body text, caption text, a text button and a standard dialog.

## Layout (Overview tab, a metal investment with a weight held)

```
Gold held: 12.5 g
Gold today: ₹12,633.66 per gram
Selling rate in India · 23 Nov 2026
[ Use as current value ]            <- text button, open investments only
```

Tapping the button opens a confirmation. Nothing is saved before it:

```
Set current value?
12.5 g × ₹12,633.66 per gram = ₹1,57,920.75
                         [ Cancel ]  [ Set value ]
```

After "Set value" a snackbar says "Current value updated". The value is saved as a dated valuation of today, weight × price, like one typed in the weight editor.

## Which rate

- A rupee investment shows the **India selling rate** (what a seller receives): "Selling rate in India · date".
- Any other currency shows the **international rate**, converted with the app's live exchange rate: "International rate · date". Never a dollar price under another currency's symbol.
- A rupee investment with no fresh India rate falls back to the international rate.
- No fresh rate (older than 3 days, missing, or no exchange rate) shows nothing: no card, no button.

## Rules

- Only on a gold or silver investment with a weight held. Closed and archived investments see the rate but no button.
- The price per gram is public market data and is shown in privacy mode. The weight and the total are the user's amounts, so the confirmation hides them in privacy mode.
- The saved value is rounded once, to the investment's currency. The investment's own currency is used, never the base currency.
- Accessibility: the rate is one text line, and the button is a Material text button with a 48dp target.
- Copy is sentence case, from the strings file.
