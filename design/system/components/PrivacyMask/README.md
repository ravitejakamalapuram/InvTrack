Privacy mode: the eye toggle that hides every amount, the masked amount text, and the blur mask for charts.

Wrap every amount, percentage and figure derived from an amount. Privacy mode is a global setting held by `privacyModeProvider`; it hides amounts on screen, in semantics labels, in notifications and in share text.

## Parts

- `toggle` (PrivacyToggleButton): an eye icon (20px; 18px on the hero) that flips to `visibility_off` with a short scale and rotation, light haptic; on the hero it sits in a 12px-radius frame with a white 15% fill (25% when on) and a white 20% border. `CompactPrivacyToggle` is an `IconButton` for app bars (24px, tooltip "Show amounts" / "Hide amounts"). Label: "Show amounts" / "Hide amounts".
- `amount` (MaskedAmountText): the figure is replaced by five bullets (six when the font size is above 24px), letter-spacing 2, a 300 ms fade and slide, announced as "Hidden amount". `CompactAmountText` shows `•••••` in the same way.
- `blur` (PrivacyMask): the child is blurred (sigma 12) inside an 8px-radius clip while privacy mode is on, and announced as "Hidden content". Use for charts and sparklines. With `useTextMask` it shows `••••••` instead.
- Percentages and subtitles fade to opacity 0 over 200 ms but keep their space, so the layout does not jump.

In HTML set `data-privacy="on"` on an ancestor; `InvTrack.amount(text)` renders both the figure and its mask.

## Consumer provides

The figure as a string. The mask is never conditional on the amount: even `₹0` is hidden.

## Rules

- Hide the semantics label as well as the pixels.
- Hide return %, XIRR, MOIC and any trend text that reveals size or direction.
- Keep the toggle reachable on every screen that shows amounts.
- Never log, share or notify an amount while privacy mode is on.

## Contrast

The masked bullets inherit the text colour of the figure they replace. The toggle icon on the hero is white at 90% (4.9:1 on the middle gradient stop); on `background` it takes `text-muted` (5.86:1 light, 7.85:1 dark).

## Source

`privacy_mask.dart` (`PrivacyMask`, `MaskedAmountText`); `privacy_toggle_button.dart` (`PrivacyToggleButton`, `CompactPrivacyToggle`); `compact_amount_text.dart`.
