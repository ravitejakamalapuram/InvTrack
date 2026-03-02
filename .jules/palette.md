## 2024-03-02 - Add Tooltips to Icon-Only Buttons
**Learning:** Icon-only buttons without `tooltip` properties are inaccessible to screen readers and lack visual hover feedback on desktop/web platforms, leading to poor UX and a11y.
**Action:** Always include a descriptive `tooltip` attribute on all `IconButton` widgets that only contain icons without visible text labels.
