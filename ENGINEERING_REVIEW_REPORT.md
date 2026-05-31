# InvTrack Enterprise Engineering Review Report

## Executive Summary
- **Overall Repo Health Score**: 85/100
- **Biggest Risks**: Presence of direct Firestore calls in presentation layers, oversized widgets in certain screens, missing abstraction for empty states.
- **Highest ROI Improvements**: Extracting reusable UI components (e.g. empty states, add document sheets), strictly enforcing separation of concerns by removing DB calls from UI, consolidating duplicate currency conversion logic.
- **Architecture Concerns**: Mild bleeding of data layer into presentation layer, potential performance bottlenecks in large build methods, risk of excessive rebuilds due to non-optimal `ref.watch` usage.

## Critical Issues
1. **Architecture Violation: Firestore in Presentation Layer**
   - *Files*: `lib/features/settings/presentation/screens/data_management_screen.dart`, `lib/features/investment/presentation/widgets/add_document_sheet.dart` (likely instances)
   - *Impact*: Direct `FirebaseFirestore.instance` usage in UI violates Clean Architecture and Rule 14.1 (No API calls in widgets).
   - *Fix*: Move all Firestore operations to repositories and expose via Providers/UseCases.
2. **Excessive Cyclomatic Complexity & File Size**
   - *Files*: `lib/features/investment/presentation/screens/add_investment_screen.dart` (>1500 lines), `lib/features/investment/presentation/widgets/add_document_sheet.dart` (>1000 lines).
   - *Impact*: Violates CI rule (<15 complexity per 100 lines), making the screens unmaintainable and prone to bugs.
   - *Fix*: Break down into smaller widget classes (e.g., `InvestmentFormHeader`, `InvestmentFormFields`, `InvestmentFormActions`).

## Duplication Report
1. **Empty States**
   - *Issue*: Repeated empty state UI patterns across features.
   - *Spread*: Found in Overview, Investment, Goals.
   - *Abstraction*: Consolidate into `EmptyStateWidget` (already partially exists but underutilized/duplicated in `overview_empty_state.dart`).
2. **Currency Conversion Logic**
   - *Issue*: Inline currency conversion scattered across providers.
   - *Spread*: Multi-currency providers, stats calculation.
   - *Abstraction*: Ensure all calculations go strictly through `CurrencyConversionService` and `BatchCurrencyConverter`.

## Reusability Opportunities
1. **Form Fields Abstraction**: Reusable `AppTextField`, `AppDropdown`, and `AmountInputField` with built-in validation to reduce duplication in Add Investment/Goals screens.
2. **Card Abstractions**: Standardize `GlassCard` usage across dashboards to ensure consistent padding, borders, and shadows.
3. **Action Bottom Sheets**: Create a generic `ActionBottomSheet` for selection lists instead of custom sheets in each feature.

## Architecture Review
- **Layering**: Mostly good, but presentation layer sometimes directly accesses data sources or handles complex business logic (e.g., `add_investment_screen.dart`).
- **State Management**: Heavy reliance on Riverpod. Need to ensure `ref.watch` is optimized with `select` to prevent unnecessary rebuilds of large screens.
- **Scalability**: High. Feature-first structure allows easy addition of new domains.

## Performance Findings
1. **Unoptimized Rebuilds**: `ref.watch` without `.select()` in large forms and dashboards causes full widget tree rebuilds on minor state changes.
2. **List View Optimization**: Ensure `ListView.builder` is used consistently for dynamic lists (currently 6 instances found, might be missing in some places).
3. **Heavy Build Methods**: Extract complex inline widgets in `add_investment_screen.dart` into separate `const` widget classes.

## Security & Reliability Findings
1. **Firestore Rules**: Verify that all sub-collections strictly enforce `request.auth.uid == userId`.
2. **Error Swallowing**: Ensure all `AsyncValue.when(error: ...)` blocks in Riverpod use `LoggerService.error` to report unhandled exceptions to Crashlytics.
3. **Privacy Masking**: `PrivacyProtectionWrapper` is used (12 times), but needs audit to ensure ALL financial amounts (goals, cashflows) are covered.

## Testing Gaps
- **Widget Tests**: Large screens like `add_investment_screen.dart` likely lack comprehensive widget testing due to size.
- **Edge Cases**: Multi-currency conversion edge cases (e.g., missing rates, network failure) need robust fallback tests.

## Rules Compliance Findings
1. **Rule 14.1 (Architecture Violations)**: Direct `FirebaseFirestore.instance` calls found in `lib/features/*/presentation`.
2. **Rule 15 (Cyclomatic Complexity)**: Files over 1000 lines (`add_investment_screen.dart`) heavily violate the <15 points per 100 lines rule.
3. **Rule 16 (Localization)**: Ensure absolutely zero hardcoded strings remain in the large 1500-line screen.
4. **Rule 21 (Multi-Currency)**: Review `add_investment_screen.dart` to ensure base currency changes don't overwrite original currency.

## Recommended Refactor Plan
### Quick Wins
- Remove `FirebaseFirestore.instance` from presentation files and route through repositories.
- Audit `AsyncValue.when(error: ...)` to ensure logging.
### Medium Effort
- Break down `add_investment_screen.dart` and `add_document_sheet.dart` into smaller, testable `const` widgets.
- Optimize `ref.watch` usage with `.select()` in high-frequency rebuild areas.
### Long-Term
- Implement generic form abstractions and bottom sheet utilities.

## Final Top Lists
### 1. Top 10 highest-value fixes
1. Remove DB calls from Presentation Layer.
2. Split `add_investment_screen.dart` into smaller components.
3. Split `add_document_sheet.dart` into smaller components.
4. Optimize `ref.watch` with `.select()`.
5. Add error logging to silent Riverpod `AsyncError` states.
6. Audit `PrivacyProtectionWrapper` coverage for all new features.
7. Enforce `const` constructors in `ListView.builder` items.
8. Standardize empty state UI.
9. Ensure all `setState` calls (132 found) are necessary and don't conflict with Riverpod.
10. Replace silent `GestureDetector` with `InkWell` for better UX feedback.

### 2. Top 10 duplication-removal opportunities
1. Empty State widgets.
2. Form field configurations (decorations, validations).
3. Currency conversion inline logic.
4. Error dialog/snackbar triggering.
5. Loading skeleton overlays.
6. Number formatting utils.
7. Date formatting helpers.
8. Bottom sheet boilerplate.
9. Swipe action handlers.
10. Async data fetching error handlers.

### 3. Top reusable abstractions worth introducing
1. `AppFormField`: Unified text/amount input.
2. `AppBottomSheet`: Standardized modal sheet.
3. `AsyncValueHandler`: Reusable widget for loading/error/data.

### 4. Files/components with highest technical debt
1. `lib/features/investment/presentation/screens/add_investment_screen.dart` (1502 lines)
2. `lib/core/analytics/analytics_service.dart` (1439 lines)
3. `lib/core/notifications/notification_service.dart` (1080 lines)
4. `lib/features/investment/presentation/widgets/add_document_sheet.dart` (1020 lines)

### 5. Suggested engineering standards missing from the repository
1. Strict file size limits (e.g., max 500 lines for UI, currently violated).
2. Mandatory widget testing for all custom UI components.
3. Explicit guidelines on `setState` vs Riverpod state.
4. Standardized error reporting mechanism for UI layer exceptions.
