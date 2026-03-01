## 2026-03-01 - [Swipe Actions Accessibility]
**Learning:** Screen readers (like TalkBack or VoiceOver) cannot discover swipe actions by default. Wrapping `Dismissible` widgets with `Semantics` and providing `customSemanticsActions` (e.g., 'Delete', 'Edit') exposes these actions to the accessibility menu. Note that doing this alters the render tree and can cause minor failures in pixel-perfect golden tests.
**Action:** Always implement `customSemanticsActions` on custom swipeable components to ensure complete accessibility.
