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

## 2024-06-05 - Added Semantics wrapper to custom horizontal scrolling cards
**Learning:** Found that custom horizontal scrolling selectors with custom interactive cards (`GestureDetector` wrapped `AnimatedContainer`s in `TemplateSelector`) lacked proper native accessibility roles in Flutter. Screen readers might fail to announce their role as a button, their selection state (`selected: isSelected`), and may read out confusing internal visual structure (like emojis, names, rates) individually.
**Action:** When building custom horizontal selection elements with custom cards, ALWAYS wrap the gesture detector with a `Semantics` widget. Set `button: true`, specify `selected: isSelected`, provide a concise and descriptive `label`, and set `excludeSemantics: true` so the screen reader only reads the top-level concise label.

## 2026-03-15 - Focus placement relative to Semantics when using excludeSemantics
**Learning:** In Flutter, when creating a custom interactive widget that hides its complex child semantics tree by using `Semantics(excludeSemantics: true)`, any `Focus` node placed *inside* that `Semantics` widget will also be hidden from the accessibility tree, making it unreachable via keyboard navigation.
**Action:** Always wrap the `Semantics` widget *inside* the `Focus` widget, so that the keyboard focus node exists outside the excluded semantic boundary and can be properly focused.

## 2026-03-22 - Added Semantics wrapper to color and icon pickers

**Learning:** Custom interactive elements like color or icon pickers created using `GestureDetector` lack proper native accessibility roles in Flutter. Screen readers may fail to announce their role as a button, their selection state, and their label.
**Action:** When building custom interactive components using generic containers and `GestureDetector`s, ALWAYS wrap the gesture detector with a `Semantics` widget. Explicitly set `button: true`, provide a clear `label`, specify `selected` state if applicable, and often use `excludeSemantics: true` to prevent the screen reader from redundantly parsing the complex child tree.

## 2024-05-18 - Added Semantics wrapper to PremiumGate overlay

**Learning:** Found that a `GestureDetector` coupled with an `AbsorbPointer` used to create a feature gate or paywall overlay (like `PremiumGate`) acts as a visual blocker but lacks proper native accessibility roles in Flutter. Screen readers may fail to announce their role as an actionable item (button) to unlock the feature, and importantly, they may still read out the inaccessible, visually obscured locked content underneath.
**Action:** When building paywall overlays or feature gates using `GestureDetector` and `AbsorbPointer`, ALWAYS wrap the gesture detector with a `Semantics` widget. Explicitly set `button: true`, provide a clear `label` (e.g., 'Unlock Premium feature'), and set `excludeSemantics: true`. This provides a single, actionable announcement for screen readers while effectively hiding the underlying, inaccessible locked content from the accessibility tree.

## 2024-05-18 - Excluded Semantics for explicit text field labels

**Learning:** Found that the `GestureDetector` used to allow clicking the visual label to focus the text field in `AppTextField` creates a double-reading issue for screen readers. Screen readers natively focus the adjacent text field and read its `labelText` property. If the visual label is not excluded, it is read once as plain text, and then again when the field is focused. Making it a button is an anti-pattern.
**Action:** Wrap the `GestureDetector` of custom visual labels in an `ExcludeSemantics` widget to hide it from the accessibility tree, relying entirely on the native `TextFormField`'s internal semantics for screen reader navigation, while preserving the visual tap-to-focus behavior for sighted users.

## 2026-04-12 - Added Semantics to Document Viewer zoom gesture

**Learning:** Found that a `GestureDetector` handling double-tap to reset zoom on images in `DocumentViewerScreen` lacks semantic meaning for screen readers. They won't announce the zoom capability.
**Action:** When wrapping visual or interactive elements with `GestureDetector` for custom gestures (like double-tap), ensure it is wrapped in a `Semantics` widget with appropriate `label` and `hint` to announce the interaction capability.

## $(date +%Y-%m-%d) - Add localized tooltips to icon-only buttons
**Learning:** Icon-only buttons (e.g., `IconButton` widgets in Flutter) are inaccessible to screen readers without explicit semantic labels. Providing a `tooltip` automatically attaches the necessary semantics to ensure accessibility. Missing `tooltip` attributes was a common pattern across app bars in this app.
**Action:** In future PRs, I will routinely check for `IconButton` components that are missing the `tooltip` attribute and apply localized labels (e.g., `l10n.tooltipClose`) to ensure compliance with basic accessibility standards.
