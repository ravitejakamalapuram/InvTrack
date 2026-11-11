# Add cash flow by weight (#946)

Mock of the existing Add Cash Flow screen (`AddTransactionScreen`) for a gold investment. No new screen, token or shared widget.

## Layout (gold, Invest or Return)

```
Type        [Invest] [Return] [Income] [Fee]
Date        3 Nov 2026
Amount      [ INR  64500.00                 ]   <- still typed by the user
Weight      [ 10            ] [ gram       v]   <- new, optional
  About ₹6,450.00 per gram                      <- hint, only when both are typed
Notes       [                               ]
Currency    INR
            [ Save Cash Flow ]
```

Gold investment page, under the Transactions/Income/Documents tabs, only when at least one cash flow has a weight:

```
Gold held: 12.5 g                               <- purchases minus sales
```

## Rules

- The Weight row shows only for the Gold type on Invest and Return. Income and Fee never carry a weight. Other investment types are unchanged.
- Weight is optional. Empty means no weight; entries made before this change keep working. A weight must be above 0.
- The amount is never calculated from the weight. Making charges and GST mean it is not weight times price. The hint is only amount divided by weight.
- Units: gram (default), kilogram, troy ounce, tola, sovereign, the same list and names as the Current Value dialog.
- "Gold held" counts only flows that have a weight; it is never below 0 and is hidden when no flow has a weight.
- Privacy mode: the entry fields show what the user types, like Amount. "Gold held" is masked with the same dots as amounts, including its screen-reader label.
- Accessibility: Weight and Unit have their own labels; the hint is plain text read in order.
- Backup: weight and unit are two extra columns (Quantity, Unit) in cashflows.csv; older files without them still import.
- Copy is sentence case, as in `system/README.md`.
