## 2024-05-29 - Missing Semantics in Empty State Widget
**Learning:** Empty states typically contain descriptive images/icons that provide context when lists or data are empty. Without semantics, screen readers may skip them entirely, leaving users confused about why a screen appears blank.
**Action:** Always wrap informational empty states in `Semantics` widgets with clear text descriptions combining the title and message so screen reader users understand the current app state.
