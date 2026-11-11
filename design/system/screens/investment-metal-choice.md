# Metal choice on the investment form (#946)

Mock of the existing Add and Edit investment form (`AddInvestmentScreen`). No new screen, token or shared widget: a row of two standard choice chips.

## Layout (type Precious metals)

```
Investment type   [... Precious metals ...]      <- the type was "Gold/Commodities"
Metal
  (Gold)  ( Silver )                             <- two choice chips, one always chosen
Name              [ Coins                    ]
```

Investment page and lists: the type chip reads "Gold" or "Silver" for a precious-metals investment that has a metal, and "Precious metals" for one saved before the choice.

Investment page, Transactions tab, when a cash flow has a weight:

```
Silver held: 120 g
```

## Rules

- The type is renamed Precious metals. Its id stays `gold`, so nothing is migrated and old records open as before.
- The Metal row shows only for Precious metals, on add and on edit. Gold is chosen on a new investment. An investment saved before the choice opens as Gold; it is only stored if the user saves the form.
- Changing the type away from Precious metals clears the metal.
- "Gold held" becomes "Silver held" for silver. A record without a metal reads as gold.
- Silver and gold are separate investments: a merge keeps the metal of its first source.
- Backup: `metal` is one more field in investments.json; older files without it still import.
- Accessibility: the chips are Material choice chips, so they announce as selected or not selected, with a 48dp touch target.
- Copy is sentence case, as in `system/README.md`. The names come from the strings file.
