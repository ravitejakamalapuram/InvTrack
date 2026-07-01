# InvTrack Engineering Review Report

## Executive Summary
* **Overall repo health score:** 7.5/10
* **Biggest risks:**
  1. Performance bottlenecks from chained O(N) operations (`.where().map().toList()`) in state calculation and analytics providers (e.g., `lib/features/goals/presentation/providers/goal_progress_provider.dart`).
  2. Potential UI crashes due to unsafe `.toInt()` usages on calculated double values (e.g., `lib/features/income_projection/presentation/screens/income_trend_report_screen.dart`).
  3. UI side effects calling `ref.read` directly inside `build()` instead of using `ref.watch` (e.g., `lib/features/settings/presentation/screens/settings_screen.dart`).
  4. Missing timeout handling in Firestore write operations, reducing offline robustness (e.g., `lib/core/services/currency_conversion_service.dart`).
* **Highest ROI improvements:**
  1. Fix all missing `.timeout(Duration(seconds: 5))` in Firestore writes to comply with offline behavior rules (Rule 19.5).
  2. Refactor direct `.toInt()` calls to use `_safeToInt` helper to prevent `UnsupportedError` crashes on infinity/NaN.
  3. Optimize chained collection operations into single loops for better iteration performance.
  4. Use proper `ref.read` event handling rather than doing it directly in `build()`.
* **Architecture concerns:** Several God classes exist (e.g., `lib/features/investment/presentation/screens/add_investment_screen.dart`, `lib/core/notifications/notification_service.dart`, `lib/core/services/currency_conversion_service.dart`, `lib/core/analytics/analytics_service.dart`) that break the 500-line rule (Rule 14 Anti-Pattern). Clean Architecture boundaries are generally respected, but UI components are occasionally doing too much logic.

## Critical Issues
* **Firestore Offline Handling:** Several `lib/features/investment/data/repositories/firestore_investment_repository.dart` and `lib/features/goals/data/repositories/firestore_goal_repository.dart` write operations do not have `.timeout(Duration(seconds: 5))`, violating Rule 19.5.
* **UI Rebuild and Riverpod Violations:** Calling `ref.read()` inside `build` method in files like `lib/features/investment/presentation/screens/investment_list_screen.dart` and `lib/features/settings/presentation/screens/settings_screen.dart`, violating Riverpod guidelines (Rule 14.1).
* **Floating Point Crash Risks:** Raw `.toInt()` usage is prevalent in UI widgets and calculations, e.g., `lib/features/income_projection/presentation/screens/income_trend_report_screen.dart`, which can crash on infinity/NaN.

## Duplication Report
* **Investment Form Validation:** There are similarities in validation across different forms (e.g., `lib/features/goals/presentation/screens/create_goal_screen.dart` and `lib/features/investment/presentation/screens/add_investment_screen.dart`).
* **List Selection / Empty States:** `lib/features/goals/presentation/widgets/goals_list_selection_controls.dart` and `lib/features/investment/presentation/widgets/investment_list_selection_controls.dart` are heavily duplicated. Abstract into a reusable `ListSelectionControls` component.

## Reusability Opportunities
* **Shared List Controls:** Consolidate `lib/features/investment/presentation/widgets/investment_list_selection_controls.dart` and `lib/features/goals/presentation/widgets/goals_list_selection_controls.dart`.
* **Empty State Cards:** Several empty state screens across features (Overview, Investments, Goals) should use a common `AppEmptyState` widget to ensure standard accessibility and theming, extracting from `lib/features/overview/presentation/widgets/overview_empty_state.dart`.

## Architecture Review
* **God Classes:** `lib/features/investment/presentation/screens/add_investment_screen.dart` (>1500 lines) needs to be broken down into sub-widgets and independent controller logic. `lib/core/notifications/notification_service.dart`, `lib/core/analytics/analytics_service.dart`, and `lib/core/services/currency_conversion_service.dart` also exceed recommended size.
* **Domain/Data Separation:** Repositories correctly abstract Firebase, but UI sometimes handles business logic for default values instead of delegating to domain.

## Performance Findings
* **Chained Collections:** Found multiple occurrences of `.where().map().toList()` chaining in `lib/features/reports/data/services/report_builder_service.dart` and `lib/features/goals/presentation/providers/goal_progress_provider.dart`. Consolidating to single-pass `for` loops is required for N+1 performance optimizations.

## Security & Reliability Findings
* **Deprecated Security Storage:** `lib/features/security/presentation/providers/security_provider.dart` uses deprecated `encryptedSharedPreferences: true` for `FlutterSecureStorage` which can cause issues on newer Android versions.

## Testing Gaps
* Extensive widget test coverage for widgets containing `.toInt()`, which may fail if calculation defaults to 0-division.
* Missing integration testing on timeout failures to verify local caching fallback works.

## Rules Compliance Findings
* **Rule 19.5 Offline Behavior:** Missing `.timeout(Duration(seconds: 5))` in `lib/core/services/currency_conversion_service.dart` and repository write methods.
* **Rule 14.1 Riverpod Usage:** `ref.read` used in `build()` methods for several UI components (e.g., `lib/features/settings/presentation/screens/settings_screen.dart`).
* **Rule 14 Anti-Pattern:** Multiple files over 500 lines (`lib/features/investment/presentation/screens/add_investment_screen.dart`, `lib/core/services/currency_conversion_service.dart`).
* **Rule 21 Multi-Currency:** Ensure new cashflows correctly wrap the base currency with exchange rate check.

## Recommended Refactor Plan
### Quick Wins
* Replace `.toInt()` with `_safeToInt` across the repository.
* Add `.timeout(Duration(seconds: 5))` to all `.add`, `.set`, `.update` calls.
* Remove deprecated `encryptedSharedPreferences` from `lib/features/security/presentation/providers/security_provider.dart`.

### Medium Effort
* Refactor `.where().map().toList()` chains to single-pass `for` loops.
* Replace `ref.read` in build with `ref.watch` or move callbacks correctly.

### Long-Term
* Break down `lib/features/investment/presentation/screens/add_investment_screen.dart` (1500+ lines) into smaller, reusable widget modules and hooks.
* Consolidate duplicated list controllers.

1. Top 10 highest-value fixes.
   - 1. Add `.timeout(Duration(seconds: 5))` to all Firestore write operations in `lib/features/investment/data/repositories/firestore_investment_repository.dart` and `lib/features/goals/data/repositories/firestore_goal_repository.dart`.
   - 2. Remove deprecated `encryptedSharedPreferences: true` from `lib/features/security/presentation/providers/security_provider.dart`.
   - 3. Replace direct `.toInt()` calls with a safe clamping helper `_safeToInt` in `lib/features/fire_number/presentation/screens/fire_settings_screen.dart` and `lib/features/portfolio_health/presentation/widgets/health_score_trend_chart.dart`.
   - 4. Fix `ref.read` inside `build()` method in `lib/features/investment/presentation/screens/investment_list_screen.dart`.
   - 5. Fix `ref.read` inside `build()` method in `lib/features/settings/presentation/screens/settings_screen.dart`.
   - 6. Optimize `.where().map().toList()` chains into single-pass `for` loops in `lib/features/goals/presentation/providers/goal_progress_provider.dart`.
   - 7. Optimize chained collection operations in `lib/features/reports/data/services/report_builder_service.dart`.
   - 8. Update missing timeout handling in `lib/core/services/currency_conversion_service.dart`.
   - 9. Replace direct `.toInt()` usage in `lib/features/income_projection/presentation/screens/income_trend_report_screen.dart`.
   - 10. Update missing timeouts in `lib/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart`.

2. Top 10 duplication-removal opportunities.
   - 1. Consolidate `lib/features/goals/presentation/widgets/goals_list_selection_controls.dart` and `lib/features/investment/presentation/widgets/investment_list_selection_controls.dart`.
   - 2. Extract shared empty states from `lib/features/overview/presentation/widgets/overview_empty_state.dart` and `lib/features/investment/presentation/screens/investment_list_screen.dart`.
   - 3. Consolidate form validation logic between `lib/features/investment/presentation/screens/add_investment_screen.dart` and `lib/features/goals/presentation/screens/create_goal_screen.dart`.
   - 4. Create a unified currency display formatting widget to avoid repeated `formatCompactCurrency` inline usage.
   - 5. Abstract the chart building logic duplicated in `lib/features/portfolio_health/presentation/widgets/health_score_trend_chart.dart` and `lib/features/reports/presentation/widgets/daily_cashflow_chart.dart`.
   - 6. Combine multiple `simple_csv_parser.dart` files if applicable or standardize import logic.
   - 7. Abstract error snackbars commonly copy-pasted across feature screens in `lib/features/investment/presentation/screens/investment_detail_screen.dart`.
   - 8. Standardize the `PrivacyProtectionWrapper` usage across dashboards.
   - 9. Use a shared list loading skeleton instead of defining it per screen.
   - 10. Unify `lib/features/fire_number/presentation/widgets/fire_milestone_card.dart` and `lib/features/goals/presentation/widgets/goal_progress_ring.dart` visualization logic.

3. Top reusable abstractions worth introducing.
   - 1. `ListSelectionControls` for managing multi-select UI patterns.
   - 2. `AppEmptyState` matching exact theming guidelines.
   - 3. `SafeNumberDisplay` or similar for correctly clamping values and displaying them.
   - 4. `AsyncFirestoreWrite` utility wrapper to enforce `.timeout()` implicitly.
   - 5. `FormValidatorService` or mixin for unified field validations.

4. Files/components with highest technical debt.
   - 1. `lib/features/investment/presentation/screens/add_investment_screen.dart` (1523 lines)
   - 2. `lib/core/analytics/analytics_service.dart` (1440 lines)
   - 3. `lib/core/notifications/notification_service.dart` (1093 lines)
   - 4. `lib/features/investment/presentation/widgets/add_document_sheet.dart` (1020 lines)
   - 5. `lib/core/services/currency_conversion_service.dart` (978 lines)

5. Suggested engineering standards missing from the repository.
   - 1. Enforce max file length via analyzer/linter rules in `analysis_options.yaml` (e.g. max 500 lines).
   - 2. Add an explicit lint rule for `flutter_riverpod` prohibiting `ref.read` in build.
   - 3. Introduce explicit linting for nested/chained iterable operations.
   - 4. Automatically validate Firestore write operations via a custom linter or wrapper constraint.
   - 5. Pre-commit hooks for running tests purely on changed files rather than whole suite.
