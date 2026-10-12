The app's actions: the full-width GradientButton for the main action of a form or screen, the themed Elevated, Outlined and Text buttons, the Material FilledButton, and the floating action button.

Use one GradientButton per screen for the primary action (Add Investment, Save, Continue). Use Outlined for a safe alternative, Text for tertiary actions, FAB to add from a list.

## Variants

- `gradient` (GradientButton): full width, 56px (`button-h-xl`), `radius-lg` 16, a 90-degree gradient from the colour to the same colour at 80%, a glow `shadow-button-gradient`, label Inter 600 16px with +0.2 spacing, white, an optional 24px leading icon with an 8px gap. The colour defaults to the light-mode primary `#5b4cdb` in both themes and can be set (a red delete button). At a large text size on a narrow screen (320dp at 1.8x) the label shrinks to fit the button on one line instead of overflowing it. Loading swaps the gradient for a flat fill (`neutral-300-light`, or `neutral-700-dark`), removes the glow and shows a 24px spinner announced as "Loading <label>".
- `elevated`: `primary` fill, `on-primary` text (white in light, #0a0a0a in dark), `radius-md` 12, padding 24 x 16, `button-large` text, no elevation.
- `outlined`: transparent, `primary` text, 1.5px `outline` border, same shape and padding.
- `text`: `primary` text, `button` 14/600, padding 16 x 12; the tap target extends to 48dp.
- `filled`: Material 3 FilledButton default (pill, 40px), used for "Save" in dialogs and "Retry". No `filledButtonTheme` exists in `app_theme.dart`; this is Flutter's default on `primary`.
- `fab`: 56px, `radius-lg` 16, `primary` fill, `on-primary` icon, Material elevation 4.

## Consumer provides

`label`, `icon`, `loading`, `disabled`, `color` (gradient only), `variant`. The press handler and haptics belong to the app.

## Rules

- Title Case labels naming the verb and the object: "Add Investment", "Save", "Delete".
- At least 48 x 48dp; keep 8px between neighbouring targets.
- While loading, keep the button in place and disabled; never remove it.
- A destructive action is confirmed in a `Dialog`, not by colour alone.

## Contrast

White on `#5b4cdb` is 6.00:1; the gradient fades to 80% so white is 4.04:1 at its right end over a light page. The dark theme's `elevated` (#0a0a0a on #8b7cf6) is 5.95:1, but GradientButton and the other light-mode fills keep white on `#5b4cdb` in dark, 6.00:1 for the label and 3.30:1 against the page. A disabled GradientButton keeps its gradient: the source paints no disabled state, so convey "disabled" with the loading style or hide the button.

## Source

`gradient_button.dart`; `elevatedButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`, `floatingActionButtonTheme` in `app_theme.dart`.
