## 2024-05-22 - [Accessibility: Custom Interactive Elements]
**Learning:** Custom interactive widgets built with `GestureDetector` in Flutter are invisible to screen readers unless explicitly wrapped in `Semantics`. Simple `Text` children are not enough if they don't convey the "button" role or state (like "selected").
**Action:** Always wrap `GestureDetector` with `Semantics(button: true, ...)` when building custom buttons or tabs. Use `excludeSemantics: true` on the container if you provide a custom `label` to merge child semantics into a single announcements.
