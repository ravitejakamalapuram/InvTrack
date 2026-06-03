## 2024-05-21 - Removed unnecessary GestureDetectors on GlassCards

**Learning:** The GlassCard widget already supports `semanticLabel` and `onLongPress` and wraps its contents properly in a `Semantics` and `InkWell`. Wrapping it in an additional `GestureDetector` causes redundant accessibility layers, confusing targets for screen readers, and prevents the default ink splash from happening since it overrides `onTap`.

**Action:** Use GlassCard built-in parameters instead of custom `GestureDetectors` wrapper.

## 2024-05-22 - Replaced GestureDetector with Material/InkWell/Ink for opaque containers

**Learning:** Using `GestureDetector` to wrap an opaque `Container` blocks the default Material ripple feedback (`InkWell` splash), which is a common pattern that reduces perceived responsiveness.

**Action:** Replace `GestureDetector` and `Container` combinations with `Material(color: Colors.transparent)`, `InkWell`, and `Ink` for the decoration. This ensures the splash effect isn't visually blocked by an opaque background.

## 2024-05-22 - Improved Empty State Accessibility

**Learning:** When building Empty States that combine static text (titles, messages) with decorative icons, screen readers often read them as disjointed elements. Additionally, wrapping the entire `EmptyStateWidget` (including its action button) in a single `Semantics` widget with `excludeSemantics: true` causes the interactive button to be removed from the accessibility tree, making it undiscoverable by screen readers.

**Action:** Wrap only the static content (Icon, Title, Message) in a `Semantics` widget using `excludeSemantics: true` with a combined label. Ensure any interactive elements like buttons are placed *outside* this wrapper so they remain discoverable and actionable.

## 2024-05-29 - Missing Semantics in Empty State Widget

**Learning:** Empty states typically contain descriptive images/icons that provide context when lists or data are empty. Without semantics, screen readers may skip them entirely, leaving users confused about why a screen appears blank.

**Action:** Always wrap informational empty states in `Semantics` widgets with clear text descriptions combining the title and message so screen reader users understand the current app state.
