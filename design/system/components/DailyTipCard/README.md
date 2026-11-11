A quiet card on the Overview with one short money-learning tip a day. Content is education only, never a recommendation to buy or sell.

## Anatomy

Same shape as `GuestLinkBanner`: 12px radius, 8px vertical margin (the screen owns the horizontal edge), padding 16, `primary` tint fill (8% light, 15% dark) and a 1px `primary` border at 40%. Left to right: a 22px `lightbulb_outline` icon in `primary`; a column with the label "Tip of the day" (`bodySmall`, 600, `primary`), the tip title (`bodyMedium`, 600; the theme does not define `titleSmall`, so it would fall back to Roboto), the tip body (`bodySmall`) and the line "Education, not investment advice." (`bodySmall`, 70% opacity); a 48dp close button (tooltip "Dismiss"). Placed on the Overview under the FIRE progress card, above the quick stats. It never pushes the hero, goal or FIRE cards down.

## Rules

- One tip per day. The tip is picked at random from the tips the user has not seen yet; when all are seen the cycle starts again. Seen ids stay on the device.
- Dismiss hides it until the next day. Same tip all day if the app is reopened.
- Tips hold no amounts, names or user data, so Privacy mode does not change them.
- Analytics: `daily_tip_shown` (once per process) and `daily_tip_dismissed`, each with a `tip_id` string (a content id, not user data).
- Tips ship in `assets/tips/tips.json`, in English.
