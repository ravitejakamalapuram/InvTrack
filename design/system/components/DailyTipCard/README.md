A quiet card on the Overview with one short money-learning tip a day. Content is education only, never a recommendation to buy or sell.

## Anatomy

Same shape as `GuestLinkBanner`: 12px radius, 8px vertical margin (the screen owns the horizontal edge), padding 16, `primary` tint fill (8% light, 15% dark) and a 1px `primary` border at 40%. Left to right: a 22px `lightbulb_outline` icon in `primary`; a column with the label "Tip of the day" (`bodySmall`, 600, `primary`), the tip title (`bodyMedium`, 600; the theme does not define `titleSmall`, so it would fall back to Roboto), the tip body (`bodySmall`, cut to 3 lines with a 48dp "Read more" / "Show less" text button when longer) and the line "Education, not investment advice." (`bodySmall`, 70% opacity); a 48dp close button (tooltip "Dismiss"). Placed on the Overview under the FIRE progress card, above the quick stats. It never pushes the hero, goal or FIRE cards down.

## Rules

- One tip per day. The tip is picked at random from the tips the user has not seen yet; when all are seen the cycle starts again. Seen ids stay on the device.
- Dismiss hides it until the next day. Same tip all day if the app is reopened.
- Tips hold no amounts, names or user data, so Privacy mode does not change them.
- Analytics: `daily_tip_shown` (once per process) and `daily_tip_dismissed`, each with a `tip_id` string (a content id, not user data).
- Tips ship in `assets/tips/tips.json`, in English.

## Bell (tips list)

A bell in the Overview app bar (`notifications_outlined`, 48dp, tooltip "Tips") keeps the tips, so a tip dismissed on the card is not lost. A small dot (8px, Material `Badge`) shows until today's tip is opened from the bell or dismissed on the card; the tooltip then reads "Tips, new tip". Tapping opens a bottom sheet (at most 90% of the screen height; the list scrolls and the disclaimer stays pinned below it): title "Tips", then today's tip and up to six earlier ones, newest first (title `bodyMedium` 600, body `bodySmall` cut to 3 lines with the same "Read more" toggle), and the disclaimer once, pinned at the bottom. The bell is hidden when there are no tips. No new analytics event.
