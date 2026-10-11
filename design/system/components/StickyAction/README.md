The submit bar at the foot of a long form (`StickyFormAction`): the button stays in view while the form scrolls behind it.

## Anatomy

- Full width, the screen `background`, a 1px `outline-variant` line along its top edge (painted inside the padding), 16px above and below and 24px at the sides (`screen-padding-x`), clear of the system navigation bar.
- It holds one GradientButton (56px).

## Behaviour

- It is the Scaffold's `bottomNavigationBar`, so a floating SnackBar appears above it, not over the button. A Scaffold leaves a bottom bar under the keyboard, so the bar pads itself by the keyboard height (or the system bar, whichever is larger) and goes up with the keyboard. Do not also pad it from outside.
- With a 250dp keyboard open at 320 x 568dp and text 1.8x the button is still on screen and can be tapped.

## Consumer provides

`body` (the button).

## Source

`sticky_form_action.dart` (`lib/core/widgets`); the layout is `first_investment_form_view.dart`.
