A quiet one-time card on the Overview inviting people to the InvTrack tips channel on Telegram (https://t.me/invtrack_tips). The same link sits in Settings as a "Join our Telegram tips" row.

## Anatomy

Same shape as `GuestLinkBanner`: 12px radius, 8px vertical margin, padding 16, `primary` tint fill (8% light, 15% dark) and a 1px `primary` border at 40%. Left to right: a 22px `send_outlined` icon in `primary`; a column with the title "Join our Telegram tips" (`bodyMedium`, 600; the theme does not define `titleSmall`, so it would fall back to Roboto), the message "Short money tips, free. Leave any time." (`bodySmall`) and a text button "Join"; a 48dp close button (tooltip "Dismiss"). Placed on the Overview under the daily tip card, so it never pushes the hero, goal or FIRE cards down.

## Rules

- Shows from the 3rd active investment. Never in sample-data mode, and never while the guest backup banner shows (one card at a time).
- Shown once: "Join" (when Telegram or the browser opens) or the close button hides it for good (device-local). If the link cannot open, the card stays and a snackbar shows the link.
- Settings row (icon `send_outlined`, same link) is always there; it logs `telegram_invite_tapped` with `source: settings`.
- Analytics: `telegram_invite_shown` (once per process), `telegram_invite_tapped` (`source`: `card` or `settings`), `telegram_invite_dismissed`. No amounts or user data.
- Not a notification or bell item: the app has no bell list yet. If one lands, move the card there.
