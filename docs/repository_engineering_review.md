# InvTrack Repository Engineering Review

## Executive Summary
* **Overall Repo Health Score**: 8.5/10
* **Biggest Risks**: Incomplete error handling in asynchronous operations, large monolithic files, excessive duplication of UI patterns.
* **Highest ROI Improvements**: Refactor duplicate UI elements into reusable components, optimize list operations for performance, and componentize oversized screens.
* **Architecture Concerns**: Oversized files masking God components, mixing of data logic in UI components in some areas.

## Critical Issues
* Oversized files acting as "God Classes" (e.g., `lib/features/investment/presentation/screens/add_investment_screen.dart` is over 1500 lines). These require immediate decomposition to improve maintainability.
* Deeply nested list operations and sorting in providers and services (e.g., in analytics and CSV parsing) that cause performance bottlenecks.
* Missing accessibility semantics on interactive widgets. InkWell elements inside custom cards often lack semantic labels, which violates accessibility standards and rule 19.3.

## Duplication Report
* **Repeated UI Patterns**: Empty states are duplicated across features (`overview_empty_state.dart`, and other screens). Consider a unified `AppEmptyState` component.
* **Form Logic**: Repetitive validation and form submission logic in data entry screens (Add Investment, Add Goal, etc.). Consolidate into a reusable form abstraction.
* **API/Repository Handling**: Repeated error catching and logging logic in repositories. Use a centralized error handling wrapper for Firestore calls.

## Reusability Opportunities
* **Reusable Empty State**: Consolidate various empty state widgets into a single configurable `AppEmptyState`.
* **Reusable Error State**: Implement a unified `ErrorState` component across all async providers.
* **Form Abstractions**: Create reusable form fields and validation utilities.

## Architecture Review
* **Scalability**: The Riverpod integration is generally good, but large provider files (`investment_notifier.dart` is 940 lines) indicate logic bloat. Extract specific use cases to independent providers.
* **Maintainability**: Several screens are massive (e.g., `add_investment_screen.dart` > 1500 lines, `fire_setup_screen.dart` > 600 lines). Break these down into smaller widgets.
* **Separation of Concerns**: Ensure UI components don't contain heavy business logic; push this to providers or domain services.

## Performance Findings
* **Inefficient List Operations**: Chained operations like `.toList().sort()` are common. Sort directly or use more efficient data structures.
* **UI Rebuilds**: Ensure Riverpod providers use `select` to minimize unnecessary rebuilds on large screens.

## Security & Reliability Findings
* **Error Swallowing**: Check Riverpod `AsyncValue.when` implementation to ensure errors aren't silently swallowed.
* **Offline Persistence**: Ensure all Firestore writes use timeouts as per Rule 19.5 to guarantee offline functionality.

## Testing Gaps
* Massive test files (`notification_service_test.dart` > 1400 lines) suggest complex logic that might be missing edge case coverage.
* Break down large test suites and improve unit test isolation.

## Rules Compliance Findings
* **Rule 19.3 Accessibility**: Missing `Semantics` wrapper on custom `InkWell` components (e.g., in settings and reports).
* **Rule 14.1 Riverpod**: Review `build()` methods to ensure `ref.read` is not used directly.
* **Rule 19.5 Offline Behavior**: Verify all Firestore `.set` / `.update` calls have `.timeout()`.

## Recommended Refactor Plan

### Quick Wins (1-2 Sprints)
* Add missing `Semantics` wrappers to all `InkWell` and custom interactive widgets.
* Fix inefficient list sorting operations in providers and services.
* Unify Empty State widgets into a single shared component.

### Medium Effort (2-3 Sprints)
* Refactor massive screens (`add_investment_screen.dart`, `investment_detail_screen.dart`) into smaller widget files.
* Decompose large test files to improve maintainability.

### Long-Term Architecture (3+ Sprints)
* Refactor large providers (`investment_notifier.dart`) by extracting domain logic into dedicated services.
* Implement centralized error handling for all Firestore repository calls.

---

### Top 10 Highest-Value Fixes
1. Decompose `add_investment_screen.dart` (1517 lines) into smaller sub-widgets.
2. Refactor `investment_notifier.dart` (940 lines) to split logic.
3. Optimize chained `.toList().sort()` list operations in data services.
4. Add missing `Semantics` wrappers to `InkWell` widgets in settings and reports.
5. Decompose `notification_service_test.dart` (1424 lines).
6. Verify all Firestore writes have `.timeout()` for offline support.
7. Unify duplicated empty state UI components.
8. Implement a centralized error wrapper for repository calls.
9. Refactor `currency_conversion_service.dart` (978 lines).
10. Ensure no `ref.read` calls inside Riverpod `build()` methods.

### Top 10 Duplication-Removal Opportunities
1. Empty state widgets across different feature modules.
2. Form field validation logic in entry screens.
3. Firestore error catching and logging blocks.
4. Loading state skeleton screens.
5. Common header/app bar configurations.
6. Number formatting utilities.
7. Theme text style overrides.
8. Bottom sheet boilerplate wrappers.
9. Basic dialog implementations.
10. Snack bar notification calls.

### Top Reusable Abstractions
1. `AppEmptyState` widget.
2. Centralized Firestore `RepositoryExceptionHandler`.
3. `AppFormBuilder` for consistent data entry.
4. Generic `PaginationController` for lists.
5. Shared `AsyncValueWidget` for handling Riverpod states.

### Files/Components With Highest Technical Debt
1. `lib/features/investment/presentation/screens/add_investment_screen.dart`
2. `lib/features/investment/presentation/providers/investment_notifier.dart`
3. `lib/core/services/currency_conversion_service.dart`
4. `test/core/notifications/notification_service_test.dart`
5. `lib/features/fire_number/presentation/screens/fire_setup_screen.dart`

### Suggested Missing Engineering Standards
1. Max lines per file rule (e.g., max 500 lines for screens, 300 for widgets).
2. Explicit requirement for centralized API/Firestore error handling.
3. Strict guidelines on list manipulation performance (e.g., avoid multiple `.map().toList()`).
4. Mandated accessibility automated testing.
5. Required extraction of form logic to distinct controller classes.
