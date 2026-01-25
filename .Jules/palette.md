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
