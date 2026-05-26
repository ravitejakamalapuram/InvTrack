## Executive Summary
* **Overall Repo Health:** Good, but with localized areas of high technical debt (e.g. AddInvestmentScreen, InvestmentDetailScreen) and some architecture rule violations (ref.read in build, missing const constructors).
* **Biggest Risks:** Complex presentation logic in God classes (>1000 lines), scattered ScaffoldMessenger usage leading to inconsistent error handling, and hardcoded 'ref.read' in some build methods (Architecture Rule 3.2).
* **Highest ROI Improvements:** Refactoring 'AddInvestmentScreen' into smaller widgets, extracting common UI feedback into 'AppFeedback' utility, standardizing error boundaries.
* **Architecture Concerns:** Some UI components are too large, breaking the 'UI -> State -> Domain -> Data' boundary by embedding business logic and direct provider mutations.

## Critical Issues
1. **'ref.read' in build methods**: Found violations of Rule 3.2 (Never ref.read in build). For instance, in 'lib/features/investment/presentation/widgets/investment_list_filter_tabs.dart'.
2. **God Classes**: 'lib/features/investment/presentation/screens/add_investment_screen.dart' is 1502 lines long, far exceeding the 500-line limit (Rule 14). 'lib/core/analytics/analytics_service.dart' is 1439 lines.
3. **ScaffoldMessenger in catch blocks**: Found instances where 'ScaffoldMessenger' is used directly in catch blocks instead of the centralized 'ErrorHandler.handle()' (Rule 3.3.3).

## Duplication Report
* **SnackBars**: There are 57+ direct uses of 'ScaffoldMessenger.of(context).showSnackBar'. Many of these are duplicated feedback messages. This should be consolidated into 'AppFeedback.showSuccess()' or similar.
* **Privacy Protection Wrappers**: Repeatedly wrapping text widgets manually. A custom text widget (like 'CompactAmountText' which already handles it) should be enforced project-wide for all currency displays.

## Reusability Opportunities
* **Form Fields**: 'AddInvestmentScreen' contains many custom form fields that could be extracted into a shared 'lib/core/widgets/forms/' directory.
* **Error Handling**: Use a standard 'AsyncValueWidget' or similar wrapper for Riverpod's 'AsyncValue.when' to ensure loading, error, and data states are handled consistently.

## Architecture Review
* **Layering**: Mostly good, but large screens indicate UI is doing too much state management.
* **Scalability**: The 'AnalyticsService' and 'NotificationService' are growing too large and should be split into domain-specific modules (e.g., 'InvestmentAnalytics', 'GoalAnalytics').

## Performance Findings
* **Missing const**: 'flutter analyze' shows a few issues with 'Invalid constant value'. Enforce 'const' constructors aggressively.
* **Over-rebuilding**: Using 'ref.watch' on entire objects instead of 'ref.select' in complex lists might cause jank.

## Security & Reliability Findings
* **Error Swallowing**: Found 'catch' blocks using direct UI feedback without logging to Crashlytics.
* **Missing Privacy Wrapper**: Some custom investment cards might be missing 'PrivacyProtectionWrapper' if they roll their own text formatting.

## Testing Gaps
* 'flutter analyze' shows 415 issues, mostly related to 'AppLocalizations' not being generated before tests.
* Missing tests for some of the massive presentation screens (like 'AddInvestmentScreen').

## Rules Compliance Findings
* **Rule 3.2 (Ref usage)**: Violated in 'investment_list_filter_tabs.dart' and potentially others.
* **Rule 14 (God classes)**: 'add_investment_screen.dart' (1502 lines), 'analytics_service.dart' (1439 lines).
* **Rule 3.3.3 (Centralized error handling)**: Violated in 'document_viewer_screen.dart' and 'data_management_screen.dart'.

## Recommended Refactor Plan
### Quick Wins
1. Run 'flutter gen-l10n' and fix all analyzer issues.
2. Fix 'ref.read' inside build methods.
3. Replace raw 'ScaffoldMessenger' catch blocks with 'ErrorHandler.handle()'.
### Medium Effort
1. Refactor 'AddInvestmentScreen' into smaller composite widgets.
2. Standardize all snackbars through 'AppFeedback'.
### Long-Term
1. Break down 'AnalyticsService' into domain-specific tracking.
2. Implement an 'AsyncValueWidget' for consistent Riverpod state handling.

## Top 10 Highest-Value Fixes
1. Fix 'ref.read' in 'build()' methods (Rule 3.2).
2. Refactor 'AddInvestmentScreen' (< 500 lines).
3. Migrate raw 'ScaffoldMessenger' to 'ErrorHandler.handle()'.
4. Resolve 415 'flutter analyze' errors/warnings.
5. Fix async gap issues (use_build_context_synchronously) in 'about_screen.dart'.
6. Ensure all catch blocks log to Crashlytics.
7. Refactor 'AnalyticsService' to be modular.
8. Enforce 'const' constructors.
9. Ensure 'PrivacyProtectionWrapper' on all currency displays.
10. Extract form fields from 'AddInvestmentScreen' to reusable widgets.

## Top 10 Duplication-Removal Opportunities
1. ScaffoldMessenger.showSnackBar -> AppFeedback.show()
2. Manual error dialogs -> ErrorHandler.handle()
3. Form text fields in 'AddInvestmentScreen'.
4. Padding/Spacing boilerplate -> AppTheme.spacing
5. Custom currency formatting -> formatCompactCurrency
6. Privacy protection text wrapping.
7. Empty state UI -> Shared 'EmptyStateWidget'.
8. Loading indicators -> Shared 'LoadingOverlay'.
9. Common confirm dialogs.
10. Date formatting.

## Top Reusable Abstractions Worth Introducing
1. 'AsyncValueWidget' for Riverpod states.
2. 'FormTextField' base class.
3. 'AppFeedback' wrapper for SnackBars.

## Files with Highest Technical Debt
1. 'lib/features/investment/presentation/screens/add_investment_screen.dart' (1502 lines)
2. 'lib/core/analytics/analytics_service.dart' (1439 lines)
3. 'lib/core/notifications/notification_service.dart' (1080 lines)
4. 'lib/features/investment/presentation/widgets/add_document_sheet.dart' (1020 lines)

## Suggested Engineering Standards Missing
1. Hard limit on file length via custom lint rules.
2. Mandatory extraction of complex form fields to separate files.
3. Rule to strictly use 'AppFeedback' over raw 'ScaffoldMessenger'.
