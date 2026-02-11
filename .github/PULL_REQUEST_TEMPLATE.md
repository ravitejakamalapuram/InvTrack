# Pull Request

## Description

<!-- Provide a brief description of the changes in this PR -->

## Type of Change

- [ ] Feature (new functionality)
- [ ] Bug fix (fixes an issue)
- [ ] Refactor (code improvement without changing functionality)
- [ ] Documentation update
- [ ] Performance improvement
- [ ] Test coverage improvement

## Impacted App Flows

<!-- List the app flows/screens affected by this change -->

- 

## Architecture Confirmation

- [ ] Changes follow clean architecture (UI → State → Domain → Data)
- [ ] No API calls in widgets
- [ ] No business logic in UI layer
- [ ] Proper layer boundaries maintained

## Localization Checklist

- [ ] No hardcoded user-facing strings (all in ARB files)
- [ ] All new strings added to `lib/l10n/app_en.arb`
- [ ] Dates formatted with `DateFormat` (locale-aware)
- [ ] Numbers formatted with `NumberFormat` (locale-aware)
- [ ] No string concatenation for sentences (use placeholders)

## Currency Localization Checklist

- [ ] All currency amounts use `formatCompactCurrency()` with locale parameter
- [ ] No direct calls to `formatCompactIndian()` (deprecated for multi-locale support)
- [ ] Presentation layer widgets watch `currencyLocaleProvider`
- [ ] Domain entities accept locale as method parameter (no provider access)
- [ ] Tested currency switching (USD → EUR → INR) for correct notation
- [ ] Compact notation changes correctly (K/M for Western, L/Cr for Indian)

## Privacy Features Checklist

- [ ] All financial data wrapped in `PrivacyProtectionWrapper`
- [ ] Charts/graphs respect privacy mode
- [ ] No exact amounts in analytics (use ranges)
- [ ] No sensitive data in logs

## Error Handling Checklist

- [ ] All `AsyncValue` states handled (`data`, `loading`, `error`)
- [ ] No `handleError()` in StreamProviders (let errors propagate to UI)
- [ ] All user-facing errors use `ErrorHandler.handle()`
- [ ] Error messages are user-friendly (no raw exceptions)
- [ ] Error states include retry buttons for transient failures

## Performance Checklist

- [ ] Use `ref.select` for specific fields (not watching entire providers)
- [ ] Use `const` constructors where possible
- [ ] Use `ListView.builder` for long lists
- [ ] No expensive operations in `build()` methods
- [ ] Controllers/subscriptions disposed properly
- [ ] Screen-specific providers use `.autoDispose`

## Testing Checklist

- [ ] Unit tests for business logic
- [ ] Widget tests for UI components (if applicable)
- [ ] Bug fixes include regression tests
- [ ] All tests passing (`flutter test`)
- [ ] No skipped/flaky tests

## Code Quality Checklist

- [ ] Zero `flutter analyze` errors/warnings
- [ ] Code formatted (`dart format .`)
- [ ] No debug print statements
- [ ] No commented-out code
- [ ] No TODOs without owner/date/issue reference

## Data Lifecycle Checklist (if new storage)

- [ ] Data included in `deleteUserData()` flow
- [ ] Export service updated (if applicable)
- [ ] Import service updated (if applicable)
- [ ] Firestore security rules added

## Accessibility Checklist

- [ ] All images have semantic labels
- [ ] Touch targets ≥44x44dp
- [ ] Color contrast ≥4.5:1
- [ ] Screen reader compatible

## Security Checklist

- [ ] No sensitive data in logs/analytics
- [ ] All user inputs validated
- [ ] No hardcoded credentials/API keys
- [ ] Firestore rules require authentication

## Screenshots/Videos

<!-- Add screenshots or videos demonstrating the changes -->

## Additional Notes

<!-- Any additional information that reviewers should know -->

## Reviewer Checklist

- [ ] Code follows InvTrack Enterprise Rules
- [ ] PR is based on latest `main` branch
- [ ] No merge conflicts
- [ ] All CI checks passing
- [ ] Localization requirements met
- [ ] Privacy features handled correctly
- [ ] Tests cover new functionality
- [ ] No breaking changes (or documented)

