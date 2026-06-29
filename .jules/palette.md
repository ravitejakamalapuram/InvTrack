## 2024-05-21 - Removed unnecessary GestureDetectors on GlassCards

**Learning:** The GlassCard widget already supports `semanticLabel` and `onLongPress` and wraps its contents properly in a `Semantics` and `InkWell`. Wrapping it in an additional `GestureDetector` causes redundant accessibility layers, confusing targets for screen readers, and prevents the default ink splash from happening since it overrides `onTap`.

**Action:** Use GlassCard built-in parameters instead of custom `GestureDetectors` wrapper.

## 2024-05-22 - Improved Empty State Accessibility

**Learning:** When building Empty States that combine static text (titles, messages) with decorative icons, screen readers often read them as disjointed elements. Additionally, wrapping the entire `EmptyStateWidget` (including its action button) in a single `Semantics` widget with `excludeSemantics: true` causes the interactive button to be removed from the accessibility tree, making it undiscoverable by screen readers.

**Action:** Wrap only the static content (Icon, Title, Message) in a `Semantics` widget using `excludeSemantics: true` with a combined label. Ensure any interactive elements like buttons are placed *outside* this wrapper so they remain discoverable and actionable.

## 2026-06-06 - Semantics excludeSemantics with interactive children

**Learning:** When using `excludeSemantics: true` on a `Semantics` widget that wraps an interactive element (like `InkWell`), the underlying interactive semantics (such as `onTap`) are completely dropped from the accessibility tree. This makes the element unclickable for screen reader users.

**Action:** If you must use `excludeSemantics: true` around an interactive element to provide a custom label, you MUST explicitly provide the `onTap` property to the `Semantics` widget itself so the screen reader knows it is actionable.

## 2024-06-16 - Removed unnecessary GestureDetectors on GlassCards

**Learning:** The GlassCard widget already supports `semanticLabel` and `onTap` directly and wraps its contents properly in a `Semantics` and `InkWell`. Wrapping it in an additional `GestureDetector` causes redundant accessibility layers, confusing targets for screen readers, and prevents the default ink splash from happening since it overrides `onTap`.

**Action:** Use GlassCard built-in parameters instead of custom `GestureDetectors` wrappers.

## 2026-06-12 - Importance of Localizing All Tooltips

**Learning:** When reviewing `PasscodeScreen`, I found hardcoded accessibility tooltips like "Use biometric authentication", "Clear", and "Delete last digit". Screen readers read these tooltips to visually impaired users. Since the app supports multiple languages, hardcoded tooltips mean non-English users receive screen reader instructions in English, degrading their experience.

**Action:** Always localize tooltips, especially those on `IconButton` or icon-only elements used extensively for accessibility. Check `.arb` files and add missing keys to ensure the app is both accessible and fully localized.

## 2026-06-17 - Avoid Hardcoded Tooltips

**Learning:** When developing UI, hardcoding tooltip texts like `tooltip: 'Toggle selection mode'` bypasses the localization and internationalization system. This results in inaccessible experiences for users utilizing non-English languages, as screen readers will read the hardcoded English text.

**Action:** Always add tooltip strings to the `lib/l10n/app_en.arb` file (e.g., `"tooltipToggleSelectionMode": "Toggle selection mode"`) and use the generated `AppLocalizations` instance in widgets (e.g., `tooltip: l10n.tooltipToggleSelectionMode`) to ensure accessibility for all supported locales.

## 2026-07-08 - Localize Tooltips on Privacy Toggle
**Learning:** Hardcoded accessibility tooltips like 'Show amounts' on PrivacyToggleButton bypass the localization system, resulting in an inaccessible experience for non-English users as screen readers will read the hardcoded English text.
**Action:** Always add tooltip strings to lib/l10n/app_en.arb and use AppLocalizations.of(context) in widgets to ensure accessibility for all supported locales.

## 2026-07-04 - Localize Accessibility Labels
**Learning:** Found hardcoded string tooltips like 'Close search' on IconButtons. These must always be localized so non-English screen reader users receive proper instructions.
**Action:** Use AppLocalizations keys for all tooltips and accessibility labels.

## 2024-06-29 - Avoid Hardcoded Tooltips
**Learning:** When developing UI, hardcoding tooltip texts like `tooltip: 'Close search'` bypasses the localization and internationalization system. This results in inaccessible experiences for users utilizing non-English languages, as screen readers will read the hardcoded English text.
**Action:** Always add tooltip strings to the `lib/l10n/app_en.arb` file (e.g., `"tooltipCloseSearch": "Close search"`) and use the generated `AppLocalizations` instance in widgets (e.g., `tooltip: l10n.tooltipCloseSearch`) to ensure accessibility for all supported locales.
