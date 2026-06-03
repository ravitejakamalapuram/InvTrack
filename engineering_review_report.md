# Enterprise Engineering Review Report - InvTrack

## Executive Summary
* **Overall Repo Health Score:** 78/100 (B+)
* **Biggest Risks:**
  * Massive god classes/files (e.g., `add_investment_screen.dart` is 1502 lines, `analytics_service.dart` is 1439 lines).
  * Direct infrastructure coupling in UI components (e.g., `data_management_screen.dart` accessing `FirebaseFirestore` directly).
  * Hardcoded API keys in `firebase_options.dart`.
  * Widespread code duplication in notification scheduling blocks.
  * Over 50 instances of missing `.timeout()` clauses on Firestore writes, violating Rule 19.5 (Offline Behavior).
  * Improper Riverpod usage (`ref.read` in `build` methods) present in 41 instances across the codebase, causing stale UI states.
* **Highest ROI Improvements:**
  * Component decomposition for large UI screens.
  * Extracing direct Firebase logic from UI into Domain/Data layers to strictly comply with Clean Architecture Rule 1.1.
  * Fixing exception swallowing (e.g., in `simple_csv_parser.dart`).
  * Enforcing `.timeout()` on all Firestore operations to ensure offline resilience.
* **Architecture Concerns:**
  * Clean Architecture boundary violations. The `presentation` layer is leaking into the `data` layer responsibilities in settings, specifically in `data_management_screen.dart`.
  * Improper Riverpod usage (`ref.read` in `build` methods) severely limits reactivity and violates Rule 14.1.

## Critical Issues
1. **Hardcoded Secrets in Source Code:** `lib/firebase_options.dart` contains hardcoded Google API keys. While sometimes standard for Firebase initialization, in enterprise settings these should be injected via environment variables (`--dart-define`) to avoid exposing keys for different environments.
2. **Clean Architecture Violations in UI:** `lib/features/settings/presentation/screens/data_management_screen.dart` directly imports and uses `FirebaseFirestore` to perform batch deletions. This tightly couples the UI to the database, making it untestable and breaking Layer Boundaries Rule 1.1.
3. **Improper Riverpod Usage:** 41 files use `ref.read` directly inside `build()` methods (e.g., `app.dart`, `debug_settings_screen.dart`, `investment_list_screen.dart`). This is a severe anti-pattern in Riverpod that prevents widgets from properly rebuilding when state changes, directly violating Rule 14.1.
4. **Exception Swallowing:** `lib/features/bulk_import/data/services/simple_csv_parser.dart` and `lib/features/settings/data/services/data_import_service.dart` have empty or silent catch blocks, swallowing errors and hiding potential data import failures from users and Crashlytics.
5. **Firestore Writes without Timeout:** Over 50 instances of Firestore writes (e.g. in `firestore_investment_repository.dart`, `firestore_goal_repository.dart`) lack the required `.timeout(Duration(seconds: 5))` clause required by Rule 19.5 (Offline Behavior).

## Duplication Report
1. **Notification Handler Logic:** `lib/core/notifications/handlers/scheduled_notification_handler.dart` and `notification_service.dart` contain identical blocks for handling different notification types (`await notificationService.scheduleNotification`).
   * *Why it is problematic:* Changing notification behavior requires changes in multiple places, increasing the risk of bugs.
   * *Duplication spread:* Scattered across the notifications module.
   * *Consolidation Suggestion:* Abstract into a generic `BaseNotificationStrategy` class or factory.
2. **Error Handling Boilerplate:** Repetitive `ScaffoldMessenger.of(context).showSnackBar` calls scattered across catch blocks in screens like `debug_settings_screen.dart` and `data_management_screen.dart`.
   * *Why it is problematic:* Inconsistent error presentation and styling across the app.
   * *Duplication spread:* 20+ instances in presentation layer.
   * *Consolidation Suggestion:* Extract to a global `AppFeedback` or `SnackbarService` to standardize error UI across the application.
3. **UI State Boilerplate:** Progress rings and empty state structures are duplicated across `goals_screen.dart`, `fire_dashboard_screen.dart`, and `investment_list_states.dart`.
   * *Why it is problematic:* Makes it difficult to enforce a unified design system.
   * *Duplication spread:* Common across multiple main feature tabs.
   * *Consolidation Suggestion:* Extract to a `SharedListEmptyState` widget.

## Reusability Opportunities
1. **Reusable Form Elements:** `AddInvestmentScreen` (1502 lines) and `CreateGoalScreen` share multiple form patterns and input styles. We should create reusable `AppTextField` or `AppDropdown` components.
2. **Reusable State Handlers:** Abstract the `toggleSelection` and list filtering logic shared between `goals_list_state_provider.dart` and `investment_list_state_provider.dart` into a generic Riverpod Notifier mixin (`SelectionListNotifier`).
3. **Generic Exporters:** The `_typeToExportString` logic duplicated in `data_export_service.dart` and `export_service.dart` should be moved to a shared domain utility or extension method.

## Architecture Review
* **Scalability and Maintainability:** High risk due to "God Files" (`add_investment_screen.dart` is 1502 lines, `analytics_service.dart` is 1439 lines). These files violate the Single Responsibility Principle and are hard to maintain. They indicate an over-centralization of logic that should be decomposed into smaller, specialized classes.
* **Separation of Concerns:** Leaky boundaries in Settings feature. UI handles business logic and direct database access (`data_management_screen.dart`), bypassing Domain and Data layers.
* **Dependency Management:** Good use of Riverpod overall, but inconsistent application (mixing `watch` and `read` improperly).

## Performance Findings
* **Excessive Rebuilds:** Found 124 uses of `setState`. While some are necessary for local UI state, many should be migrated to Riverpod or `ValueNotifier`. Lack of `.select` usage in Riverpod providers means entire large screens may rebuild unnecessarily on minor state changes.
* **Oversized Bundles/Memory Risks:** The 1500+ line screens carry a lot of widget instances in a single build method, potentially causing frame drops and UI jank during rendering.
* **Redundant Transformations:** Possible O(N*M) aggregations in provider `.fold` chains if list size increases significantly.

## Security & Reliability Findings
* **Firestore Timeouts Missing:** Offline-first operations require 5s timeouts (Rule 19.5). Found missing across multiple repository implementations. Impact: App hangs offline.
* **Exception Swallowing:** Found instances where exceptions are caught but neither logged to Crashlytics nor shown to the user, particularly in CSV parsing.
* **Raw Exceptions Displayed:** Multiple screens catch raw exceptions and show them directly in the UI instead of using the centralized `ErrorHandler.handle()` and `AppException` types, exposing stack traces or raw error codes to users.

## Testing Gaps
* While many features have tests, the large files (like `add_investment_screen.dart` and `analytics_service.dart`) are notoriously difficult to unit test due to their size. Test coverage for these monolithic classes is likely low at the unit level, relying heavily on integration tests.
* **Offline Behavior Testing:** Ensure tests cover offline scenarios given the missing `.timeout()` implementations.

## Rules Compliance Findings
* **Rule 1.1 (Clean Architecture):** Violated in `data_management_screen.dart` (Firestore in UI). Impact: High coupling. Fix: Move logic to a `DataManagementRepository`.
* **Rule 14.1 (Riverpod `ref.read` in `build`):** Violated in 41 files. Impact: Stale UI. Fix: Change to `ref.watch()`.
* **Rule 16.1 (Localization):** Found hardcoded strings like `'FY '` and `'Week of '` in `report_pdf_exporter.dart` and `report_csv_exporter.dart`. Impact: Poor localization support. Fix: Move to ARB files.
* **Rule 19.5 (Offline Behavior):** Violated in multiple Firestore calls missing `.timeout(Duration(seconds: 5))`. Impact: App hangs offline. Fix: Append `.timeout()` to all Firestore Futures.

## Recommended Refactor Plan

**Quick Wins (Days 1-3)**
1. Fix all `ref.read()` inside `build()` methods to use `ref.watch()`.
2. Add `.timeout(Duration(seconds: 5))` to all missing Firestore queries.
3. Replace hardcoded strings in `report_pdf_exporter.dart` and `report_csv_exporter.dart` with localized `l10n` calls.
4. Fix the empty catch blocks in `simple_csv_parser.dart` to throw an `AppException(shouldReport: true)`.

**Medium Effort (Weeks 1-2)**
1. Refactor `data_management_screen.dart` to remove Firestore imports and use a dedicated Repository/Provider.
2. Replace raw `ScaffoldMessenger` error handling with `AppFeedback` utility.
3. Consolidate notification scheduling logic into a single reusable strategy.

**Long-Term Architecture (Months 1-2)**
1. Split `add_investment_screen.dart` (1502 lines) into smaller, logical sub-components (e.g., `InvestmentFormDetails`, `InvestmentFormCalculations`).
2. Modularize `analytics_service.dart` (1439 lines) by event domains.
3. Migrate API keys in `firebase_options.dart` to build-time environment variables.

---

### 1. Top 10 Highest-Value Fixes
1. Fix Clean Architecture violation in `data_management_screen.dart` (Remove direct Firestore access).
2. Fix `ref.read` inside `build` methods across the app (41 files) to prevent stale UI bugs.
3. Enforce `.timeout(Duration(seconds: 5))` on Firestore writes across all repositories for offline resilience.
4. Break down `add_investment_screen.dart` (1502 lines).
5. Break down `analytics_service.dart` (1439 lines).
6. Fix empty catch block swallowing errors in `simple_csv_parser.dart`.
7. Move API keys in `firebase_options.dart` to environment variables.
8. Remove raw exceptions from UI (`ScaffoldMessenger` in catch blocks) in favor of `ErrorHandler.handle()`.
9. Localize hardcoded strings in `report_pdf_exporter.dart` and `report_csv_exporter.dart`.
10. Refactor unlogged exceptions returning values in `data_import_service.dart`.

### 2. Top 10 Duplication-Removal Opportunities
1. Notification scheduling logic blocks.
2. Repeated raw Exception catching & Snackbars (replace with `AppFeedback`).
3. Export logic `_typeToExportString` (DataExportService & ExportService).
4. List Selection State (`toggleSelection` in Goals and Investments).
5. Empty State layouts (Goals, FIRE, Investments).
6. Common Firestore query boilerplate (extract to `BaseFirestoreRepository`).
7. Progress Ring layout code (Goals vs FIRE).
8. Text field input decoration and validation styles in form screens.
9. Common date picker logic and display formatting.
10. Modal bottom sheet header and drag handle structures.

### 3. Top Reusable Abstractions Worth Introducing
1. `BaseNotificationStrategy` for handling different notification types.
2. `AppFeedback` / `SnackbarService` for unified error reporting and `ErrorHandler.handle` integration.
3. `SharedListEmptyState` widget to standardize list empty states.
4. `SelectionListNotifier` mixin for shared Riverpod list selection states.
5. `EnvironmentConfig` for securely injecting build-time variables.

### 4. Files/Components with Highest Technical Debt
1. `lib/features/investment/presentation/screens/add_investment_screen.dart` (God UI Class - 1502 lines)
2. `lib/core/analytics/analytics_service.dart` (God Service Class - 1439 lines)
3. `lib/features/settings/presentation/screens/data_management_screen.dart` (Architecture Violations)
4. `lib/core/notifications/notification_service.dart` (1093 lines)
5. `lib/features/investment/presentation/widgets/add_document_sheet.dart` (1020 lines)

### 5. Suggested Engineering Standards Missing from the Repository
1. **Max File Size Limit:** Introduce a linter rule (e.g., `analyzer_plugin` or custom CI script) to fail builds for files > 500 lines to prevent God classes.
2. **Strict Architecture Lints:** Use `dart_code_metrics` or similar to strictly ban cross-layer imports (e.g., `import 'package:cloud_firestore/...` in `presentation/`).
3. **Environment Variable Enforcement:** Document strict standards for secrets management (no hardcoded keys in source).
4. **Offline Resilience Lints:** Automated custom lint to ensure all Firebase futures have `.timeout()` chained.
5. **Exception Handling Standard:** Automated check for `catch (e)` blocks missing `LoggerService` / `ErrorHandler`.
