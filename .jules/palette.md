## 2024-05-21 - Removed unnecessary GestureDetectors on GlassCards

**Learning:** The GlassCard widget already supports `semanticLabel` and `onLongPress` and wraps its contents properly in a `Semantics` and `InkWell`. Wrapping it in an additional `GestureDetector` causes redundant accessibility layers, confusing targets for screen readers, and prevents the default ink splash from happening since it overrides `onTap`.

**Action:** Use GlassCard built-in parameters instead of custom `GestureDetectors` wrapper.

## 2024-05-19 - Removed redundant GestureDetector blocking InkWell ripple feedback
**Learning:** In Flutter, wrapping components with an InkWell inside a silent `GestureDetector` blocks the underlying ripple and touch feedback, causing "dead zones" where buttons don't react visually on touch. This issue happened heavily with the `GlassCard` wrapper.
**Action:** Always prefer using a native `.onTap()` parameter on custom interactive containers over wrapping them in a silent `GestureDetector` to preserve Material touch ripples and improve immediate feedback.
