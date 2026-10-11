The submit bar at the foot of a long form (`StickyFormAction`): the button stays in view while the form scrolls behind it.

## Anatomy

- Full width, the screen `background`, a 1px `outline-variant` line along its top edge (painted inside the padding), 16px above and below and 24px at the sides (`screen-padding-x`), clear of the system navigation bar.
- It holds one GradientButton (56px).

## Behaviour

- It sits under the scrolling part of the form in a column, so it rides above the keyboard: the body shrinks when the keyboard opens and the bar goes up with it. Do not use a Scaffold's `bottomNavigationBar` for it: that stays at the foot of the screen and the keyboard covers it.
- With a 250dp keyboard open at 320 x 568dp and text 1.8x the button is still on screen and can be tapped.

## Consumer provides

`body` (the button).

## Source

`sticky_form_action.dart` (`lib/core/widgets`); the layout is `first_investment_form_view.dart`.
