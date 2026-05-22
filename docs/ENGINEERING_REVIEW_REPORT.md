# InvTrack Enterprise Engineering Review

## Executive Summary
* **Overall Repo Health Score:** 80/100
* **Biggest Risks:**
  * **UI God Classes:** Several screens (especially `add_investment_screen.dart` at 1500+ lines and `investment_detail_screen.dart` at 900+ lines) are oversized, mixing UI, form state, complex validation, and logic.
  * **Duplication:** Common form layouts, list tiles, and empty state handlers are repeated across screens. Date formatting, amount formatting, and error state handling could be centralized.
  * **Performance Anti-patterns:** Widespread use of `.where().toList()` when evaluating boolean conditions like `.isEmpty`.
* **Highest ROI Improvements:**
  * Adopt a declarative form builder to deduplicate form inputs and sections.
  * Replace O(N) array allocation checks (`.where().toList().isEmpty`) with O(1) checks (`!any()`).
  * Break down the major screens into smaller, composable, independently testable widgets.

## Critical Issues
1. `lib/features/investment/presentation/screens/add_investment_screen.dart` is a massive "God Class" (1,502 lines). This file violates standard separation of concerns and maintainability principles.
2. `lib/features/investment/presentation/screens/investment_detail_screen.dart` is another god class (937 lines). It handles routing, UI logic, document management, and transaction viewing simultaneously.

## Duplication Report
1. **Forms:** Creating investments and creating transactions have duplicate UI form inputs (TextFields, date pickers, dropdowns).
2. **List Items:** The codebase repeats similar metric tile and list layouts for displaying different types of data (Investments, CashFlows, Goals).
3. **Currency Conversion/Privacy:** Multi-currency logic, while governed by rules, is sometimes repeated in the view layer rather than centralized in a unified `CurrencyAmountDisplay` widget.

## Reusability Opportunities
1. **Forms:** Implement a reusable Form Builder abstraction (`InvTrackFormBuilder`) to standardize validation, error handling, and visual layout of form fields.
2. **UI Cards:** Extract generic list items that can display an icon, title, subtitle, and an action slot.
3. **Empty/Error States:** Standardize error layout boundaries with reusable Error State Widgets across all `AsyncValue` consumers.

## Architecture Review
1. **Feature Leakage:** Features occasionally reference each other directly instead of through domain events or shared core services.
2. **State Management:** Screens have heavy local state `ConsumerStatefulWidget` instead of delegating form validation/state management to Riverpod Notifiers, creating bloated UI layers.
3. **Rule 21 (Multi-Currency):** Strict compliance is required to ensure base currency references do not leak into source entity definitions.

## Performance Findings
1. Found numerous instances of the `where(...).toList()` anti-pattern in `lib/` (e.g. `BatchCurrencyConverter`, `GoalProgressProvider`, `InvestmentStatsProvider`, etc.). These create unnecessary heap allocations.

## Security & Reliability Findings
1. **Timeouts:** Per rule 19.5, ensure all Firestore write operations have a 5-second timeout `.timeout(Duration(seconds: 5))`.
2. **Privacy:** The financial wrapper `PrivacyProtectionWrapper` is documented as mandatory, ensure it wraps every newly introduced component that handles real user amounts.

## Testing Gaps
1. **UI Tests:** The large god classes make granular widget testing impossible. Breaking these apart is a prerequisite for adding effective widget test coverage.
2. **Multi-Currency Tests:** Ensure edge case testing exists for changing currencies where the user's base currency updates dynamically.

## Rules Compliance Findings
1. File lengths violate implicit standards for maintainable UI components (typically < 300 lines).
2. Performance checks must be addressed to comply with rule 19.6 ("All screens MUST load within 2 seconds") by avoiding large, unmemoized build functions.

## Recommended Refactor Plan
### Quick Wins
1. Clean up `.where().toList()` allocations across `lib/` and replace them with `for` loops or `.any()` / `.every()` logic.
2. Ensure Firestore writes use proper timeouts.

### Medium Effort Improvements
1. Break `add_investment_screen.dart` and `investment_detail_screen.dart` into smaller widgets (`InvestmentFormHeader`, `TransactionListSection`, etc.).
2. Extract reusable form components (amount input, date picker, dropdown).

### Long-term Architecture Improvements
1. Adopt a more robust form state management system leveraging Riverpod to remove state from UI build methods.
2. Enforce strict max line counts via linting.

## Top 10 Priority Execution Items
1. Replace `.where().toList()` anti-patterns.
2. Decompose `add_investment_screen.dart` into sub-widgets.
3. Decompose `investment_detail_screen.dart` into sub-widgets.
4. Extract `CurrencyAmountText` widget.
5. Create a shared `FormInputComponent` library.
6. Enforce Firestore write timeouts.
7. Centralize Riverpod `AsyncValue` error handling UI.
8. Unify `EmptyStateWidget` usage.
9. Centralize List Item UI for standard entries.
10. Move form validation rules to the domain layer.

## Top 10 Duplication-Removal Opportunities
1. Consolidate Form Input widgets (Text, Date, Amount, Dropdown) across Add screens.
2. Unify Empty State implementations.
3. Consolidate currency conversion + display logic into a single `CurrencyAmountText` widget.
4. Unify List Item UI for Investments, Goals, and History.
5. Extract common validation rules (required, min value, max length) into a validator utility.
6. Combine repeated Firestore query setups into base repository methods.
7. Unify Error State / Retry UI components.
8. Standardize Loading Skeletons for lists.
9. Extract common date formatting logic used in lists and details.
10. Consolidate repetitive Riverpod `ref.listen` logic for error handling into a custom hook/mixin.

## Top Reusable Abstractions Worth Introducing
1. `InvTrackFormBuilder`: A declarative way to build forms.
2. `CurrencyDisplayWidget`: Automatically handles base currency conversion and formatting.
3. `PaginatedFirestoreListView`: A reusable list component for standardizing infinite scrolling.
4. `BaseRepository`: Abstract common Firestore CRUD operations.

## Files/Components with Highest Technical Debt
1. `lib/features/investment/presentation/screens/add_investment_screen.dart` (1502 lines)
2. `lib/features/investment/presentation/screens/investment_detail_screen.dart` (937 lines)
3. `lib/features/investment/presentation/screens/investment_list_screen.dart` (673 lines)
4. `lib/features/portfolio_health/presentation/screens/portfolio_health_details_screen.dart` (537 lines)

## Suggested Engineering Standards Missing From the Repository
1. Maximum File Length rule (e.g., 300 lines max for UI files).
2. Requirement for UI components to have companion widget tests.
3. Strict ban on business logic inside `build()` methods.
4. Declarative UI Component library mandate (no raw Text/Containers for common elements).
