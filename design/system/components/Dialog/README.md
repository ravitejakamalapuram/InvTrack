A centred modal dialog: the confirmation dialog with explicit styling, and the form dialog that uses Flutter's Material 3 defaults.

Use a confirm dialog before any destructive or irreversible action (delete, sign out, clear data). Use a form dialog for one small input (the current value). For lists of choices use a `BottomSheet`.

## Anatomy

- Confirm (`AppFeedback.showConfirmDialog`): `AlertDialog` on `surface`, 20px radius, title `h4` (16/600) in `text`, message `body` 16 in `text-muted`, two text buttons: cancel in `text-muted` and confirm in the light-mode red (destructive, 600) or the light-mode primary. Defaults: Cancel / Delete. On a scrim of black at 54%.
- Form (`CurrentValueDialog`): no `dialogTheme` exists in `app_theme.dart`, so it uses Material 3 defaults on `card` (Flutter's 28px radius and 24 padding), title in `h3` 18/600, a `TextFormField` from the global input theme (a filled `input-fill` box with a 12px outline and a 2px `primary` border while focused, not an underline) labelled "Value in INR" (the floating label is the theme's `label` style in `text-secondary`) with a validator ("Enter a value of 0 or more"), a text button with a calendar icon ("Value as of Oct 11, 2026"), and actions: "Use estimate" (only when the user set a value), "Cancel", and a filled "Save". The preview approximates the M3 defaults; they are not set by InvTrack code.

## Consumer provides

`title`, `message`, `confirm`, `cancel`, `destructive`. The consequence belongs in the message: "This will permanently delete this investment and all its transactions. This action cannot be undone."

## Rules

- Name the verb on the confirm button (`Delete`, `Archive`, `Sign Out`), never "OK".
- Cancel is always present and first; the destructive action is the last, in `danger`.
- Focus the first field in a form dialog; submit on the keyboard's done key.
- Show a snackbar if saving fails, not a second dialog.

## Contrast

The dialog fill `surface` equals the dark `background` (#0a0a0a), so the dialog edge is invisible against the dimmed page in dark mode; the scrim is the only separation. The destructive label (`#ef4444`) is 3.45:1 on `surface` in light and 5.26:1 in dark; `text-muted` message 4.40:1 on `surface` in light. Kept as drawn.

## Source

`lib/core/utils/app_feedback.dart` (`showConfirmDialog`); `current_value_dialog.dart`; `swipe_actions.dart` (confirm copy).
