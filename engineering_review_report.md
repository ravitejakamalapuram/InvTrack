
# Enterprise Engineering Review Report - InvTrack

## Executive Summary
* **Overall Repo Health Score:** 78/100 (B+)
* **Biggest Risks:**
  * Massive god classes/files (e.g., `add_investment_screen.dart` is 1500+ lines, `analytics_service.dart` is 1400+ lines).
  * Direct infrastructure coupling in UI components (e.g., `data_management_screen.dart` accessing Firestore and Auth directly).
  * Hardcoded API keys in `firebase_options.dart`.
  * Widespread code duplication in notification scheduling blocks.
* **Highest ROI Improvements:**
  * Component decomposition for large UI screens.
  * Extracing direct Firebase logic from UI into Domain/Data layers to strictly comply with Clean Architecture.
  * Fixing exception swallowing (e.g., in `simple_csv_parser.dart`).
* **Architecture Concerns:**
  * Clean Architecture boundary violations. The `presentation` layer is leaking into the `data` layer responsibilities in settings.
  * Improper Riverpod usage (`ref.read` in `build` methods).

## Critical Issues
1. **Hardcoded Secrets in Source Code:** `lib/firebase_options.dart` contains hardcoded Google API keys. While sometimes standard for Firebase, in enterprise settings these should be injected via environment variables (`--dart-define`) to avoid exposing different environment keys.
2. **Clean Architecture Violations in UI:** `lib/features/settings/presentation/screens/data_management_screen.dart` directly imports and uses `FirebaseFirestore` and `FirebaseAuth`. This tightly couples the UI to the database, making it untestable and breaking Rule #16 (Architecture Rules).
3. **Improper Riverpod Usage:** 10 files use `ref.read` directly inside `build()` methods (e.g., `app.dart`, `debug_settings_screen.dart`). This is a severe anti-pattern in Riverpod that prevents widgets from properly rebuilding when state changes, directly violating Rule 14.1.
4. **Exception Swallowing:** `lib/features/bulk_import/data/services/simple_csv_parser.dart` has an empty catch block, swallowing errors and hiding potential data import failures from users and crashlytics.

## Duplication Report
1. **Notification Handler Logic:** `lib/core/notifications/handlers/scheduled_notification_handler.dart` and `notification_service.dart` contain identical 10-line blocks repeated 5-6 times for handling different notification types.
   * *Consolidation Suggestion:* Abstract into a generic `BaseNotificationStrategy` class or factory.
2. **UI State Boilerplate:** Progress rings (`goal_progress_ring.dart` and `fire_progress_ring.dart`) have duplicated layout logic blocks.
   * *Consolidation Suggestion:* Create a reusable `CircularProgressWidget` that accepts generic parameters.
3. **Empty States & List States:** `goals_screen.dart`, `fire_dashboard_screen.dart`, and `investment_list_states.dart` share duplicated UI structural patterns.
   * *Consolidation Suggestion:* Extract to a `SharedListEmptyState` widget.

## Reusability Opportunities
1. **Reusable State Handlers:** Abstract the `toggleSelection` logic shared between `goals_list_state_provider.dart` and `investment_list_state_provider.dart` into a generic Riverpod Notifier mixin.
2. **Generic Exporters:** The `_typeToExportString` logic duplicated in `data_export_service.dart` and `export_service.dart` should be moved to a shared domain utility or extension method.
3. **Generic Error Handlers:** Extract the repetitive `ScaffoldMessenger` error displays into a global `AppFeedback` or `SnackbarService` to standardize error UI across the application.

## Architecture Review
* **Scalability:** High risk due to "God Files" (`add_investment_screen.dart` - 1500 lines, `analytics_service.dart` - 1440 lines). These files violate the Single Responsibility Principle and are hard to maintain.
* **Separation of Concerns:** Leaky boundaries in Settings feature. UI handles business logic and data access.
* **Dependency Management:** Good use of Riverpod, but inconsistent application (mixing `watch` and `read` improperly).

## Performance Findings
* **Async in Build:** `lib/core/widgets/swipe_to_delete.dart` contains async operations inside the build flow, which can cause frame drops and UI jank.
* **Large Rebuilds:** Lack of `.select` usage in Riverpod providers means entire large screens (like the 1500-line Add Investment Screen) may rebuild unnecessarily on minor state changes.

## Security & Reliability Findings
* **Firestore Timeouts:** `data_management_screen.dart` is missing `.timeout()` clauses on Firestore reads, violating Rule 19.5 (Offline Behavior) and potentially causing infinite hangs if offline.
* **Raw Exceptions Displayed:** Multiple screens (`data_management_screen.dart`, `about_screen.dart`) catch raw exceptions and show them directly in the UI instead of using the centralized `ErrorHandler.handle()` and `AppException` types.

## Testing Gaps
* While 13 features have tests, the large files (like `add_investment_screen.dart` and `analytics_service.dart`) are notoriously difficult to unit test due to their size. We need to verify if these monolithic classes have adequate test coverage or if they rely entirely on integration tests.

## Rules Compliance Findings
* **Rule 14.1 (Riverpod `ref.read` in `build`):** Violated in 10 files. Impact: Stale UI. Fix: Change to `ref.watch()`.
* **Rule 16 (Clean Architecture):** Violated in `data_management_screen.dart` (Firestore in UI). Impact: High coupling. Fix: Move logic to a `DataManagementRepository`.
* **Rule 19.5 (Offline Behavior):** Violated in multiple Firestore calls missing `.timeout(Duration(seconds: 5))`. Impact: App hangs offline. Fix: Append `.timeout()` to all Firestore Futures.
* **Localization Rule:** `lib/core/widgets/native_ad_widget.dart` contains hardcoded string literals in the UI, missing localization.

## Recommended Refactor Plan
### Quick Wins (Days 1-3)
1. Fix all `ref.read()` inside `build()` methods to use `ref.watch()`.
2. Add `.timeout(Duration(seconds: 5))` to all missing Firestore queries.
3. Replace hardcoded strings in `native_ad_widget.dart` with localized `l10n` calls.
4. Replace raw `ScaffoldMessenger` error handling with `AppFeedback` utility.

### Medium Effort (Weeks 1-2)
1. Refactor `data_management_screen.dart` to remove Firestore/Auth imports and use a dedicated Repository/Provider.
2. Consolidate notification scheduling logic in `scheduled_notification_handler.dart` into a single reusable strategy.
3. Fix the empty catch block in `simple_csv_parser.dart` to throw an `AppException(shouldReport: true)`.

### Long-Term Architecture (Months 1-2)
1. Split `add_investment_screen.dart` (1500 lines) into smaller, logical sub-components (e.g., `InvestmentFormDetails`, `InvestmentFormCalculations`).
2. Modularize `analytics_service.dart` (1440 lines) by event domains.
3. Migrate API keys in `firebase_options.dart` to build-time environment variables.

---

### 1. Top 10 Highest-Value Fixes
1. Fix Clean Architecture violation in `data_management_screen.dart` (Remove direct Firestore/Auth access).
2. Fix `ref.read` inside `build` methods across the app (10 files).
3. Break down `add_investment_screen.dart` (1503 lines).
4. Break down `analytics_service.dart` (1440 lines).
5. Fix missing Firestore `.timeout()` implementations for offline resilience.
6. Fix empty catch block in `simple_csv_parser.dart`.
7. Move API keys in `firebase_options.dart` to environment variables.
8. Remove raw exceptions from UI (`ScaffoldMessenger` in catch blocks).
9. Resolve async operations inside the build method of `swipe_to_delete.dart`.
10. Remove hardcoded strings in `native_ad_widget.dart`.

### 2. Top 10 Duplication-Removal Opportunities
1. Notification scheduling logic blocks (repeated 6 times).
2. Export logic `_typeToExportString` (DataExportService & ExportService).
3. List Selection State (`toggleSelection` in Goals and Investments).
4. Portfolio Health Tier color logic.
5. Progress Ring layout code (Goals vs FIRE).
6. Empty State layouts (Goals, FIRE, Investments).
7. List State builders.
8. Repeated raw Exception catching & Snackbars.
9. Common Firestore query boilerplate.
10. Shared widget styles (Cards, paddings).

### 3. Top Reusable Abstractions Worth Introducing
1. `BaseNotificationStrategy` for handling different notification types.
2. `AppFeedback` / `SnackbarService` for unified error reporting.
3. `CircularProgressWidget` for shared ring UI.
4. `SelectionListNotifier` mixin for shared Riverpod list selection states.
5. `EnvironmentConfig` for securely injecting build-time variables.

### 4. Files/Components with Highest Technical Debt
1. `lib/features/investment/presentation/screens/add_investment_screen.dart` (God UI Class)
2. `lib/core/analytics/analytics_service.dart` (God Service Class)
3. `lib/features/settings/presentation/screens/data_management_screen.dart` (Architecture Violations)
4. `lib/core/notifications/notification_service.dart` (1000+ lines, high duplication)
5. `lib/features/investment/presentation/widgets/add_document_sheet.dart` (1000+ lines)

### 5. Suggested Engineering Standards Missing
1. **File Size Limits:** Introduce a linter rule (e.g., `analyzer_plugin` or custom CI script) to fail builds for files > 500 lines.
2. **Strict Architecture Lints:** Use `dart_code_metrics` or similar to strictly ban cross-layer imports (e.g., `import 'package:cloud_firestore/...` in `presentation/`).
3. **Environment Variable Enforcement:** Document strict standards for secrets management (no hardcoded keys in `firebase_options.dart`).
