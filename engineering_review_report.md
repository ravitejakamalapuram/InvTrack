# Repository-Wide Engineering Review & Refactoring Report

## Executive Summary
* **Overall Repo Health Score:** 6.5/10
* **Biggest Risks:** Massive "God classes" in UI and service layers, improper use of `ref.read` in build methods leading to state sync issues, significant code duplication in models and screens, and lack of component reusability.
* **Highest ROI Improvements:** Standardizing form/input components to eliminate boilerplate, enforcing the 500-line limit by splitting up massive files, and refactoring expensive `Column` usages into `ListView.builder` for list rendering.
* **Architecture Concerns:** Widespread violation of the Riverpod architecture rules (using `ref.read` in build methods). `add_investment_screen.dart` is an unmaintainable 1502-line monolith mixing presentation and business logic. `analytics_service.dart` is overloaded (1440 lines) and lacks domain separation.

---

## Critical Issues

1. **Riverpod Architecture Violation:**
   - **Issue:** Direct usage of `ref.read` in `build()` methods across at least 20 UI files (e.g., `lib/features/investment/presentation/screens/investment_list_screen.dart`). This prevents components from reacting to state changes and leads to subtle UI sync bugs.
   - **Impact:** Critical. Violates `invtrack_rules.md` (Rule 14.1).
   - **Fix:** Replace with `ref.watch` for state observation or move imperative logic to callbacks (like `onPressed`).

2. **God Classes (Violates Rule 1.3 & 14.1):**
   - **Issue:** The codebase contains several massive files that exceed the 500-line limit defined in the enterprise rules:
     - `add_investment_screen.dart` (1502 lines)
     - `analytics_service.dart` (1439 lines)
     - `notification_service.dart` (1080 lines)
     - `add_document_sheet.dart` (1020 lines)
   - **Impact:** High maintenance burden, increased cyclomatic complexity, difficult to unit test.
   - **Fix:** Break down `add_investment_screen` into smaller form sections (e.g., `InvestmentDetailsForm`, `AssetAllocationForm`). Split `analytics_service.dart` into domain-specific loggers (e.g., `InvestmentAnalyticsLogger`, `UserAnalyticsLogger`).

3. **Performance Risks - Unoptimized Lists:**
   - **Issue:** Widespread use of `Column` with a massive number of children (over 50 elements) instead of `ListView.builder` for dynamic or large lists.
   - **Locations:** `user_profile_card.dart` (55 children), `report_type_selector.dart` (52 children), `fire_stats_card.dart` (52 children).
   - **Impact:** High memory footprint, dropped frames during scrolling, expensive initial layout passes.
   - **Fix:** Refactor into `ListView.builder` or `SliverList` for lazy evaluation and rendering.

---

## Duplication Report

1. **Currency and Formatting Logic:**
   - **Finding:** Duplicated formatting logic exists between `lib/core/utils/currency_utils.dart` and `lib/features/settings/presentation/providers/settings_provider.dart`.
   - **Consolidation:** Move all currency logic to a shared `CurrencyFormatter` class.

2. **Notification Handlers:**
   - **Finding:** Overlapping and duplicated logic between `notification_service.dart` and specific handlers like `scheduled_notification_handler.dart`.
   - **Consolidation:** Extract a unified `NotificationDispatcher` and standard handler interface.

3. **Data Import and Validation:**
   - **Finding:** Validation logic for imported data is duplicated between `data_import_service.dart` and the UI `import_confirmation_screen.dart`.
   - **Consolidation:** Move validation logic entirely into the domain layer (`DataValidationService`).

4. **Document Add/Edit Sheets:**
   - **Finding:** `add_document_sheet.dart` and `edit_document_sheet.dart` contain nearly identical form and validation logic.
   - **Consolidation:** Create a single `DocumentFormSheet` that takes an optional existing document for editing.

---

## Reusability Opportunities

1. **Shared Bottom Sheet Logic:**
   - **Issue:** Every screen implementing a bottom sheet re-writes the boilerplate (drag handles, padding, styling, keyboard handling).
   - **Opportunity:** Create a reusable `AppBottomSheet` widget in `lib/core/widgets/`.

2. **Standardized Form Fields:**
   - **Issue:** Input validation, error text handling, and focus node management are manually implemented in every form.
   - **Opportunity:** Introduce an `AppFormBuilder` package/pattern (e.g., `AppTextField`, `AppDropdown`) that encapsulates common styling, validation, and accessibility labels.

3. **List Action Bars:**
   - **Issue:** Action bars for sorting/filtering are duplicated in `goals_list_action_bar.dart` and `investment_list_action_bar.dart`.
   - **Opportunity:** Create a generic `ListActionBar<T>` that accepts sort/filter configurations.

---

## Architecture Review

- **Layer Violations:** Too much business logic resides in UI files. For example, `investment_detail_screen.dart` orchestrates complex deletions and data transformations directly in the presentation layer rather than delegating to the `investmentNotifierProvider`.
- **State Management:** While Riverpod is used, many features manually manage complex local state (e.g., form state in `add_investment_screen.dart`) which should be moved to scoped `StateNotifier`s or `Notifier`s to keep the UI declarative.
- **Error Handling:** Many `try/catch` blocks (575+ in the repo) do not use the central `ErrorHandler.handle()` utility, risking unlogged crashes or inconsistent user feedback.

---

## Performance Findings

- **Expensive Renders:** God widgets like `add_investment_screen.dart` lack granular `const` usage and rebuild entirely on minor state changes.
- **Memory Leaks:** Potential undisposed controllers in complex screens where state is manually managed.
- **List Optimization:** As noted, large `Column` lists must be migrated to `ListView.builder`.

---

## Security & Reliability Findings

- **Offline Behavior:** Missing timeout handling and offline persistence checks in some Firestore operations.
- **Exceptions:** Swallowed exceptions in async `try/catch` blocks without reporting to Crashlytics.
- **Privacy:** Financial data should consistently use the `PrivacyProtectionWrapper`, but its application is scattered and sometimes forgotten in newer screens.

---

## Testing Gaps

- **Missing Coverage:** God classes (`add_investment_screen.dart`, `analytics_service.dart`) are extremely difficult to test and likely lack isolated unit test coverage for their complex internal branching.
- **Golden Tests:** No visual regression tests for core reusable widgets (buttons, cards), making it risky to refactor standard UI components.

---

## Rules Compliance Findings

- **Rule 1.3 (Complexity):** Multiple files severely violate the <15 decision points per 100 lines due to their massive size.
- **Rule 14.1 (Clean UI):** Files > 500 lines exist in abundance. `ref.read` used in build methods.
- **Rule 5.1 (Data Protection):** Need to ensure all newly added logging in large service files does not accidentally log PII or financial data.

---

## Recommended Refactor Plan

### Quick Wins (Weeks 1-2)
1. **Fix Architectural Violations:** Audit and replace all `ref.read` occurrences inside `build()` methods with `ref.watch`.
2. **Optimize Lists:** Convert the identified massive `Column` widgets into `ListView.builder`.
3. **Consolidate Error Handling:** Enforce the usage of `ErrorHandler.handle()` across the codebase.

### Medium Effort (Weeks 3-4)
1. **Deduplicate UI Forms:** Merge `add_document_sheet.dart` and `edit_document_sheet.dart`.
2. **Extract Reusable Widgets:** Build `AppBottomSheet` and `ListActionBar`.
3. **Clean Utilities:** Consolidate currency formatting and data import validation logic.

### Long-Term Architecture (Months 2-3)
1. **Deconstruct God Classes:** Break down `add_investment_screen.dart` into focused sub-widgets and move form state to Riverpod notifiers. Split `analytics_service.dart` and `notification_service.dart` by domain.
2. **Implement Form Builders:** Standardize all data entry across the app using a unified form architecture.

---

## Top Lists

### Top 10 Highest-Value Fixes
1. Replace `ref.read` with `ref.watch` in `build()` methods globally.
2. Refactor large `Column` lists (>50 children) to `ListView.builder`.
3. Split the 1502-line `add_investment_screen.dart` into smaller form components.
4. Delegate complex UI business logic (e.g., in `investment_detail_screen.dart`) to Riverpod notifiers.
5. Standardize error handling by replacing raw `catch` blocks with `ErrorHandler`.
6. Break down `analytics_service.dart` into domain-specific modules.
7. Unify data import validation between service and UI layers.
8. Consolidate document adding/editing sheets.
9. Fix null safety and offline sync handling in exchange rate caches.
10. Ensure `PrivacyProtectionWrapper` is used consistently for all monetary displays.

### Top 10 Duplication-Removal Opportunities
1. Currency formatting logic (`currency_utils.dart` vs `settings_provider.dart`).
2. Scheduled notification logic (service vs handler).
3. Import validation logic.
4. `add_document_sheet.dart` and `edit_document_sheet.dart`.
5. Empty state widgets across different feature list screens.
6. List action bars and filter tabs.
7. Settings tile definitions across the settings module.
8. Loading overlays and shimmer effects.
9. Goal progress calculation utilities.
10. Analytics event tracking boilerplate.

### Top Reusable Abstractions Worth Introducing
1. `AppFormBuilder` for standardized, validated form inputs.
2. `AppBottomSheet` for consistent modal presentations.
3. `ListActionBar` for unified sorting/filtering controls.
4. `BaseSettingsTile` for a consistent settings UI.
5. `DomainEventLogger` to simplify analytics service calls.

### Files/Components with Highest Technical Debt
1. `lib/features/investment/presentation/screens/add_investment_screen.dart` (1502 lines)
2. `lib/core/analytics/analytics_service.dart` (1439 lines)
3. `lib/core/notifications/notification_service.dart` (1080 lines)
4. `lib/features/investment/presentation/widgets/add_document_sheet.dart` (1020 lines)
5. `lib/core/services/currency_conversion_service.dart` (978 lines)

### Suggested Engineering Standards Missing
1. **File Size Limits:** Automated CI block for files exceeding 500 lines.
2. **Form Standardization:** Strict requirement to use common form builders instead of manual `TextFormField` widgets.
3. **Riverpod Lints:** Custom analyzer plugins to detect `ref.read` in build methods.
4. **Widget Testing:** Mandate Golden tests for all shared UI components.
