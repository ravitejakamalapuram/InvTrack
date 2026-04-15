## 2024-05-15 - Double Tap Context for Image Viewers
**Learning:** `GestureDetector` widgets that handle multi-tap interactions (like `onDoubleTap`) around components like `InteractiveViewer` do not automatically announce this capability to screen readers, leaving visually impaired users unaware of zoom functionality.
**Action:** When wrapping an `InteractiveViewer` with a `GestureDetector` for zooming, always enclose the `GestureDetector` in a `Semantics` widget with a descriptive `label` (e.g., "Double tap to zoom") to provide proper interaction context.
