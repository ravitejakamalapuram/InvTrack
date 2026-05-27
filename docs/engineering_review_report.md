# Repository-Wide Engineering Review
Date: 2026-05-27

## Executive Summary
* **Overall Repo Health Score**: 7.5/10
* **Biggest Risks**: High cyclomatic complexity in few god classes (e.g. AddInvestmentScreen, InvestmentDetailScreen), missing timeout on some firestore operations, tight coupling in analytics reporting.
* **Highest ROI Improvements**: Extract complex UI components into smaller widgets, introduce proper offline timeouts for all firestore writes, consolidate repeated metric calculations.
* **Architecture Concerns**: The UI widgets `data_management_screen.dart` contains direct API calls (`FirebaseFirestore.instance`) violating Layer Boundaries Rule 1.1.

## Critical Issues
1. **Architecture Rule Violation (UI Layer API Call)**
   - `lib/features/settings/presentation/screens/data_management_screen.dart` directly accesses `FirebaseFirestore.instance` to perform batch deletes. This violates Rule 1.1 (UI -> State -> Domain -> Data).
2. **God Classes / Files**
   - `AddInvestmentScreen` (1500+ lines) is too large and hard to maintain. Needs decomposition into smaller form widgets.
   - `AnalyticsService` (1400+ lines) has bloated event definitions.
3. **Firestore Writes without Timeout**
   - Several Firestore `.add()` / `.update()` calls may lack the required `.timeout(Duration(seconds: 5))` (Rule 4.2).

## Duplication Report
1. **Repeated `.fold` and Iteration Patterns**
   - Metrics like portfolio total, total gains, etc., often iterate the same list multiple times.
   - Example: `multi_currency_providers.dart` and `overview_analytics.dart` have sequential `.fold` calls which can be combined into a single-pass loop.
2. **Form Elements**
   - Multiple screens use similar styling for form inputs, suggesting the need for a unified `AppTextField` or `AppDropdown` component.

## Reusability Opportunities
1. **Unified List Empty State**
   - Extracted `overview_empty_state.dart` could be generalized into a reusable `AppEmptyState` for all list views.
2. **Form Components**
   - Create reusable form fields and validation helpers to simplify `AddInvestmentScreen` and `CreateGoalScreen`.
3. **Single-Pass Aggregation Utility**
   - Extract a helper for calculating `totalValue`, `totalInvested`, `gains` in one pass for a list of investments to prevent O(N*M) iterations.

## Architecture Review
* **Scalability and Maintainability**: Good separation into features. However, Riverpod state management in some providers (`multi_currency_providers.g.dart`) is complex.
* **Rule 1.1 Violations**: As noted, `data_management_screen.dart` needs a dedicated repository/service for its deletion logic.
* **Localization**: A few hardcoded strings found in `report_pdf_exporter.dart` (e.g., 'Week of', 'FY'). Need to migrate to ARB files.

## Performance Findings
* **Excessive Iterations**: Sequential `.fold()` calls in providers over potentially large lists of investments.
* **setState Usage**: Found ~128 instances of `setState`. While some are necessary for local UI state, many should be migrated to Riverpod or `ValueNotifier`.

## Security & Reliability Findings
* **Timeout Missing**: Offline-first operations require 5s timeouts. Needs verification across all Firestore repository implementations.
* **Error Swallowing**: `ConnectivityService` and `CurrencyConversionService` have `catch (e)` blocks that return default values but fail to log to `LoggerService` or Crashlytics.

## Testing Gaps
* Ensure full coverage of the new `report_pdf_exporter.dart` localization.
* Test offline behavior of all forms.

## Rules Compliance Findings
* **Rule 1.1**: Violated in `data_management_screen.dart`.
* **Rule 4.2 (Offline Pattern)**: Some Firestore sets missing timeout.
* **Rule 16.1 (Localization)**: `report_pdf_exporter.dart` contains hardcoded text.

## Recommended Refactor Plan

**Quick Wins (1-2 days)**
1. Move FirebaseFirestore calls out of `data_management_screen.dart` into a service.
2. Fix unlogged `catch` blocks in `ConnectivityService` and `CurrencyConversionService`.
3. Add timeouts to Firestore operations.
4. Localize `report_pdf_exporter.dart`.

**Medium Effort (1-2 weeks)**
1. Refactor `.fold` chains in `multi_currency_providers.dart` and `overview_analytics.dart` to single-pass loops.
2. Consolidate custom form fields into reusable `core/widgets/form_fields/`.

**Long-Term (1-2 months)**
1. Decompose `AddInvestmentScreen` and `InvestmentDetailScreen`.
2. Split `AnalyticsService` into feature-specific analytics classes.

---
## Top 10 Highest-Value Fixes
1. Extract `FirebaseFirestore.instance` out of `data_management_screen.dart`.
2. Replace sequential `.fold()` iterations with single-pass loops in `overview_analytics.dart`.
3. Replace sequential `.fold()` iterations in `multi_currency_providers.dart`.
4. Add `LoggerService.warn` / `error` in `ConnectivityService` empty catch blocks.
5. Add `LoggerService.warn` / `error` in `CurrencyConversionService` empty catch blocks.
6. Enforce `.timeout(Duration(seconds: 5))` on Firestore writes in repositories.
7. Localize strings in `report_pdf_exporter.dart`.
8. Fix `use_build_context_synchronously` warnings in `about_screen.dart` and `in_app_update_initializer.dart`.
9. Replace `.fold()` iterations in `report_builder_service.dart`.
10. Refactor god method in `AnalyticsService`.

## Top 10 Duplication-Removal Opportunities
1. Combine sequential `.fold()` calls calculating total value, invested, and gains.
2. Extract common empty state UI into `AppEmptyState`.
3. Extract common text fields in `AddInvestmentScreen` to reusable widgets.
4. Extract common date picker logic.
5. Create a shared utility for generating PDF report headers (removing hardcoded strings).
6. Consolidate Firebase batch deletion logic into a generic repository method.
7. Merge duplicate currency formatting logic if any exists outside `CompactAmountText`.
8. Unify error handling snakbars into `ErrorHandler.handle`.
9. Consolidate repetitive chart configuration code.
10. Extract common modal sheet drag-handle and header UI.

## Top Reusable Abstractions Worth Introducing
1. `SinglePassAggregator` for O(N) financial metrics calculation.
2. `AppEmptyState` widget.
3. `AppTextFormField` with built-in validation formatting.
4. `BaseFirestoreRepository` with built-in timeout logic.

## Files/Components with Highest Technical Debt
1. `lib/features/investment/presentation/screens/add_investment_screen.dart` (1502 lines)
2. `lib/core/analytics/analytics_service.dart` (1439 lines)
3. `lib/features/settings/presentation/screens/data_management_screen.dart` (Architecture violation)

## Suggested Engineering Standards Missing from the Repository
1. Max File Length Rule (e.g., throw error if > 500 lines).
2. Explicit rule against sequential iterations (`.fold().fold()`) on large collections.
3. Automated check for `catch (e)` blocks missing `LoggerService` / `ErrorHandler`.
