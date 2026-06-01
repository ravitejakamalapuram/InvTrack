## 2024-05-21 - Removed unnecessary GestureDetectors on GlassCards

**Learning:** The GlassCard widget already supports `semanticLabel` and `onLongPress` and wraps its contents properly in a `Semantics` and `InkWell`. Wrapping it in an additional `GestureDetector` causes redundant accessibility layers, confusing targets for screen readers, and prevents the default ink splash from happening since it overrides `onTap`.

**Action:** Use GlassCard built-in parameters instead of custom `GestureDetectors` wrapper.

## 2024-05-22 - Replaced GestureDetector with Material/InkWell/Ink for opaque containers

**Learning:** Using `GestureDetector` to wrap an opaque `Container` blocks the default Material ripple feedback (`InkWell` splash), which is a common pattern that reduces perceived responsiveness.

**Action:** Replace `GestureDetector` and `Container` combinations with `Material(color: Colors.transparent)`, `InkWell`, and `Ink` for the decoration. This ensures the splash effect isn't visually blocked by an opaque background.
