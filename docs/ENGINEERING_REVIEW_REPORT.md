# Enterprise Engineering Review Report - InvTrack

## Executive Summary
* **Overall Repo Health Score**: 75/100
* **Biggest Risks**: High duplication of error handling patterns across screens (violating enterprise Rule 3.3.3), multiple UI screens directly handling `catch` blocks rather than using `ErrorHandler.handle()`, missing timeout constraints on some Firebase update operations, and massive "God Classes" exceeding 1,000 lines.
* **Highest ROI Improvements**: Extracting `ScaffoldMessenger.of(context).showSnackBar` into a centralized `AppFeedback` or `NotificationService` call, migrating direct error handling to `ErrorHandler.handle()`, breaking down `AddInvestmentScreen` (1,502 lines) into smaller components.
* **Architecture Concerns**: The repository structure generally adheres to the prescribed Clean Architecture (UI -> State -> Domain -> Data) using Riverpod and feature-first folders. However, there is UI-layer leakage of business logic in large screen widgets and direct Firebase/Auth handling in some UI blocks (e.g., in `data_management_screen.dart`).

## Critical Issues
1. **Error Handling & Rule 3.3.3 Violations**: There are 62 instances of raw `ScaffoldMessenger.of(context).showSnackBar` directly in UI code, frequently exposing raw exceptions or hardcoded strings to the user, directly violating Rule 3.3.3 which mandates `ErrorHandler.handle()`.
2. **Missing Firestore Timeouts**: Direct `.set()` and `.update()` calls exist across several data repositories (e.g., `version_check_service.dart`, `firestore_goal_repository.dart`, `firestore_investment_repository.dart`) without `.timeout(Duration(seconds: 5))` wrappers. This violates Rule 4.2 (Offline-First Pattern).
3. **God Classes & Oversized Files**:
   - `add_investment_screen.dart` (1,502 lines)
   - `analytics_service.dart` (1,199 lines)
   - `notification_service.dart` (1,080 lines)
   - `add_document_sheet.dart` (1,020 lines)
   These violate the strict <500 lines rule (Rule 14).
4. **Localization (Rule 16)**: Direct use of `Text('...')` instead of `AppLocalizations.of(context)!.key` was detected in PDF exporter and some UI areas (e.g., `report_pdf_exporter.dart`).
5. **Hardcoded Currency (Rule 16.5)**: 5 instances of `formatCompactIndian` persist, violating the mandate to use locale-aware `formatCompactCurrency()`.

## Duplication Report
1. **Snackbar Spam**: `ScaffoldMessenger.of(context).showSnackBar(...)` is duplicated 62 times across multiple screens (`about_screen.dart`, `data_management_screen.dart`, `document_viewer_screen.dart`).
   - *Fix*: Replace with `AppFeedback.showError(context, message)` or `ErrorHandler.handle()`.
2. **Try/Catch Blocks in UI**: Components like `data_management_screen.dart` and `about_screen.dart` directly catch `FirebaseAuthException` and `catch (e)` and handle errors themselves rather than delegating to `ErrorHandler`.
   - *Fix*: Create unified generic handlers inside `ErrorHandler`.
3. **Firestore Repository Boilerplate**: Repeated manual serialization logic (`.set(_investmentToFirestore(investment))`) and transaction batching logic.
   - *Fix*: Introduce a generic `BaseFirestoreRepository<T>` class with built-in timeouts and generic serialization.
4. **Provider Initializations**: Repeated `try/catch` and `AnalyticsService` / `CrashlyticsService` extraction in UI events (e.g., `sign_in_screen.dart`).
   - *Fix*: Move to a dedicated Controller/Notifier class instead of keeping it in `onPressed` callbacks of UI elements.

## Reusability Opportunities
1. **Base Error Handling Mixin**: Extract the error propagation logic in view models to a base `StateNotifier`/`AsyncNotifier`.
2. **Firestore Generic Repository**: Create a `FirestoreRepository<T>` that enforces timeouts and offline-first paradigms across all collections (Users, Goals, Investments).
3. **Generic CSV Parser**: `simple_csv_parser.dart` (815 lines) could be abstracted into strategy patterns to support various bank CSV formats without exploding the file size.
4. **Shared Bottom Sheets**: `add_document_sheet.dart` (1,020 lines) has too much internal logic. Split UI definition from state/file selection logic.
5. **AppFeedback Utility**: Centralize all Snackbars, Dialogs, and Toasts.

## Architecture Review
* **Scalability**: High. Feature-first structure makes it easy to add new modules. Riverpod provides good state isolation.
* **Maintainability**: Degraded by "God Classes". `add_investment_screen.dart` handles too many responsibilities (validation, form state, calculation, UI).
* **Layering**: Mostly good, but UI screens occasionally access repositories directly via `ref.read` (e.g., `sign_in_screen.dart` reading `authRepositoryProvider` directly). This should be mediated by a Presentation Controller.
* **Testability**: Logic trapped in UI callbacks (`onPressed`) makes unit testing hard.

## Performance Findings
1. **UI Renders**: Extremely large build methods in `add_investment_screen.dart` risk massive widget tree rebuilds. Ensure `ref.select` is used extensively and extract smaller widgets into separate files.
2. **Heavy File Loading**: `simple_csv_parser.dart` is synchronous or block-heavy. Ensure Web Workers/Isolates are used for parsing large CSV files.
3. **Firestore Caching**: Ensure `timeout` is applied consistently to prevent blocking UI on network timeouts.

## Security & Reliability Findings
1. **Raw Exception Exposure**: Showing raw exceptions (caught by raw `catch(e)`) in Snackbars leaks implementation details to users.
2. **Direct Authentication Flow**: `sign_in_screen.dart` handles Auth exceptions directly. Move this to the Domain layer to prevent UI tampering risks and improve reliability.

## Testing Gaps
1. **God Class Tests**: Testing `add_investment_screen.dart` (1,502 lines) is likely brittle due to its size and mixed concerns.
2. **Missing Timeouts**: Lack of timeouts on `set`/`update` means offline tests might not be covering edge cases where data gets stuck pending.

## Rules Compliance Findings
* **Rule 3.3.3 (Centralized Error Handling)**: Violated in 62 locations using `ScaffoldMessenger`.
* **Rule 4.2 (Offline-first pattern)**: Violated in multiple data repositories missing `.timeout(Duration(seconds: 5))`.
* **Rule 14 (God Classes)**: 10+ files exceed the 500 lines threshold.
* **Rule 16.1 (String Externalization)**: Some instances of raw strings in `report_pdf_exporter.dart`.
* **Rule 16.5 (Currency Localization)**: Remaining `formatCompactIndian` usages found.

## Recommended Refactor Plan

### Quick Wins (Sprint 1)
1. **Enforce Timeouts**: Audit and append `.timeout(Duration(seconds: 5))` to all `.set()` and `.update()` calls in Firestore repositories.
2. **Replace ScaffoldMessenger**: Migrate all direct `ScaffoldMessenger` calls to `ErrorHandler.handle()` or a shared `AppFeedback` class.
3. **Remove Hardcoded Strings/Currency**: Fix `report_pdf_exporter.dart` hardcoded strings and replace `formatCompactIndian`.

### Medium Effort (Sprint 2)
1. **Componentize God Screens**: Break down `add_investment_screen.dart` (1,500+ lines), `data_management_screen.dart` (839 lines), and `investment_detail_screen.dart` (937 lines) into smaller, single-responsibility widgets.
2. **Extract Form State**: Move form validation and state logic out of UI into Riverpod Notifiers.

### Long-Term Architecture (Sprint 3+)
1. **Introduce Base Firestore Repository**: Unify CRUD operations into a generic class that enforces Rules 4.2 and 5.3 automatically.
2. **Controller Pattern**: Ensure UI widgets never call repositories directly. Introduce Presentation Controllers (Notifiers) to bridge UI and Domain.

# Final Requirements

### Top 10 Highest-Value Fixes
1. Add 5-second timeouts to all Firestore writes.
2. Replace all `ScaffoldMessenger` calls with `ErrorHandler.handle()`.
3. Break down `add_investment_screen.dart` into smaller chunks.
4. Move `catch(e)` blocks from UI into Riverpod Notifiers.
5. Replace `formatCompactIndian` with `formatCompactCurrency`.
6. Extract UI logic from `data_management_screen.dart`.
7. Move direct repository calls in `sign_in_screen.dart` to an AuthController.
8. Componentize `add_document_sheet.dart`.
9. Ensure all `catch(e)` errors map to typed `AppException`s.
10. Remove raw string texts from `report_pdf_exporter.dart`.

### Top 10 Duplication-Removal Opportunities
1. Shared `AppFeedback` for Snackbars.
2. Shared generic `BaseFirestoreRepository<T>`.
3. Abstracted CSV processing strategies.
4. Shared `try/catch` wrapper inside Riverpod Notifiers for async actions.
5. Reusable Confirmation Dialog widget.
6. Reusable Bottom Sheet scaffolding.
7. Reusable Empty State widget configuration.
8. Shared date/time formatters avoiding inline `.toString().split(' ')`.
9. Common Loading Overlay.
10. Shared Google Sign In error handlers.

### Top Reusable Abstractions Worth Introducing
* `AppFeedbackService` or utility for safe UI feedback.
* `BaseFirestoreRepository<T>` enforcing timeouts and serialization.
* `AsyncActionNotifier` to unify `loading`/`error` states for button clicks.
* Form Field validation mixins.

### Files/Components with Highest Technical Debt
1. `add_investment_screen.dart` (Complexity, Size, Mixed logic)
2. `analytics_service.dart` (Size, Boilerplate)
3. `data_management_screen.dart` (Mixed presentation and direct repo access)
4. `notification_service.dart` (High complexity and length)

### Suggested Engineering Standards Missing
* **Strict Presentation Controller Pattern**: Explicitly ban `ref.read(repositoryProvider)` in UI widgets. Require `ref.read(controllerProvider.notifier)`.
* **Standardized Form Management**: Adopt a standard way to handle large forms (e.g., `flutter_form_builder` or custom Riverpod form states) to prevent 1500-line form files.
* **Maximum Widget Depth**: Add a linter rule restricting widget tree depth to encourage componentization.
