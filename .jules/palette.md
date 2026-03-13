## 2024-03-06 - Missing tooltip on Add Transaction Screen Close button
**Learning:** Found an `IconButton` without a `tooltip` in `lib/features/investment/presentation/screens/add_transaction_screen.dart`. Adding tooltips to icon-only buttons improves screen reader accessibility and provides hover descriptions.
**Action:** Always add `tooltip` to `IconButton`s.

## 2024-03-06 - Missing tooltips on Add Investment Screen
**Learning:** Found multiple `IconButton`s without tooltips in `lib/features/investment/presentation/screens/add_investment_screen.dart` (e.g., Close, Clear start date, Clear maturity date).
**Action:** Always add `tooltip` to `IconButton`s.

## 2024-03-06 - Unaccessible color selector in GoalIconPicker
**Learning:** Found a color picker (`GestureDetector`) inside a `Wrap` in `lib/features/goals/presentation/widgets/goal_icon_picker.dart` without `Semantics` wrapper or keyboard focus support. These need to be accessible.
**Action:** When creating custom interactive elements like color pickers or icon buttons, wrap them in `Semantics(button: true)` and ensure they can be focused/activated by keyboard if necessary.

## 2024-03-06 - Unaccessible icon selector in CreateGoalScreen
**Learning:** Found the main icon/color display in `lib/features/goals/presentation/screens/create_goal_screen.dart` is just a `GestureDetector` without Semantics. Screen readers wouldn't know it's a button to open the icon picker.
**Action:** Always wrap interactive visual elements that act as buttons in `Semantics(button: true, label: '...', onTap: ...)`.

## 2024-05-18 - Added Semantics wrapper to custom Segment Tab
**Learning:** Custom interactive widgets (like `GestureDetector` wrapped `TweenAnimationBuilder` tabs in `InvestmentDetailSegmentControl`) lack native accessibility features in Flutter. Screen readers may fail to announce their role (button), selection state, and label effectively if they contain multiple text nodes or intricate structures.
**Action:** When building custom interactive components (like tabs or buttons) using generic containers and `GestureDetector`s, ALWAYS wrap the gesture detector with a `Semantics` widget. Explicitly set `button: true`, provide a clear `label`, specify `selected` state if applicable, and often use `excludeSemantics: true` to prevent the screen reader from redundantly parsing the complex child tree.

## 2024-05-18 - Added Semantics wrapper to custom Filter Tabs in Goals
**Learning:** Found custom filter tabs (`GestureDetector` wrapped `TweenAnimationBuilder`) in `lib/features/goals/presentation/screens/goals_screen.dart` lack native accessibility features in Flutter. Screen readers may fail to announce their role (button), selection state, and a clear label containing both the text ("Active") and the item count.
**Action:** When building custom interactive components (like tabs or buttons) using generic containers and `GestureDetector`s, ALWAYS wrap the gesture detector with a `Semantics` widget. Explicitly set `button: true`, provide a clear `label`, specify `selected` state if applicable, and often use `excludeSemantics: true` to prevent the screen reader from redundantly parsing the complex child tree.

## 2024-05-18 - Unaccessible pickers in GoalIconPicker
**Learning:** Found custom color and icon pickers built with `GestureDetector` in `lib/features/goals/presentation/widgets/goal_icon_picker.dart` lacked `Semantics` wrapper and keyboard focus support. A screen reader user navigating the modal wouldn't know they are interactable options, which option is selected, or what the option represents.
**Action:** When building custom interactive pickers using generic containers and `GestureDetector`s, ALWAYS wrap the gesture detector with a `Semantics` widget. Set `button: true`, provide a clear `label` (e.g., "$icon icon" or color name), specify the `selected` state, and use `excludeSemantics: true` to prevent screen reader redundancy.
