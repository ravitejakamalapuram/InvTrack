## 2024-05-22 - [Accessibility: Custom Interactive Elements]
**Learning:** Custom interactive widgets built with `GestureDetector` in Flutter are invisible to screen readers unless explicitly wrapped in `Semantics`. Simple `Text` children are not enough if they don't convey the "button" role or state (like "selected").
**Action:** Always wrap `GestureDetector` with `Semantics(button: true, ...)` when building custom buttons or tabs. Use `excludeSemantics: true` on the container if you provide a custom `label` to merge child semantics into a single announcements.

## 2025-01-11 - [Interaction: Clear Button Pattern]
**Learning:** For text fields with explicit "Search" vs "Close Search Mode" actions, it is critical to distinguish the icons. Using `Icons.cancel` (filled circle with X) for clearing text inside the field distinguishes it from `Icons.close_rounded` (X) used for closing the search bar itself.
**Action:** Use `suffixIcon` with `Icons.cancel` for text clearing actions inside `TextField`s, and ensure to provide a tooltip ("Clear text") and haptic feedback (`HapticFeedback.lightImpact()`) for better UX.

## 2025-01-28 - [Accessibility: Selection Chip Metadata]
**Learning:** When custom selection chips display auxiliary information visually (e.g., a checkmark indicating "present in original selection"), this metadata is lost to screen readers if not explicitly included in the `Semantics` label.
**Action:** Append auxiliary status information to the `label` in `Semantics` (e.g., "Type A, present in selection") so screen reader users have the same context as visual users.

## 2025-01-28 - [Accessibility: ExcludeSemantics Trap]
**Learning:** When using `Semantics(excludeSemantics: true, ...)` to wrap a `GestureDetector`, the gesture detector's semantics (including `onTap`) are excluded from the tree. The custom Semantics widget MUST provide the `onTap` callback explicitly, otherwise the element becomes unclickable for screen reader users.
**Action:** Always pass `onTap`, `onLongPress`, etc., to the `Semantics` widget when `excludeSemantics` is true.

## 2026-01-15 - [Accessibility: Default Semantics for Reusable Cards]
**Learning:** Reusable container widgets (like `GlassCard`) that accept `onTap` often get used as buttons but lack semantics, making them invisible to screen readers. Relying on developers to wrap them in `Semantics` leads to inconsistent accessibility.
**Action:** Embed `Semantics(button: true, ...)` directly into reusable interactive widgets when `onTap` is present. Expose a `semanticLabel` parameter to allow overriding the announcement, but ensure the "button" role is there by default.

## 2026-01-22 - [Accessibility: Page Indicators]
**Learning:** Page indicators (dots) are often implemented as purely visual elements, but users expect them to be interactive. Making them tappable with transparent padding for touch targets and full semantics (label "Page X of Y", selected state) significantly improves navigation and accessibility.
**Action:** Wrap page indicator dots in `Semantics(button: true, ...)` and `GestureDetector` with transparent padding to ensure a 48px touch target.

## 2026-01-25 - [Accessibility: Loading State Semantics]
**Learning:** Custom buttons (like `InkWell` wrapped in `Container`) that replace text with a `CircularProgressIndicator` during loading often lose their accessible label and button role, causing screen readers to announce nothing or just "disabled" without context.
**Action:** Wrap the button in `Semantics(button: true, excludeSemantics: true, ...)` and dynamically update the `label` to include the action status (e.g., "Signing in...") while maintaining the `enabled` state logic (or explicitly communicating it via label if `onTap` is null).

## 2026-02-15 - [Accessibility: Privacy Masking & Compact Text]
**Learning:** Privacy masking using bullets ("•••••") results in verbose "bullet bullet..." announcements. Similarly, compact financial notation ("1.5L") is often ambiguous to screen readers.
**Action:** For privacy masks, use `Semantics(label: 'Hidden amount', excludeSemantics: true)`. For compact values, provide the full expanded value in the semantic label (e.g., "1,50,000 rupees") to offer better context than the visual abbreviation.

## 2026-05-21 - [Accessibility: IconButtons & Small Targets]
**Learning:** `IconButton` widgets often lack the `tooltip` property, making them inaccessible to screen readers and confusing for mouse users. Also, small custom actions inside chips (like "clear filter") are often implemented with raw `GestureDetector`s that are too small to touch reliably and invisible to accessibility tools.
**Action:** Always provide a descriptive `tooltip` for `IconButton`. For small custom actions, wrap them in `Semantics(button: true, label: ...)` and use transparent padding or containers to expand the touch target to at least 48x48px (or close to it) without disrupting the visual layout.

## 2026-06-10 - [Accessibility: Selection State on Custom Cards]
**Learning:** When using custom card widgets (like `GlassCard`) in a selectable list, the internal checkbox is often hidden from accessibility when `excludeSemantics` is used on the card. Screen readers need explicit state information on the card itself.
**Action:** Add a `selected` property to the custom card widget that maps to `Semantics(selected: true)`. Additionally, for maximum compatibility, prepend "Selected" or "Not selected" to the semantic label so the state is clear even if the semantic flag is not announced.

## 2026-10-27 - [Accessibility: Disassociated Labels]
**Learning:** When rendering form labels manually outside of `TextField` (e.g. using a `Column` with `Text` + `TextField`), the label is not programmatically associated with the input field for screen readers. Users land on the field without context.
**Action:** Use `InputDecoration.labelText` with `FloatingLabelBehavior.never` to pass the label to the semantic tree without duplicating it visually. Also, wrap the external visual label in a `GestureDetector` that requests focus on the field to mimic standard `htmlFor` behavior.

## 2026-10-27 - [Accessibility: Custom Widget Keyboard Focus]
**Learning:** Custom selection widgets built with `GestureDetector` (like `TypeSelector`) are often implemented without keyboard focus support, making them inaccessible to keyboard users and screen readers that rely on focus traversal.
**Action:** Wrap custom interactive widgets in a `Focus` widget. Handle `onFocusChange` to update visual state (e.g., focus ring) and `onKeyEvent` to support Enter/Space activation, ensuring they behave like native buttons.

## 2026-10-27 - [Accessibility: Contextual Metadata in List Items]
**Learning:** Screen reader users often miss context available to sighted users through auxiliary text (e.g., "Last activity", "Total invested" in a footer). Grouping primary data (Name, Value) with secondary metadata into a single semantic label ensures users get the full picture without navigating multiple small elements.
**Action:** Consolidate all relevant data points into a single, comprehensive `semanticLabel` for complex list items (like investment cards), using clear separators (e.g., ". ") to allow screen readers to pause naturally between pieces of information.

## 2026-10-28 - [Accessibility: Redundant Semantics in Tooltips]
**Learning:** When wrapping a custom widget that already has a `Semantics(label: ...)` wrapper with a `Tooltip`, the screen reader announces both the label and the tooltip message, leading to redundant "Show amounts, Show amounts" announcements.
**Action:** Set `excludeFromSemantics: true` on the `Tooltip` when the underlying widget already has a descriptive `Semantics` label to ensure a clean, single announcement while preserving the visual tooltip behavior.

## 2026-10-28 - [Accessibility: Custom Swipe Actions]
**Learning:** Swipe-to-action widgets like `Dismissible` are inaccessible to screen reader users who cannot perform swipe gestures. Standard `Semantics` actions (like "Delete", "Archive") are not automatically exposed unless explicitly defined.
**Action:** Wrap `Dismissible` children in `Semantics(customSemanticsActions: ...)` to map swipe directions to accessible actions (e.g., "Delete", "Archive") that can be triggered via the screen reader's actions menu.
