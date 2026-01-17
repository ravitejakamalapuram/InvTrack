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
