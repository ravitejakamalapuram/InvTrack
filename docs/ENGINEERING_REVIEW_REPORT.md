# Engineering Review Report
Generated on: 2026-07-10

## Executive Summary
* **Overall repo health score:** 75/100
* **Biggest risks:**
  1. Missing Firestore offline timeouts leading to silent failure scenarios during transient network drops.
  2. Severe architectural drift in large screen widgets containing complex logic and violating Riverpod best practices (`ref.read` in build).
  3. Floating point crash risks due to prevalent `.toInt()` calls on division results.
* **Highest ROI improvements:**
  1. Wrap `.toInt()` operations with `_safeToInt()`.
  2. Add `.timeout(Duration(seconds: 5))` to Firestore write operations.
  3. Extract repeated multi-select List UI controls.
* **Architecture concerns:** Multiple God classes exist (e.g. `add_investment_screen.dart`, `analytics_service.dart`, `notification_service.dart`) that break the 500-line rule (Rule 14 Anti-Pattern). Clean Architecture boundaries are respected, but UI components are sometimes heavily overloaded with side effects.

## Critical Issues
* **Firestore Offline Handling:** Several `lib/features/investment/data/repositories/firestore_investment_repository.dart` and `lib/features/goals/data/repositories/firestore_goal_repository.dart` write operations do not have `.timeout(Duration(seconds: 5))`, violating Rule 19.5.
* **UI Rebuild and Riverpod Violations:** Calling `ref.read()` inside `build` method in files like `lib/features/settings/presentation/screens/settings_screen.dart` and `lib/features/income_projection/presentation/screens/income_calendar_screen.dart`, violating Riverpod guidelines (Rule 14.1).
* **Floating Point Crash Risks:** Raw `.toInt()` usage is prevalent in UI widgets and calculations, e.g., `lib/features/income_projection/presentation/screens/income_trend_report_screen.dart`, which can crash on infinity/NaN.

## Duplication Report
* **Investment Form Validation:** There are similarities in validation across different forms (e.g., `lib/features/goals/presentation/screens/create_goal_screen.dart` and `lib/features/investment/presentation/screens/add_investment_screen.dart`).
* **List Selection / Empty States:** `lib/features/goals/presentation/widgets/goals_list_selection_controls.dart` and `lib/features/investment/presentation/widgets/investment_list_selection_controls.dart` are heavily duplicated. Abstract into a reusable `ListSelectionControls` component.
* **Empty States:** Duplicated empty state widgets across `lib/core/widgets/empty_state_widget.dart`, `lib/features/goals/presentation/widgets/goals_empty_state.dart`, and `lib/features/overview/presentation/widgets/overview_empty_state.dart`.

## Reusability Opportunities
* **Shared List Controls:** Consolidate `lib/features/investment/presentation/widgets/investment_list_selection_controls.dart` and `lib/features/goals/presentation/widgets/goals_list_selection_controls.dart`.
* **Empty State Cards:** Consolidate multiple empty state implementations into a single `AppEmptyState` widget to ensure standard accessibility and theming.

## Architecture Review
* **God Classes:** `lib/features/investment/presentation/screens/add_investment_screen.dart` (>1500 lines) needs to be broken down into sub-widgets and independent controller logic. `lib/core/analytics/analytics_service.dart` and `lib/core/notifications/notification_service.dart` also exceed recommended sizes.
* **Layer Leakage:** Navigation logic and data-fetching orchestration is occasionally found in the data layer rather than domain.
* **Unnecessary Re-renders:** Widespread Riverpod `ref.watch` on entire providers rather than using `ref.select` for specific fields.

## Performance Findings
* **Chained Collections:** Found multiple occurrences of `.where().map().toList()` chaining in `lib/features/reports/data/services/portfolio_health_service.dart` and `lib/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart`. Consolidating to single-pass `for` loops is required.
* **Redundant Await in Loops:** Redundant await in iteration loops located in `lib/core/services/currency_conversion_service.dart` and `lib/features/settings/data/services/data_import_service.dart`.

## Security & Reliability Findings
* **Stale Security Configs:** Jetpack Security is deprecated, and `encryptedSharedPreferences` references should be fully removed if not already per project memory.

## Testing Gaps
* Missing test coverage on Widget tests containing potentially unsafe math `.toInt()`.
* Missing contract tests for timeout behavior logic on repositories.
* Integration tests should ensure UI graceful degradation offline.

## Rules Compliance Findings
* **Rule 19.5 Offline Behavior:** Missing `.timeout(Duration(seconds: 5))` in `lib/core/services/currency_conversion_service.dart` and repository write methods.
* **Rule 14.1 Riverpod Usage:** `ref.read` used in `build()` methods for several UI components (e.g., `lib/app/app.dart`).
* **Rule 14 Anti-Pattern:** Multiple files over 500 lines (`lib/features/investment/presentation/screens/add_investment_screen.dart`, `lib/core/analytics/analytics_service.dart`).
* **Rule 21 Multi-Currency:** Ensure new cashflows correctly wrap the base currency with exchange rate check.

## Recommended Refactor Plan
### Quick Wins
* Replace `.toInt()` with `_safeToInt` across the repository.
* Add `.timeout(Duration(seconds: 5))` to all `.add`, `.set`, `.update` calls.

### Medium Effort
* Refactor `.where().map().toList()` chains to single-pass `for` loops.
* Replace `ref.read` in build with `ref.watch` or move callbacks correctly.

### Long-Term
* Break down `lib/features/investment/presentation/screens/add_investment_screen.dart` (1500+ lines) into smaller, reusable widget modules and hooks.
* Consolidate duplicated list controllers and empty states.

1. Top 10 highest-value fixes.
   1. Add `.timeout(Duration(seconds: 5))` to all Firestore write operations in `lib/features/investment/data/repositories/firestore_investment_repository.dart`.
   2. Fix `ref.read` inside `build()` method in `lib/features/settings/presentation/screens/settings_screen.dart`.
   3. Replace direct `.toInt()` calls with a safe clamping helper `_safeToInt` in `lib/features/income_projection/presentation/screens/income_trend_report_screen.dart`.
   4. Add missing `.timeout(Duration(seconds: 5))` in `lib/features/goals/data/repositories/firestore_goal_repository.dart`.
   5. Optimize chained collection operations in `lib/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart`.
   6. Remove deprecated `encryptedSharedPreferences: true` from `lib/features/security/presentation/providers/security_provider.dart` (if present).
   7. Fix `ref.read` inside `build()` method in `lib/app/app.dart`.
   8. Optimize chained collection operations in `lib/features/reports/data/services/portfolio_health_service.dart`.
   9. Update missing timeouts in `lib/features/income_projection/data/repositories/firestore_expected_cash_flow_repository.dart`.
   10. Replace direct `.toInt()` usage in `lib/features/reports/presentation/widgets/daily_cashflow_chart.dart`.

2. Top 10 duplication-removal opportunities.
   1. Consolidate `lib/features/goals/presentation/widgets/goals_list_selection_controls.dart` and `lib/features/investment/presentation/widgets/investment_list_selection_controls.dart`.
   2. Extract shared empty states from `lib/features/overview/presentation/widgets/overview_empty_state.dart` and `lib/features/goals/presentation/widgets/goals_empty_state.dart`.
   3. Consolidate form validation logic between `lib/features/investment/presentation/screens/add_investment_screen.dart` and `lib/features/goals/presentation/screens/create_goal_screen.dart`.
   4. Create a unified currency display formatting widget to avoid repeated `formatCompactCurrency` inline usage.
   5. Combine multiple `simple_csv_parser.dart` files if applicable or standardize import logic.
   6. Abstract error snackbars commonly copy-pasted across feature screens in `lib/features/investment/presentation/screens/investment_detail_screen.dart`.
   7. Standardize the `PrivacyProtectionWrapper` usage across dashboards.
   8. Use a shared list loading skeleton instead of defining it per screen.
   9. Abstract the chart building logic duplicated in `lib/features/portfolio_health/presentation/widgets/health_score_trend_chart.dart` and `lib/features/reports/presentation/widgets/daily_cashflow_chart.dart`.
   10. Unify `lib/features/fire_number/presentation/widgets/fire_milestone_card.dart` and `lib/features/goals/presentation/widgets/goal_progress_ring.dart` visualization logic.

3. Top reusable abstractions worth introducing.
   1. `ListSelectionControls` for managing multi-select UI patterns.
   2. `AppEmptyState` matching exact theming guidelines.
   3. `SafeNumberDisplay` or similar for correctly clamping values and displaying them.
   4. `AsyncFirestoreWrite` utility wrapper to enforce `.timeout()` implicitly.
   5. `FormValidatorService` or mixin for unified field validations.

4. Files/components with highest technical debt.
   1. `lib/features/investment/presentation/screens/add_investment_screen.dart` (1523 lines)
   2. `lib/core/analytics/analytics_service.dart` (1440 lines)
   3. `lib/core/notifications/notification_service.dart` (1093 lines)
   4. `lib/features/investment/presentation/widgets/add_document_sheet.dart` (1021 lines)
   5. `lib/core/services/currency_conversion_service.dart` (978 lines)

5. Suggested engineering standards missing from the repository.
   1. Enforce max file length via analyzer/linter rules in `analysis_options.yaml` (e.g. max 500 lines).
   2. Add an explicit lint rule for `flutter_riverpod` prohibiting `ref.read` in build.
   3. Introduce explicit linting for nested/chained iterable operations.
   4. Automatically validate Firestore write operations via a custom linter or wrapper constraint.
   5. Pre-commit hooks for running tests purely on changed files rather than whole suite.
