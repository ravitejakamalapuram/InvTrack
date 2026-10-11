Transient feedback at the bottom of the screen: success, error and info snackbars, and the exact-amount toast that appears on a long-press.

Use a snackbar to confirm a finished action or report a failure the user can retry. Do not use it for anything that needs a decision: use a `Dialog`.

## Kinds

- `success`: `success` fill (light `#007a54`, dark `#34d399`), a 20px white check-circle icon, 2 s. Haptic: medium.
- `error`: `error` fill (light `#cc1926`, dark `#f87171`), a white error icon, 3 s. Haptic: heavy.
- `info`: `primary` fill (light `#5b4cdb`, dark `#8b7cf6`), a white info icon, 2 s. Haptic: selection.
- `exact` (CompactAmountText long-press): `neutral-800-light` in light, `surface` in dark; a 11px "Exact Amount" label (white 70%) over the 16px/700 figure to two decimals, and a copy icon button (48dp). Copying shows a green "Copied to clipboard" snackbar for 1 s: `success` fill (light `#10b981`, dark `#34d399`), a check icon and the message in `card` colour (white in light, #171717 in dark; 9.33:1 on the dark fill). 4 s.
The snackbars of Settings, Data & Account and the guest-backup notices follow the same rule: `success` or `error` fill by theme, and the Retry action of the currency snackbar is the message colour (white in light, #171717 in dark). Only the import-warnings snackbar keeps one amber fill (`warning`, #f59e0b) with fixed dark text in both themes.
All are floating with a 12px radius (`radius-md`). The message is not styled in code: it takes the theme's `bodyMedium` (`caption`, Inter 14/400) in Material's default colour `onInverseSurface`, which `app_theme.dart` leaves unset, so it falls back to `ColorScheme.surface`: `card`, white in light and #171717 in dark. The icons of the success, error and info snackbars are explicit white in both themes; the check of the Copied snackbar is the message colour.

## Consumer provides

`kind`, `message` (a short sentence). The exact-amount toast cannot appear in privacy mode, because the long-press is disabled there.

## Rules

- One snackbar at a time; a new one replaces the old.
- Say what happened in under ten words, with a retry in the message when it failed ("Could not save the current value. Try again.").
- Pair the colour with the icon and the words.

## Contrast

In light the white message is 5.37:1 on the success fill and 5.62:1 on the error fill; white on the info fill is 6.00:1. In dark the message is #171717 on the lighter fills: 9.33:1 on success `#34d399`, 6.48:1 on error `#f87171`, 5.39:1 on info `#8b7cf6`; only the white icon is low there, 1.92:1, 2.77:1 and 3.33:1. The exact-amount toast is 15.17:1 and 19.80:1. These are the source's pairs and are kept; the message and the icon shape carry the meaning.

## Source

`lib/core/utils/app_feedback.dart` (`showSuccess`, `showError`, `showInfo`); `compact_amount_text.dart` (`_showFullAmount`). There is no `snackBarTheme` in `app_theme.dart`.
