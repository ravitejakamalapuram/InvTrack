---
type: "always_apply"
---

# Riverpod State Management Rules – InvTrack

These rules ensure consistent, testable, and efficient state management.

---

## RIVERPOD RULE 1: PROVIDER LOCATION
Providers MUST be in:
```
lib/features/{feature}/presentation/providers/
```

Naming convention:
```
{feature}_provider.dart
```

Example: `lib/features/investment/presentation/providers/investment_provider.dart`

---

## RIVERPOD RULE 2: PROVIDER TYPE SELECTION

| Use Case | Provider Type |
|----------|---------------|
| Simple sync value | `Provider` |
| Async data fetch | `FutureProvider` |
| Real-time data | `StreamProvider` |
| Mutable state | `StateProvider` |
| Complex state + logic | `StateNotifierProvider` / `NotifierProvider` |
| Async state + logic | `AsyncNotifierProvider` |
| Parameterized data | `.family` modifier |
| Screen-specific data | `.autoDispose` modifier |

---

## RIVERPOD RULE 3: REF USAGE PATTERNS
```dart
// ✅ In build() - reactive, triggers rebuild
final data = ref.watch(myProvider);

// ✅ For one-time read (callbacks, methods)
final data = ref.read(myProvider);

// ✅ For side effects (navigation, snackbars)
ref.listen(myProvider, (prev, next) {
  if (next.hasError) showSnackbar(next.error);
});

// ❌ Never use ref.read in build
Widget build(context, ref) {
  final data = ref.read(myProvider); // WRONG!
}
```

---

## RIVERPOD RULE 4: AUTODISPOSE USAGE
Use `.autoDispose` when:
- Data is screen-specific
- Provider holds resources (streams, connections)
- Data should refresh on re-entry

```dart
// ✅ Disposed when screen is popped
final screenDataProvider = FutureProvider.autoDispose((ref) => ...);

// ✅ Keep alive briefly for back navigation
final cachedProvider = FutureProvider.autoDispose((ref) {
  ref.keepAlive(); // Prevents immediate disposal
  Timer(Duration(seconds: 30), () => ref.invalidateSelf());
  return fetchData();
});
```

---

## RIVERPOD RULE 5: FAMILY PROVIDERS
Use `.family` for parameterized providers:
```dart
// ✅ Correct - parameter-based provider
final investmentByIdProvider = FutureProvider.family<InvestmentEntity?, String>(
  (ref, id) => ref.watch(investmentRepositoryProvider).getById(id),
);

// Usage
final investment = ref.watch(investmentByIdProvider(investmentId));
```

Family key requirements:
- Must be immutable
- Must implement `==` and `hashCode`
- Prefer primitives (String, int) over objects

---

## RIVERPOD RULE 6: ERROR HANDLING
Always handle AsyncValue states:
```dart
ref.watch(myAsyncProvider).when(
  data: (data) => DataWidget(data),
  loading: () => const LoadingIndicator(),
  error: (error, stack) => ErrorWidget(error),
);

// Or with pattern matching
switch (asyncValue) {
  AsyncData(:final value) => DataWidget(value),
  AsyncLoading() => const LoadingIndicator(),
  AsyncError(:final error) => ErrorWidget(error),
}
```

Never use `.value!` without null check.

---

## RIVERPOD RULE 7: PROVIDER DEPENDENCIES
Document and manage dependencies:
```dart
/// Depends on:
/// - [authStateProvider] for user ID
/// - [firestoreProvider] for database access
final investmentRepositoryProvider = Provider<InvestmentRepository>((ref) {
  final userId = ref.watch(authStateProvider).value?.uid;
  if (userId == null) throw StateError('User not authenticated');
  return FirestoreInvestmentRepository(ref.watch(firestoreProvider), userId);
});
```

Avoid circular dependencies. Use `.family` or restructure if needed.

---

## RIVERPOD RULE 8: NOTIFIER PATTERNS
For StateNotifier/Notifier classes:
```dart
class InvestmentNotifier extends StateNotifier<AsyncValue<List<Investment>>> {
  InvestmentNotifier(this._repository) : super(const AsyncLoading()) {
    _load();
  }
  
  final InvestmentRepository _repository;
  
  Future<void> _load() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.getAll());
  }
  
  Future<void> add(Investment investment) async {
    await _repository.create(investment);
    await _load(); // Refresh state
  }
}
```

---

## RIVERPOD RULE 9: TESTING PROVIDERS
Test with ProviderContainer:
```dart
test('investment provider returns data', () async {
  final container = ProviderContainer(
    overrides: [
      investmentRepositoryProvider.overrideWithValue(MockRepository()),
    ],
  );
  addTearDown(container.dispose);
  
  final result = await container.read(investmentsProvider.future);
  expect(result, isNotEmpty);
});
```

---

## RIVERPOD RULE 10: PERFORMANCE OPTIMIZATION
```dart
// ✅ Select specific fields to minimize rebuilds
final investmentName = ref.watch(
  investmentProvider(id).select((inv) => inv?.name),
);

// ✅ Use selectAsync for async providers
final count = await ref.watch(
  investmentsProvider.selectAsync((list) => list.length),
);

// ❌ Avoid watching entire provider when subset needed
final allInvestments = ref.watch(investmentsProvider);
Text(allInvestments.value?.first.name ?? ''); // Rebuilds on ANY change
```

---

## RIVERPOD RULE 11: SIDE EFFECTS
Handle side effects with ref.listen:
```dart
ref.listen(authStateProvider, (previous, next) {
  if (previous?.value != null && next.value == null) {
    // User logged out - navigate to login
    context.go('/login');
  }
});
```

Never trigger navigation or show dialogs directly from provider changes without ref.listen.

---

## RIVERPOD RULE 12: PROVIDER SCOPING
Use ProviderScope overrides for:
- Testing (mock dependencies)
- Feature flags
- Platform-specific implementations

```dart
ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(mockPrefs),
  ],
  child: MyApp(),
)
```

