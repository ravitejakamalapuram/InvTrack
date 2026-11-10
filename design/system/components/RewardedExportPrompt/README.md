A standard Material alert dialog that asks whether to watch one short rewarded ad before the Tax-Year CSV export. It uses the app's normal dialog styling; no new widget.

## Rules

- Shown only when `AdPolicy.mayOffer` allows it: after the first 7 days, at most 3 ads a day, never while Privacy mode is on.
- "Watch ad" plays one non-personalised Google AdMob rewarded ad. If the user watches it to the end, the export goes ahead. If the ad cannot load or show, the export goes ahead without it.
- "Not now" or tapping outside closes the dialog and does not export.
- The text shows no amounts, names or investment details.
- Analytics: `rewarded_prompt_shown`, `rewarded_prompt_declined`, `rewarded_ad_earned`, `rewarded_ad_dismissed`, `rewarded_ad_unavailable`, each with only `placement` = `fy_export_csv`.
- It is the only ad spot in the app. Never on Overview, investment detail, goals, FIRE, add-investment or the first-investment flow.
