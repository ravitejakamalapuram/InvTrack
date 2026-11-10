# Current value by weight (#946)

Mock of the "Current Value" dialog for a gold investment. It extends the existing dialog (`CurrentValueDialog`); no new screen, no new token, no new shared widget.

## States

Total (default, unchanged):

```
Current Value
[ Value in INR            ]
  Enter weight and price instead      <- text button, gold only
  (calendar) Value as of 3 Nov 2026
                [Remove] [Cancel] [Save]
```

Weight and price (after tapping the text button):

```
Current Value
[ Weight                  ]  10
[ Unit                   v]  gram
[ Price per gram in INR   ]  6,000
  Total: INR 60000.00                 <- echo of what was typed
  Enter total value instead
  (calendar) Value as of 3 Nov 2026
                [Remove] [Cancel] [Save]
```

## Rules

- Offered only for the Gold/Commodities type, and only while dated valuations are on, because the weight is stored with the dated valuation. Otherwise the dialog is exactly as before.
- Units: gram, kilogram, troy ounce, tola, sovereign (8 g). The label of the price field follows the unit ("Price per tola in INR").
- The total is derived (weight x price, rounded once to the currency's minor unit) and never typed. Changing weight, unit or price updates it; leaving weight mode returns to a plain total.
- Error (one message under Weight): "Enter a weight above 0 and a price."
- Copy is sentence case for fields and messages, per the voice rules in `system/README.md`. The text buttons use the existing `TextButton` style; fields use `AppTextField`/`InputDecoration` defaults as the total field does.
- Accessibility: each field has its own label (Weight, Unit, Price per gram in INR); the toggle is a button whose label names the action; the total is plain text a screen reader reads in order.
- Privacy mode: this is an entry dialog; like the existing value field it shows what the user is typing. The total is only an echo of those two typed numbers.
