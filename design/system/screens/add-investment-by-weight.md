# Add investment by weight

Mock of the existing add investment form (first investment flow) for Precious metals. No new screen, token or shared widget: the Weight row is the one from Add cash flow by weight (`WeightEntryRow`, now shared by both screens).

## Layout (type Precious metals)

```
Type        [..] [Precious metals] [..]
Metal       (Gold) (Silver)
Name        [ Coins                          ]
Amount      [ INR  300000                    ]   <- what you paid, as today
Weight      [ 50            ] [ gram       v]   <- new, optional
  About ₹6,000.00 per gram                       <- hint, only when both are typed
Start date  11 Oct 2026
More details
            [ Add investment ]
```

## Rules

- The Weight row shows only for Precious metals. Other types are unchanged and never send a weight, even if one was typed before the type was changed.
- Weight is optional. With an amount it is saved on the first cash flow (a purchase) with its unit, in the same write. Gram is the default; the unit list is the same as Add cash flow.
- The amount is the purchase price. It is never calculated from the weight (making charges and GST). The hint is only amount divided by weight.
- A weight with no amount is an error under the field ("Add the amount you paid to save the weight"): a weight lives on a cash flow, so it is never dropped silently.
- Why it matters: with a weight, the gold and silver rate card on the investment page works straight away.
- Privacy mode: the fields show what the user types, like Amount.
- Copy is sentence case, as in `system/README.md`.
