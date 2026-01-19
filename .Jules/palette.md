## 2024-05-22 - [Accessibility: Custom Interactive Elements]
**Learning:** Custom interactive widgets built with `GestureDetector` in Flutter are invisible to screen readers unless explicitly wrapped in `Semantics`. Simple `Text` children are not enough if they don't convey the "button" role or state (like "selected").
**Action:** Always wrap `GestureDetector` with `Semantics(button: true, ...)` when building custom buttons or tabs. Use `excludeSemantics: true` on the container if you provide a custom `label` to merge child semantics into a single announcements.

## 2025-01-11 - [Interaction: Clear Button Pattern]
**Learning:** For text fields with explicit "Search" vs "Close Search Mode" actions, it is critical to distinguish the icons. Using `Icons.cancel` (filled circle with X) for clearing text inside the field distinguishes it from `Icons.close_rounded` (X) used for closing the search bar itself.
**Action:** Use `suffixIcon` with `Icons.cancel` for text clearing actions inside `TextField`s, and ensure to provide a tooltip ("Clear text") and haptic feedback (`HapticFeedback.lightImpact()`) for better UX.

## 2026-01-15 - [Accessibility: Default Semantics for Reusable Cards]
**Learning:** Reusable container widgets (like `GlassCard`) that accept `onTap` often get used as buttons but lack semantics, making them invisible to screen readers. Relying on developers to wrap them in `Semantics` leads to inconsistent accessibility.
**Action:** Embed `Semantics(button: true, ...)` directly into reusable interactive widgets when `onTap` is present. Expose a `semanticLabel` parameter to allow overriding the announcement, but ensure the "button" role is there by default.
