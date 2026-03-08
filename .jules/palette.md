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
