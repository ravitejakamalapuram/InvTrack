## 2024-05-21 - Removed unnecessary GestureDetectors on GlassCards

**Learning:** The GlassCard widget already supports `semanticLabel` and `onLongPress` and wraps its contents properly in a `Semantics` and `InkWell`. Wrapping it in an additional `GestureDetector` causes redundant accessibility layers, confusing targets for screen readers, and prevents the default ink splash from happening since it overrides `onTap`.

**Action:** Use GlassCard built-in parameters instead of custom `GestureDetectors` wrapper.

## 2024-05-23 - Interactive Element Visual Feedback
**Learning:** Using a silent `GestureDetector` wrapped around a `Container` for custom buttons deprives users of immediate visual feedback, making the UI feel unresponsive.
**Action:** Always prefer `Material` + `InkWell` + `Ink` over `GestureDetector` + `Container` for custom interactive UI elements to ensure standard Material ripple feedback is provided.
