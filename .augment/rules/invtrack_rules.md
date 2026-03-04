---
type: "always_apply"
---

# InvTrack Enterprise Rules

**All code must comply with these rules. Violations block PRs.**

---

## 1. ARCHITECTURE

### 1.1 Layer Boundaries
- **UI → State → Domain → Data** (strict)
- ❌ No API calls in widgets
- ❌ No business logic in UI
- ❌ No navigation in domain layer

### 1.2 File Structure
- Providers: `lib/features/{feature}/presentation/providers/`
- Screens: `lib/features/{feature}/presentation/screens/`
- Widgets: `lib/features/{feature}/presentation/widgets/`

### 1.3 Complexity Guidelines
- Keep functions focused and single-purpose
- Cyclomatic complexity: <15 decision points per 100 lines (enforced by CI)
- Complex logic should be extracted to separate functions/classes
- High complexity indicates need for refactoring

---

## 2. CODE QUALITY

### 2.1 Static Analysis
- Zero errors/warnings from `flutter analyze`
- No `// ignore:` without documented justification
- Run `dart fix --apply` before commit

### 2.2 Cyclomatic Complexity
- Measures decision points (if/else, loops, switch, &&, ||, ??)
- Target: <15 decision points per 100 lines
- High complexity indicates need for refactoring
- Extract complex logic into smaller, testable functions

### 2.3 Code Coverage
- Target: ≥80% coverage for new code
- Minimum: ≥60% coverage
- All business logic must be tested
- Bug fixes must include regression tests

### 2.5 Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables: `camelCase`
- Providers: `camelCaseProvider`

### 2.6 Strong Typing
- Use enums for states/actions (no magic strings)
- No boolean explosion patterns
- Explicit return types on all functions

### 2.7 Documentation
- Document public APIs and complex logic
- TODOs must include: owner, date, issue reference

---

## 3. RIVERPOD STATE MANAGEMENT

### 3.1 Provider Selection
| Use Case | Type |
|----------|------|
| Sync value | `Provider` |
| Async fetch | `FutureProvider` |
| Real-time | `StreamProvider` |
| Parameterized | `.family` |
| Screen-specific | `.autoDispose` |

### 3.2 Ref Usage
```dart
// ✅ Build: ref.watch (reactive)
// ✅ Callbacks: ref.read (one-time)
// ✅ Side effects: ref.listen
// ❌ Never ref.read in build
```

### 3.3 Error Handling

**All async operations MUST have proper error handling with user-friendly feedback.**

#### 3.3.1 AsyncValue States
Always handle all `AsyncValue` states: `data`, `loading`, `error`

```dart
// ✅ GOOD: Handle all states
asyncValue.when(
  data: (data) => DataWidget(data),
  loading: () => LoadingIndicator(),
  error: (error, stack) => ErrorWidget(error),
);

// ❌ BAD: Only handling data
final data = asyncValue.value;
```

#### 3.3.2 StreamProvider Error Handling
**Never use `handleError()` to swallow errors** - let them propagate to UI

```dart
// ✅ GOOD: Errors propagate to UI
final dataProvider = StreamProvider<List<Data>>((ref) {
  return repository.watchData();
});

// ❌ BAD: Errors swallowed with only debug logging
final dataProvider = StreamProvider<List<Data>>((ref) {
  return repository.watchData().handleError((e, st) {
    debugPrint('Error: $e'); // User never sees this!
  });
});
```

#### 3.3.3 User-Facing Operations
All user-facing operations MUST use centralized error handling:

```dart
// ✅ GOOD: Use ErrorHandler for proper error mapping
try {
  await operation();
} catch (e, st) {
  if (!mounted) return;
  ErrorHandler.handle(e, st, context: context, showFeedback: true);
}

// ❌ BAD: Raw exception shown to user
try {
  await operation();
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Error: $e')), // Shows raw exception!
  );
}
```

#### 3.3.4 Error Types and User Messages
Use appropriate `AppException` types with user-friendly messages:

| Error Type | When to Use | User Message Example |
|------------|-------------|---------------------|
| `NetworkException.noConnection()` | No internet | "No internet connection" |
| `NetworkException.timeout()` | Request timeout | "Request timed out" |
| `AuthException.signInCancelled()` | User cancelled | "Sign in was cancelled" |
| `AuthException.signInFailed()` | Auth failed | "Sign in failed" |
| `DataException.saveFailed()` | Save failed | "Failed to save data" |
| `ValidationException` | User input error | "Invalid amount" |

#### 3.3.5 Error State UI Requirements
All error states MUST include:
- ✅ User-friendly error message (no raw exceptions)
- ✅ Error icon (e.g., `Icons.cloud_off_rounded` for network errors)
- ✅ Retry button for transient failures
- ✅ Proper error logging (Crashlytics for non-validation errors)

```dart
// ✅ GOOD: Complete error state
Widget _buildErrorState() {
  return Center(
    child: Column(
      children: [
        Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.errorLight),
        Text('Connection Error', style: AppTypography.h3),
        Text('Failed to load data. Please try again.'),
        TextButton(
          onPressed: () => ref.invalidate(dataProvider),
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}
```

#### 3.3.6 Offline Operations
Offline operations with timeout MUST inform users:
- ✅ Show success feedback immediately (optimistic UI)
- ✅ Data syncs automatically when online (Firestore offline-first)
- ❌ Don't show "pending sync" warnings (confuses users)

#### 3.3.7 Error Handling Checklist
Before submitting PR, verify:
- [ ] All `AsyncValue` states handled (`data`, `loading`, `error`)
- [ ] No `handleError()` in StreamProviders (let errors propagate)
- [ ] All user-facing errors use `ErrorHandler.handle()`
- [ ] Error messages are user-friendly (no raw exceptions)
- [ ] Error states include retry buttons for transient failures
- [ ] Network errors show "No internet" message
- [ ] Auth errors differentiate between cancelled vs failed
- [ ] Validation errors don't report to Crashlytics

---

## 4. FIREBASE & DATA

### 4.1 Collection Structure
```
users/{userId}/collectionName/{documentId}
```
❌ Never root-level user data

### 4.2 Offline-First Pattern
```dart
await writeOp().timeout(Duration(seconds: 5));
// Timeout = cached locally, syncs when online
```

### 4.3 New Collection Checklist
- [ ] Add to `firestore.rules`
- [ ] Add to `deleteUserData()` flow
- [ ] Add to export/import services
- [ ] Create repository pattern (interface → implementation → provider)

---

## 5. SECURITY (OWASP MASVS)

### 5.1 Data Protection
- ❌ Never log: passwords, tokens, PII, financial data
- Use `FlutterSecureStorage` for sensitive data
- Use ranges for analytics (not exact amounts)

### 5.2 Input Validation
- Validate ALL user inputs (length, type, range)
- Sanitize before Firestore writes

### 5.3 Authentication
- Verify auth state before data operations
- All Firestore rules require `request.auth.uid == userId`

### 5.4 Network
- HTTPS only, validate certificates
- Handle errors without exposing internals

---

## 6. PERFORMANCE

### 6.1 Widget Optimization
```dart
// ✅ Use ref.select for specific fields
final name = ref.watch(provider.select((s) => s.name));
// ✅ Use const constructors
const SizedBox(height: 16)
// ✅ Use ListView.builder for lists
// ❌ No async/await in build methods
```

### 6.2 Resource Management
- Dispose controllers in `dispose()`
- Cancel subscriptions/timers
- Use `.autoDispose` for screen-specific providers

---

## 7. LOCALIZATION & ACCESSIBILITY

### 7.1 Localization
- All strings in ARB files
- No hardcoded dates/numbers/currency
- Use locale-aware formatters

### 7.2 Accessibility (WCAG)
- All images: semantic labels
- Touch targets: min 44x44dp
- Color contrast: 4.5:1 minimum
- Screen reader compatible (`Semantics` widgets)

---

## 8. TESTING

### 8.1 Requirements
- Unit tests for business logic
- Widget tests for UI components
- Bug fixes MUST include regression tests
- No skipped/flaky tests

### 8.2 Mocking
- Mock only side-effects (API, DB, timers)
- Never mock pure functions

---

## 9. ANALYTICS & MONITORING

### 9.1 Event Naming
- Pattern: `{noun}_{action}` in snake_case
- Example: `investment_created`, `goal_completed`

### 9.2 Privacy
Never track: email, phone, names, account numbers, exact amounts
Use ranges: `under_1k`, `1k_10k`, `10k_100k`, `over_100k`

### 9.3 Error Tracking
```dart
CrashlyticsService().recordError(error, stack, reason: 'context');
```

---

## 10. PR REQUIREMENTS

### 10.1 Description Must Include
- What problem it solves
- Type: feature/bugfix/refactor
- Architecture confirmation
- Impacted app flows

### 10.2 Merge Criteria
- [ ] Zero analyzer issues
- [ ] All tests passing
- [ ] Localization applied
- [ ] Accessibility verified
- [ ] Data lifecycle handled (if new storage)
- [ ] Help & FAQ screen updated (if major feature/change)

### 10.3 Help & FAQ Update Requirements
**For major features, breaking changes, or new user-facing functionality:**

Update `lib/features/settings/presentation/screens/help_faq_screen.dart` with:
- [ ] New FAQ entry explaining the feature
- [ ] Common use cases and examples
- [ ] Troubleshooting tips (if applicable)
- [ ] Links to related features (if applicable)

**Examples of changes requiring Help & FAQ updates:**
- ✅ New investment types or categories
- ✅ New FIRE calculation methods
- ✅ Changes to data export/import behavior
- ✅ New privacy or security features
- ✅ Changes to currency handling or localization
- ❌ Minor UI tweaks or bug fixes (unless they change user workflow)

---

## 11. DEPENDENCIES

### 11.1 Before Adding Package
- pub.dev score ≥100
- Updated within 6 months
- Null-safety support
- Compatible license (MIT/BSD/Apache)

### 11.2 Preference Order
1. Flutter SDK built-in
2. Official Google/Firebase packages
3. Verified publishers
4. Community (last resort)

### 11.3 Version Constraints
- Use caret: `^1.2.3`
- Never `any` or open ranges
- Commit `pubspec.lock`

---

## 12. DATA LIFECYCLE (New Features)

### 12.1 Before Implementation
Answer these for any new data storage:
1. Delete account: Will this data be purged?
2. Export: Include in ZIP backup?
3. Import: Handle in restore?
4. Re-signup: Old data won't resurface?

### 12.2 Required Updates
- [ ] `deleteUserData()` includes new data
- [ ] Export service updated (if applicable)
- [ ] Import service updated (if applicable)
- [ ] Firestore security rules added

❌ New storage without lifecycle plan → REJECTED

---

## 13. MULTI-PERSPECTIVE REVIEW

For features, review from 4 perspectives:

### 13.1 Architect
- Data model normalized?
- Scalability considered?
- Properly decoupled?

### 13.2 Product Manager
- Solves user problem?
- Edge cases handled?
- Analytics implemented?

### 13.3 Senior Flutter Dev
- Widget rebuilds optimized?
- Memory leaks avoided?
- Code testable?

### 13.4 Compliance
- GDPR: data rights supported?
- Accessibility: WCAG compliant?
- Security: OWASP MASVS checked?

---

## 14. ANTI-PATTERNS TO REJECT

### Security ❌
- Hardcoded credentials/API keys
- Sensitive data in logs/analytics
- Disabled SSL verification
- Passwords in SharedPreferences

### Architecture ❌
- API calls in widgets
- Business logic in UI
- God classes (>500 lines)
- ref.read in build methods

### Performance ❌
- Column with 100+ children (use ListView.builder)
- Missing const constructors
- Watching entire provider for one field
- Undisposed controllers

### Accessibility ❌
- Images without semantic labels
- Touch targets <44dp
- Color-only information
- Missing focus management

---

## 15. CI AUTOMATION CHECKS

The enterprise review workflow verifies:
- [ ] **Static Analysis**: Zero errors/warnings from `flutter analyze`
- [ ] **All Tests Pass**: 100% test success rate
- [ ] **Cyclomatic Complexity**: <15 decision points per 100 lines (warning), <20 (critical)
- [ ] **Code Coverage**: ≥60% overall coverage
- [ ] **Architecture Violations**: No API calls in widgets, no navigation in domain
- [ ] **Bug Fixes Include Tests**: Regression tests for all bug fixes
- [ ] **Security**: No hardcoded secrets, no print statements in production
- [ ] **Accessibility**: Semantic labels on images and interactive elements
- [ ] **Localization**: All strings in ARB files
- [ ] **Privacy**: Financial data wrapped in PrivacyProtectionWrapper
- [ ] **No Stale Code**: PR based on latest main branch

---

## 16. LOCALIZATION REQUIREMENTS

### 16.1 String Externalization
**All user-facing strings MUST be in ARB files** (`.arb` in `lib/l10n/`)

❌ **REJECT:**
```dart
Text('Add Investment')  // Hardcoded string
```

✅ **ACCEPT:**
```dart
Text(AppLocalizations.of(context)!.addInvestment)
```

### 16.2 Localization Checklist
Before submitting PR, verify:
- [ ] No hardcoded user-facing strings in UI code
- [ ] All new strings added to `app_en.arb`
- [ ] All ARB keys are unique (no duplicate keys)
- [ ] ARB entries include `@keyName` metadata with description
- [ ] Placeholders use proper syntax: `{variableName}`
- [ ] Placeholder types defined in ARB metadata
- [ ] Dates formatted with `DateFormat` (locale-aware)
- [ ] Numbers formatted with `NumberFormat` (locale-aware)
- [ ] Currency formatted with `NumberFormat.currency()`
- [ ] No string concatenation for sentences (use placeholders)
- [ ] Run `flutter gen-l10n` to regenerate localization files
- [ ] Run `flutter analyze` to verify no errors after localization changes
- [ ] Import statement added: `import 'package:inv_tracker/l10n/generated/app_localizations.dart';`
- [ ] `final l10n = AppLocalizations.of(context);` declared in build methods
- [ ] For dialogs/bottom sheets: `l10n` captured in builder context (not in callbacks)

### 16.3 Common Violations
❌ **Hardcoded strings:**
```dart
'Total: $amount'  // Wrong
AppBar(title: Text('Settings'))  // Wrong
```

❌ **String concatenation:**
```dart
'You have ' + count.toString() + ' investments'  // Wrong
```

❌ **Non-locale-aware formatting:**
```dart
Text('${DateTime.now()}')  // Wrong
Text('${amount.toStringAsFixed(2)}')  // Wrong
```

✅ **Correct approach:**
```dart
Text(l10n.totalAmount(amount))  // ARB: "totalAmount": "Total: {amount}"
Text(DateFormat.yMMMd(locale).format(date))
Text(NumberFormat.currency(locale: locale, symbol: '₹').format(amount))
```

### 16.4 ARB File Structure
```json
{
  "@@locale": "en",
  "addInvestment": "Add Investment",
  "@addInvestment": {
    "description": "Button text to add a new investment"
  },
  "totalAmount": "Total: {amount}",
  "@totalAmount": {
    "description": "Shows total amount",
    "placeholders": {
      "amount": {
        "type": "String"
      }
    }
  }
}
```

### 16.5 Currency Localization
**All currency amounts MUST respect locale settings**

InvTrack supports 35+ currencies with locale-aware formatting:
- **Indian locale (en_IN)**: Shows 1L, 10L, 1Cr (lakhs/crores)
- **Western locales (en_US, en_GB, de_DE)**: Shows 100K, 1M, 10M (thousands/millions)

#### 16.5.1 Required Utilities
Always use `formatCompactCurrency()` from `lib/core/utils/currency_utils.dart`:

❌ **REJECT:**
```dart
// Hardcoded Indian notation
formatCompactIndian(amount, symbol: '₹')

// No locale parameter
Text('₹${amount.toStringAsFixed(2)}')
```

✅ **ACCEPT:**
```dart
// Locale-aware formatting
final locale = ref.watch(currencyLocaleProvider);
final symbol = ref.watch(currencySymbolProvider);
formatCompactCurrency(amount, symbol: symbol, locale: locale)
```

#### 16.5.2 Currency Localization Checklist
Before submitting PR, verify:
- [ ] All currency amounts use `formatCompactCurrency()` with locale parameter
- [ ] No direct calls to `formatCompactIndian()` (deprecated for multi-locale support)
- [ ] All presentation layer widgets watch `currencyLocaleProvider`
- [ ] Domain entities accept locale as method parameter (no provider access)
- [ ] Tested currency switching (USD → EUR → INR) to verify correct notation
- [ ] Compact notation changes correctly (K/M for Western, L/Cr for Indian)

#### 16.5.3 Common Violations
❌ **Hardcoded Indian notation:**
```dart
formatCompactIndian(amount)  // Always shows L/Cr
```

❌ **Missing locale parameter:**
```dart
formatCompactCurrency(amount, symbol: '₹')  // Defaults to en_US
```

❌ **Domain layer accessing providers:**
```dart
// In domain/entities/goal_progress.dart
final locale = ref.watch(currencyLocaleProvider);  // ❌ Domain can't access providers
```

✅ **Correct approach:**
```dart
// Presentation layer
final locale = ref.watch(currencyLocaleProvider);
final message = progress.getProgressMessage(currencySymbol, locale);

// Domain layer
String getProgressMessage(String symbol, String locale) {
  return formatCompactCurrency(amount, symbol: symbol, locale: locale);
}
```

---

## 17. PRIVACY FEATURE HANDLING

### 17.1 Privacy Mode Requirements
**All financial data displays MUST respect privacy mode**

Use `PrivacyProtectionWrapper` for:
- ✅ Investment amounts
- ✅ Returns/gains/losses
- ✅ Goal targets
- ✅ Portfolio values
- ✅ Transaction amounts
- ✅ Income/dividend amounts

### 17.2 Privacy Mode Checklist
Before submitting PR, verify:
- [ ] All amount displays wrapped in `PrivacyProtectionWrapper`
- [ ] All percentage displays wrapped (if showing gains/losses)
- [ ] Charts/graphs respect privacy mode
- [ ] Export/share features mask data in privacy mode
- [ ] Screenshots don't leak data in privacy mode
- [ ] Analytics don't send exact amounts (use ranges)

### 17.3 Implementation Pattern
❌ **REJECT:**
```dart
Text('₹${investment.currentValue}')  // No privacy protection
```

✅ **ACCEPT:**
```dart
PrivacyProtectionWrapper(
  child: Text('₹${NumberFormat.currency(locale: locale, symbol: '₹').format(investment.currentValue)}'),
)
```

### 17.4 Privacy-Sensitive Data
**NEVER log or track:**
- ❌ Exact investment amounts
- ❌ Exact returns/gains
- ❌ Account numbers
- ❌ User names/emails
- ❌ Phone numbers
- ❌ Addresses

**Use ranges for analytics:**
```dart
// ✅ GOOD
final amountRange = amount < 1000 ? 'under_1k'
  : amount < 10000 ? '1k_10k'
  : amount < 100000 ? '10k_100k'
  : 'over_100k';
AnalyticsService().logEvent('investment_created', {'amount_range': amountRange});

// ❌ BAD
AnalyticsService().logEvent('investment_created', {'amount': amount});
```

### 17.5 Privacy Mode Testing
**Required tests for privacy-sensitive features:**
```dart
testWidgets('respects privacy mode', (tester) async {
  // Test with privacy mode ON
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        privacyModeProvider.overrideWith((ref) => true),
      ],
      child: MyWidget(),
    ),
  );

  // Verify amounts are masked
  expect(find.text('₹1,234.56'), findsNothing);
  expect(find.text('••••••'), findsOneWidget);
});
```

---

## 18. STALE CODE PREVENTION

### 18.1 PR Freshness Requirements
**PRs MUST be based on latest `main` branch**

Before submitting PR:
- [ ] Rebase on latest `main`: `git rebase origin/main`
- [ ] Resolve any conflicts
- [ ] Re-run tests after rebase
- [ ] Verify no duplicate/conflicting changes

### 18.2 Auto-Merge Disabled
**Manual review required for all PRs**

Auto-merge is temporarily disabled to prevent:
- ❌ Stale code being merged
- ❌ Conflicting changes from multiple PRs
- ❌ Outdated dependencies
- ❌ Missed breaking changes

### 18.3 Review Checklist
Reviewer MUST verify:
- [ ] PR is based on latest `main`
- [ ] No merge conflicts
- [ ] All CI checks passing
- [ ] Code follows InvTrack Enterprise Rules
- [ ] Localization requirements met
- [ ] Privacy features handled correctly
- [ ] Tests cover new functionality
- [ ] No breaking changes (or documented)

### 18.4 Merge Process
1. **Developer:** Create PR, ensure all checks pass
2. **CI:** Run automated checks (tests, analysis, architecture)
3. **Reviewer:** Manual code review
4. **Developer:** Address feedback, rebase if needed
5. **Reviewer:** Approve PR
6. **Developer:** Manually merge using squash merge
7. **CI:** Delete branch after merge

---

## 19. ADDITIONAL REVIEW POINTS

### 19.1 User Input Validation
**All user inputs MUST be validated**

Required validations:
- [ ] Amount fields: positive numbers, max 15 digits
- [ ] Date fields: valid dates, not in far future
- [ ] Text fields: max length, no special chars (if applicable)
- [ ] Dropdown selections: valid enum values
- [ ] File uploads: size limits, allowed types

### 19.2 Error Messages
**All error messages MUST be user-friendly**

❌ **REJECT:**
```dart
'Exception: Null check operator used on a null value'
'FirebaseException: permission-denied'
```

✅ **ACCEPT:**
```dart
'Failed to save investment. Please try again.'
'No internet connection. Changes will sync when online.'
```

### 19.3 Loading States
**All async operations MUST show loading indicators**

Required for:
- [ ] Data fetching (Firestore queries)
- [ ] Form submissions
- [ ] File uploads
- [ ] Authentication operations
- [ ] Export/import operations

### 19.4 Empty States
**All lists MUST have empty state UI**

Required elements:
- [ ] Descriptive icon
- [ ] Helpful message
- [ ] Call-to-action button (if applicable)

Example:
```dart
if (investments.isEmpty) {
  return EmptyState(
    icon: Icons.account_balance_wallet_outlined,
    title: l10n.noInvestmentsTitle,
    message: l10n.noInvestmentsMessage,
    actionLabel: l10n.addFirstInvestment,
    onAction: () => context.push('/add-investment'),
  );
}
```

### 19.5 Offline Behavior
**All features MUST work offline (where applicable)**

Required:
- [ ] Firestore operations use offline persistence
- [ ] Write operations timeout after 5 seconds (cached locally)
- [ ] Read operations show cached data
- [ ] No "offline" warnings (confuses users)
- [ ] Sync happens automatically when online

### 19.6 Performance Considerations
**All screens MUST load within 2 seconds**

Optimization checklist:
- [ ] Use `ref.select` for specific fields
- [ ] Use `const` constructors where possible
- [ ] Use `ListView.builder` for long lists
- [ ] Avoid expensive operations in `build()`
- [ ] Dispose controllers/subscriptions
- [ ] Use `.autoDispose` for screen-specific providers

---

## 20. FINAL PR SUBMISSION CHECKLIST

Before marking PR as ready for review:

### Code Quality
- [ ] Zero `flutter analyze` errors/warnings
- [ ] All tests passing (`flutter test`)
- [ ] Code formatted (`dart format .`)
- [ ] No debug print statements
- [ ] No commented-out code
- [ ] No TODOs without owner/date/issue

### Functionality
- [ ] Feature works as expected
- [ ] Edge cases handled
- [ ] Error states tested
- [ ] Loading states implemented
- [ ] Empty states implemented
- [ ] Offline behavior verified

### Compliance
- [ ] Localization: All strings in ARB files
- [ ] Localization: All ARB keys unique (no duplicates)
- [ ] Localization: Run `flutter gen-l10n` and `flutter analyze` after changes
- [ ] Localization: Import statement and `l10n` variable declared properly
- [ ] Currency: All amounts use `formatCompactCurrency()` with locale parameter
- [ ] Currency: No direct calls to `formatCompactIndian()` (deprecated)
- [ ] Currency: Tested with different currencies (USD, EUR, INR) for correct notation
- [ ] **Multi-Currency: Feature complies with base currency change (see Rule 21)**
- [ ] Privacy: Financial data wrapped in `PrivacyProtectionWrapper`
- [ ] Security: No sensitive data in logs/analytics
- [ ] Accessibility: Semantic labels, touch targets ≥44dp
- [ ] Architecture: Clean layer boundaries
- [ ] Testing: Unit tests for business logic

### Documentation
- [ ] PR description explains what/why
- [ ] Breaking changes documented
- [ ] New dependencies justified
- [ ] Data lifecycle handled (if new storage)
- [ ] Help & FAQ screen updated (if major feature/change - see Rule 10.3)

### Review
- [ ] PR based on latest `main`
- [ ] No merge conflicts
- [ ] All CI checks passing
- [ ] Ready for manual review

---

## 21. MULTI-CURRENCY COMPLIANCE

### 21.1 Core Principle
**Original data is NEVER changed when base currency changes.**

All features that handle investment/cashflow data MUST comply with multi-currency architecture:
- Store original amounts and currencies
- Convert on-demand for display
- Preserve data integrity across currency changes

### 21.2 Data Storage Requirements

**✅ REQUIRED for all entities storing monetary amounts:**
```dart
class MyEntity {
  final double amount;      // Original amount
  final String currency;    // Original currency (e.g., 'USD', 'INR', 'EUR')
  // ❌ NO pre-converted amounts
  // ❌ NO base-currency-only fields
}
```

**Examples:**
- ✅ `InvestmentEntity` has `currency` field
- ✅ `CashFlowEntity` has `currency` field
- ⚠️ `GoalEntity` should have `currency` field (pending)
- ⚠️ `FireSettingsEntity` amounts are in base currency (user preference)

### 21.3 Display/Calculation Requirements

**All monetary displays MUST:**
1. Convert to user's base currency using `CurrencyConversionService`
2. Show exchange rate when currency differs (transparency)
3. Use `formatCompactCurrency()` with locale parameter

```dart
// ✅ GOOD: Convert for display
final baseCurrency = ref.watch(currencyCodeProvider);
final convertedAmount = await conversionService.convert(
  amount: cashFlow.amount,
  from: cashFlow.currency,
  to: baseCurrency,
  date: cashFlow.date,
);

// ❌ BAD: Assume base currency
final displayAmount = cashFlow.amount; // Wrong if currencies differ
```

### 21.4 Import/Export Requirements

**CSV/ZIP exports MUST include currency information:**

**✅ REQUIRED CSV columns:**
```csv
Date, Investment Name, Type, Amount, Currency, Notes
2024-01-01, US Stocks, INVEST, 1000, USD, Initial
2024-01-01, Indian FD, INVEST, 50000, INR, Fixed deposit
```

**❌ REJECT exports without currency:**
```csv
Date, Investment Name, Type, Amount, Notes
2024-01-01, US Stocks, INVEST, 1000, Initial  # Lost currency info!
```

**Import parsers MUST:**
- Read currency column if present
- Default to base currency if missing (backward compatibility)
- Validate currency codes (ISO 4217)

### 21.5 Sample Data Requirements

**Sample data MUST showcase multi-currency:**
- Include investments in at least 2-3 different currencies
- Demonstrate currency conversion in UI
- Show exchange rate transparency

```dart
// ✅ GOOD: Multi-currency sample data
createInvestment(name: 'US Stocks', currency: 'USD', ...);
createInvestment(name: 'Indian FD', currency: 'INR', ...);
createInvestment(name: 'European Bonds', currency: 'EUR', ...);

// ❌ BAD: All same currency
createInvestment(name: 'Investment 1', currency: 'USD', ...);
createInvestment(name: 'Investment 2', currency: 'USD', ...);
```

### 21.6 Data Lifecycle Requirements

**Delete user data MUST clean up:**
- [ ] All investments (includes currency field)
- [ ] All cashflows (includes currency field)
- [ ] All goals (includes currency field if added)
- [ ] **Exchange rate cache** (`users/{userId}/exchangeRates` collection)
- [ ] FIRE settings
- [ ] Sample data preferences

**Exchange rate cache cleanup:**
```dart
// ✅ REQUIRED in deleteAllUserData()
final exchangeRatesRef = FirebaseFirestore.instance
    .collection('users')
    .doc(userId)
    .collection('exchangeRates');

final snapshot = await exchangeRatesRef.get();
final batch = FirebaseFirestore.instance.batch();
for (final doc in snapshot.docs) {
  batch.delete(doc.reference);
}
await batch.commit();
```

### 21.7 Feature Compliance Checklist

**Before implementing ANY feature that handles monetary amounts, verify:**

- [ ] **Data Model:** Entity has `currency` field for all amounts
- [ ] **Storage:** Original currency stored in Firestore/database
- [ ] **Display:** Amounts converted to base currency for UI
- [ ] **Transparency:** Exchange rates shown when currencies differ
- [ ] **Import:** CSV/file import reads currency column
- [ ] **Export:** CSV/file export includes currency column
- [ ] **Sample Data:** Includes multiple currencies (if applicable)
- [ ] **Calculations:** Uses converted amounts (XIRR, CAGR, totals)
- [ ] **Data Lifecycle:** Currency data cleaned up on delete
- [ ] **Cache Cleanup:** Exchange rate cache deleted (if applicable)

### 21.8 Common Violations

**❌ REJECT these patterns:**

1. **Storing converted amounts:**
```dart
class Investment {
  final double amountInBaseCurrency;  // ❌ Wrong! Breaks on currency change
}
```

2. **Assuming base currency:**
```dart
final total = cashFlows.map((cf) => cf.amount).sum();  // ❌ Wrong! Mixed currencies
```

3. **Export without currency:**
```dart
csv.add([date, name, type, amount]);  // ❌ Missing currency column
```

4. **Sample data in single currency:**
```dart
// ❌ All USD - doesn't showcase feature
createInvestment('Inv 1', currency: 'USD');
createInvestment('Inv 2', currency: 'USD');
```

5. **Forgetting cache cleanup:**
```dart
await deleteAllUserData() {
  // Delete investments, cashflows, goals...
  // ❌ Missing: Delete exchange rate cache!
}
```

### 21.9 Testing Requirements

**Multi-currency tests MUST verify:**
- [ ] Display updates when base currency changes
- [ ] Original data unchanged after currency change
- [ ] Exchange rates fetched correctly
- [ ] Import/export preserves currency info
- [ ] Calculations use converted amounts
- [ ] Cache cleanup on data deletion

**Example test:**
```dart
testWidgets('changing base currency updates display', (tester) async {
  // Create investment in USD
  final investment = InvestmentEntity(
    amount: 1000,
    currency: 'USD',
    ...
  );

  // Set base currency to INR
  await tester.pumpWidget(
    ProviderScope(
      overrides: [currencyCodeProvider.overrideWith((ref) => 'INR')],
      child: MyApp(),
    ),
  );

  // Verify display shows converted amount (not original)
  expect(find.text('₹83,120'), findsOneWidget);  // 1000 USD × 83.12
  expect(find.text('$1,000'), findsNothing);

  // Verify original data unchanged
  expect(investment.amount, 1000);
  expect(investment.currency, 'USD');
});
```

### 21.10 Migration Considerations

**When adding currency support to existing features:**

1. **Add currency field with default:**
```dart
final String currency;  // Default to 'USD' for backward compatibility
```

2. **Provide migration path for existing users:**
- Show one-time dialog: "Set currency for existing data?"
- Allow bulk update to base currency
- Allow individual review

3. **Update Firestore schema:**
```dart
// Read with fallback
currency: data['currency'] as String? ?? 'USD',
```

---

**End of Multi-Currency Compliance Rules** 🌍

