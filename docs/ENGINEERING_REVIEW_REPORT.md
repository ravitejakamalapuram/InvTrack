## Executive Summary
* **Overall Repo Health**: 7.5/10. The project follows Clean Architecture with Riverpod and provides comprehensive multi-currency support, but has significant technical debt in some UI components.
* **Biggest Risks**: Extremely large UI components (add_investment_screen.dart is 1517 lines), mixing business logic with UI, missing timeouts on some Firestore writes, and large God classes (analytics_service.dart, notification_service.dart).
* **Highest ROI Improvements**: Break down add_investment_screen.dart, create reusable form components, ensure all Firestore writes use .timeout(), and address God classes.
* **Architecture Concerns**: The codebase struggles with component size limits and separating presentation logic from business logic, violating Clean Architecture principles in places.

## Critical Issues
* `lib/features/investment/presentation/screens/add_investment_screen.dart` (1517 lines) is a massive "God component" that violates single responsibility and is extremely difficult to maintain.
* `lib/core/analytics/analytics_service.dart` (1439 lines) handles too many specific tracking scenarios. Needs abstraction.
* `lib/core/notifications/notification_service.dart` (1093 lines) and `lib/features/investment/presentation/widgets/add_document_sheet.dart` (1020 lines) are overgrown.
* `lib/core/services/currency_conversion_service.dart` (978 lines) mixes network requests, local storage, and business logic.
* Missing `.timeout(Duration(seconds: 5))` on some Firestore operations (`.add`, `.update`, `.set`), violating Rule 19.5 (Offline Behavior).

## Duplication Report
* **Empty State UI**: `OverviewEmptyState` (684 lines) and `GoalsEmptyState` duplicate logic covered by `EmptyStateWidget`.
* **Form Handling**: Text fields, validation, and styling logic are duplicated across `add_investment_screen.dart` and `add_document_sheet.dart`.
* **Exception Handling**: Repetitive `try-catch` blocks catching `FirebaseException` and mapping to `AppException` in repository layer.
* **Firestore Write Logic**: Repetitive code for creating `batch` updates, setting data, and timeout logic in `firestore_investment_repository.dart`.

## Reusability Opportunities
* **Form Builder Abstraction**: Create a robust, reusable form field wrapper to reduce boilerplate in screens like `add_investment_screen.dart`.
* **Empty State Unification**: Consolidate `OverviewEmptyState` and others into a single `EmptyStateWidget`.
* **Firestore Error Handler**: A centralized utility to handle `FirebaseException` catching, mapping, and timeouts.
* **Date & Number Formatting Utilities**: Ensure consistent use of `formatCompactCurrency()` and centralized date formatters.

## Architecture Review
* **Scalability**: Feature-first folder structure is good, but the `core` folder contains massive services that act as dumping grounds.
* **Maintainability**: Many screens have excessive logic in their `build` methods, tightly coupling UI to state manipulation.
* **Separation of Concerns**: Riverpod providers (like `investment_notifier.dart`, 940 lines) are doing too much. Need to be broken down.
* **Layer Boundaries**: UI widgets sometimes directly interact with formatting or business logic instead of delegating to domain providers.

## Performance Findings
* **Widget Rebuilds**: Large screens like `add_investment_screen.dart` likely suffer from unnecessary re-renders. Need smaller `ConsumerWidget` components.
* **Array Operations**: While some chained operations like `.toList().sort()` were fixed, ensure loops are used instead of chaining `.map().where().toList()` for large datasets.
* **Async Code in UI**: Some UI components might be performing async tasks directly instead of relying on Riverpod's `AsyncValue`.

## Security & Reliability Findings
* **Offline Safety**: Missing `.timeout(Duration(seconds: 5))` on multiple Firestore write operations (e.g., `.add`, `.update`, `.set`), risking app hangs in poor network conditions.
* **Swallowed Errors**: Need to ensure that all `try-catch` blocks log errors properly to Crashlytics and don't just fail silently.
* **Encrypted Storage**: Validate that `FlutterSecureStorage` is used correctly for sensitive data without deprecated Android options.

## Testing Gaps
* **Massive Test Files**: Huge service files likely have correspondingly massive, unmaintainable test files.
* **Contract Tests**: Missing contract/integration tests for currency APIs to detect upstream changes.
* **Widget Testing**: `add_investment_screen.dart` is too large to test effectively. Needs smaller widget tests.

## Rules Compliance Findings
* **Rule 14.1 (Riverpod)**: Must ensure `ref.read` is NOT used inside `build()` methods anywhere.
* **Rule 19.5 (Offline Behavior)**: ALL Firestore write operations (`.add`, `.update`, `.set`) MUST include a `.timeout(Duration(seconds: 5))`. (Found violations).
* **Rule 19.3 (Accessibility)**: Ensure custom widgets have appropriate `Semantics`.
* **Rule 21.1 (Multi-currency)**: Ensure original data is never changed when base currency changes.

## Recommended Refactor Plan
### Quick Wins
* Enforce `.timeout(Duration(seconds: 5))` on all Firestore write operations.
* Fix any `ref.read` in `build()` violations.
### Medium Effort
* Consolidate Empty States into a reusable widget.
* Create reusable Form components to reduce boilerplate.
### Long-term Architecture
* Break down `add_investment_screen.dart` into specialized widgets.
* Refactor `analytics_service.dart` and `notification_service.dart`.

### Top 10 highest-value fixes
1. Refactor `add_investment_screen.dart` (1517 lines) into smaller widgets.
2. Add missing `.timeout(Duration(seconds: 5))` to all Firestore writes.
3. Decouple `analytics_service.dart` (1439 lines).
4. Break down `notification_service.dart` (1093 lines).
5. Refactor `add_document_sheet.dart` (1020 lines).
6. Abstract logic out of `currency_conversion_service.dart` (978 lines).
7. Refactor `investment_notifier.dart` (940 lines) into granular providers.
8. Enforce centralized error handling for Firestore exceptions.
9. Unify empty state duplicate code into `EmptyStateWidget`.
10. Ensure no `ref.read` inside Riverpod `build()` methods.

### Top 10 duplication-removal opportunities
1. Empty state UI elements (`OverviewEmptyState`, `GoalsEmptyState`).
2. Form field styles, validation, and error handling.
3. Repetitive `try-catch` Firestore exception mapping.
4. Custom bottom sheet skeleton logic.
5. Number and currency formatting implementations.
6. Date formatting strings.
7. Loading skeletons and shimmer effects.
8. Localized dialog prompts.
9. Snack bar notifications.
10. Theme color extractors.

### Top reusable abstractions
1. `AppFormBuilder` / `AppTextField`
2. `AppEmptyState` / `EmptyStateWidget`
3. `FirestoreExceptionHandler`
4. `AsyncValueWrapper` (for Riverpod UI states)
5. `CompactAmountText` (enforce usage)

### Files/components with highest technical debt
1. `lib/features/investment/presentation/screens/add_investment_screen.dart`
2. `lib/core/analytics/analytics_service.dart`
3. `lib/core/notifications/notification_service.dart`
4. `lib/features/investment/presentation/widgets/add_document_sheet.dart`
5. `lib/core/services/currency_conversion_service.dart`

### Suggested missing engineering standards
1. Strict file length limits (e.g., maximum 500 lines per file).
2. Centralized API/Firestore exception wrapper enforcement.
3. Mandatory UI separation for screens vs. complex widgets.
4. Explicit unit testing rules for large services.
5. Rule to enforce smaller Riverpod providers.
