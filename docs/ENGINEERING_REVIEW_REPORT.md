# Engineering Review Report

## Executive Summary
* **Overall Repo Health Score:** 65/100
* **Biggest Risks:** God classes with >1500 lines, numerous potential anti-pattern violations (e.g. `ref.read` in build methods), low modularity in some screens.
* **Highest ROI Improvements:** Decomposing large screen widgets (like `AddInvestmentScreen` and `AnalyticsService`) and refactoring `ref.read` calls inside `build()` to `ref.watch()`.
* **Architecture Concerns:** Feature files contain too much business logic; UI classes exceed 500 lines threshold (violating rule #14 Anti-Patterns).

## Critical Issues
1. **Rule 14 (Anti-Pattern) Violations:**
   * **God Classes (> 500 lines):**
     - `lib/features/investment/presentation/screens/add_investment_screen.dart` (1517 lines)
     - `lib/core/analytics/analytics_service.dart` (1440 lines)
     - `lib/core/notifications/notification_service.dart` (1093 lines)
     - `lib/features/investment/presentation/widgets/add_document_sheet.dart` (1020 lines)
   * **`ref.read` in build methods:** Detected potential usages in 39 files, e.g., `lib/features/investment/presentation/screens/add_investment_screen.dart`, `lib/features/auth/presentation/screens/sign_in_screen.dart`, etc.

## Duplication Report
* **Repeated UI Logic:** Similar selection and filtering controls in `investment_list_selection_controls.dart` and `goals_list_selection_controls.dart`.
* **Repeated Settings Logic:** Boilerplate sections in `debug_settings_screen.dart`, `notifications_settings_screen.dart`, `data_management_screen.dart`, etc.

## Reusability Opportunities
* Extract common list actions (Search, Filter, Select) into a unified generic `DataListControls` widget.
* Create a unified settings section widget builder to handle preferences rather than recreating similar UI in every settings screen.
* Create a dedicated `ActionSheet` abstraction to unify `add_document_sheet.dart` and other bottom sheets.

## Architecture Review
* **Layering Issues:** Screens like `AddInvestmentScreen` mix complex form validation, database calls, and UI rendering.
* **State Management:** Riverpod `ref.watch` vs `ref.read` is used inconsistently. In asynchronous operations, `ref.read` is fine, but it appears inside synchronous `build` phases, causing stale states and violating `14.1` rules.

## Performance Findings
* Oversized widgets (like `AddInvestmentScreen` and `AnalyticsService`) force larger rebuilds and consume unnecessary memory.
* Potential N+1 queries or synchronous conversions in `CurrencyConversionService` (978 lines).

## Security & Reliability Findings
* **Auth Error Handling:** `sign_in_screen.dart` logs cancellations explicitly; must verify it correctly uses `LoggerService.info` instead of error to avoid Crashlytics pollution.
* **Firestore Writes:** Need to verify `timeout()` is appended to all Firestore writes as per Rule 19.5.

## Testing Gaps
* With files over 1500 lines, unit test coverage on pure logic is likely low because business logic is heavily coupled to the UI.

## Rules Compliance Findings
* **Rule 14 (Anti-Patterns):** Classes over 500 lines (36 files found).
* **Rule 14.1 (Riverpod):** `ref.read` used in build methods.

## Recommended Refactor Plan
### Quick Wins
* Refactor `ref.read` to `ref.watch` in `build()` methods across the 39 flagged UI files.
* Update `LoggerService.error` to `LoggerService.info` for known cancellations in Auth/Update flows to reduce false Crashlytics alerts.
### Medium Effort Improvements
* Split `AddInvestmentScreen` into smaller sub-components (e.g., `InvestmentFormFields`, `InvestmentSubmitButton`).
* Refactor `CurrencyConversionService` and `AnalyticsService` into smaller, focused single-responsibility classes.
### Long-Term Architecture Improvements
* Enforce strict `< 500 lines` rule via custom linter or git pre-commit hooks.
* Centralize UI components (like list selection/filters) into a unified shared library within `lib/core/widgets`.

---

1. **Top 10 highest-value fixes:**
   1. Fix `ref.read` inside `build()` methods.
   2. Ensure all Firestore `.add`, `.update`, `.set` calls have `.timeout()`.
   3. Fix `LoggerService.error` calls on expected cancellations.
   4. Move complex business logic out of `AddInvestmentScreen.dart`.
   5. Break down `AnalyticsService.dart`.
   6. Break down `NotificationService.dart`.
   7. Enforce timeout clauses in repository layers.
   8. Standardize loading states using AsyncValue properly.
   9. Consolidate list filtering logic across features.
   10. Convert `ref.read` calls inside `onPressed` to use a consistent error boundary.

2. **Top 10 duplication-removal opportunities:**
   1. Selection controls in `Investment` and `Goals`.
   2. Search fields across different feature lists.
   3. Settings screen row items.
   4. Action bar implementations in `Investment` and `Goals`.
   5. Document picking/adding sheets.
   6. Error handling UI dialogs.
   7. Generic empty state widgets.
   8. Currency formatting wrappers.
   9. Common form validation rules.
   10. App bar configurations across detail screens.

3. **Top reusable abstractions:**
   1. `SharedListControls` (Search, Filter, Select).
   2. `FormBuilder` utilities for standardized input and validation.
   3. `SettingsSectionBuilder` for consistent settings UI.
   4. `BaseRepository` with built-in timeouts and offline error handling.

4. **Files/components with highest technical debt:**
   1. `lib/features/investment/presentation/screens/add_investment_screen.dart`
   2. `lib/core/analytics/analytics_service.dart`
   3. `lib/core/notifications/notification_service.dart`
   4. `lib/features/investment/presentation/widgets/add_document_sheet.dart`
   5. `lib/core/services/currency_conversion_service.dart`

5. **Suggested missing engineering standards:**
   1. Strict max file length (e.g., 500 lines) enforced by CI.
   2. Hard CI rules against `ref.read` inside `build()`.
   3. Centralized API for expected cancellations vs. fatal crashes.
   4. Standardized Firestore Write abstractions that enforce `.timeout()`.
   5. UI test coverage mandates for all new components.
