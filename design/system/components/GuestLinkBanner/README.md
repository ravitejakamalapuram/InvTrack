A quiet card at the top of the Overview that tells a guest their data lives only on this phone and offers to link Google (A43, #786). Behind `FeatureFlag.guestLinkBanner`, off by default.

## Anatomy

A 12px-radius card, margin 8px vertical (the screen owns the horizontal edge), padding 16, `primary` tint fill (8% light, 15% dark) and a 1px `primary` border at 40%. Left to right: a 22px `cloud_upload_outlined` icon in `primary`; a column with the title "Your data is only on this phone" (`titleSmall`), the message "Link Google to back it up and keep it if you change phones." (`bodySmall`) and a text button "Link Google"; a 48dp close button (tooltip "Dismiss"). Placed under the sample-data banner, above the hero card.

## Rules

- Guests only (`isAnonymous`), flag on, not in sample-data mode. Never for a Google user.
- Dismiss hides it for 14 days (device-local time stamp); there is no permanent hide.
- Tapping "Link Google" starts the same `GoogleSignInHandler` flow as the Settings profile card, which logs `account_link_success`.
- Analytics carry no parameters: `guest_link_banner_shown` (once per process), `guest_link_banner_tapped`, `guest_link_banner_dismissed`.
- Not a prompt after the 3rd investment: deliberately left out until the banner's data justifies it.
