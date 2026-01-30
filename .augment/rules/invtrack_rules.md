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

### 1.3 File Size Limits
| Type | Max Lines |
|------|-----------|
| Screen | 500 |
| Widget | 300 |
| Provider | 200 |
| Repository | 400 |
| Model | 150 |

---

## 2. CODE QUALITY

### 2.1 Static Analysis
- Zero errors/warnings from `flutter analyze`
- No `// ignore:` without documented justification
- Run `dart fix --apply` before commit

### 2.2 Naming
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables: `camelCase`
- Providers: `camelCaseProvider`

### 2.3 Strong Typing
- Use enums for states/actions (no magic strings)
- No boolean explosion patterns
- Explicit return types on all functions

### 2.4 Documentation
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
- [ ] Static analysis passes
- [ ] All tests pass
- [ ] File size limits respected
- [ ] No architecture violations
- [ ] Bug fixes include tests
- [ ] PR description adequate

