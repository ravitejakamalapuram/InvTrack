---
type: "always_apply"
---

# Performance & Optimization Rules – InvTrack

These rules ensure smooth 60fps UI and efficient resource usage.

---

## PERF RULE 1: STARTUP OPTIMIZATION
Main initialization pattern:
```dart
void main() async {
  // 1. Critical path only (Firebase, SharedPrefs)
  await Future.wait([criticalInit1, criticalInit2]);
  
  // 2. Launch UI immediately
  runApp(MyApp());
  
  // 3. Defer non-critical to post-frame
  SchedulerBinding.instance.addPostFrameCallback((_) {
    _initializeNonCriticalServices();
  });
}
```

❌ Never block app launch for non-critical initialization
❌ Never await network calls in main()

---

## PERF RULE 2: CONST CONSTRUCTORS
Use `const` everywhere possible:
```dart
// ✅ Good
const SizedBox(height: 16),
const EdgeInsets.all(16),
const Text('Static text'),

// ❌ Bad - creates new instance every rebuild
SizedBox(height: 16),
EdgeInsets.all(16),
```

Const widgets are canonicalized and skip rebuild checks.

---

## PERF RULE 3: WIDGET REBUILD OPTIMIZATION
Minimize rebuilds:
```dart
// ✅ Use ref.select for specific fields
final name = ref.watch(userProvider.select((u) => u.name));

// ❌ Avoid watching entire objects when only one field needed
final user = ref.watch(userProvider);
Text(user.name); // Rebuilds on ANY user change
```

Split large widgets into smaller const children.

---

## PERF RULE 4: LIST PERFORMANCE
For lists with many items:
```dart
// ✅ Use ListView.builder (lazy loading)
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemWidget(items[index]),
)

// ❌ Never use Column with many children
Column(children: items.map((i) => ItemWidget(i)).toList())
```

- Use `itemExtent` if items have fixed height
- Use `cacheExtent` for smoother scrolling
- Consider pagination for 100+ items

---

## PERF RULE 5: IMAGE OPTIMIZATION
- Compress images before adding to assets (<500KB)
- Use appropriate resolution variants (1x, 2x, 3x)
- Use `cacheWidth`/`cacheHeight` for network images
- Dispose image controllers properly
- Consider lazy loading for image-heavy screens

---

## PERF RULE 6: STREAM MANAGEMENT
Always dispose streams:
```dart
class _MyWidgetState extends State<MyWidget> {
  StreamSubscription? _subscription;
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
```

Use `.autoDispose` for providers that should clean up:
```dart
final myProvider = StreamProvider.autoDispose((ref) => ...);
```

---

## PERF RULE 7: ASYNC BEST PRACTICES
```dart
// ✅ Parallel when independent
await Future.wait([task1(), task2(), task3()]);

// ❌ Sequential when independent (slower)
await task1();
await task2();
await task3();
```

- Use `compute()` for heavy CPU work
- Never await in build methods
- Show loading states for operations >100ms

---

## PERF RULE 8: MEMORY MANAGEMENT
- Dispose controllers: `TextEditingController`, `AnimationController`, `ScrollController`
- Cancel timers and subscriptions in `dispose()`
- Use weak references for caches if needed
- Avoid storing large objects in state
- Clear caches when memory pressure detected

---

## PERF RULE 9: PROVIDER EFFICIENCY
```dart
// ✅ Use .family for parameterized providers
final investmentProvider = FutureProvider.family<Investment, String>((ref, id) => ...);

// ✅ Use .autoDispose for screen-specific data
final screenDataProvider = FutureProvider.autoDispose((ref) => ...);

// ❌ Avoid creating providers dynamically in build
```

---

## PERF RULE 10: BUILD METHOD HYGIENE
In build methods:
- ❌ No async/await
- ❌ No heavy computations
- ❌ No print statements
- ❌ No side effects
- ✅ Only widget tree construction
- ✅ Use ref.listen for side effects

---

## PERF RULE 11: ANIMATION PERFORMANCE
- Use `AnimatedBuilder` or `AnimatedWidget` for custom animations
- Prefer implicit animations (`AnimatedContainer`, `AnimatedOpacity`)
- Keep animations at 60fps (use `flutter performance` to check)
- Avoid animating expensive widgets
- Use `RepaintBoundary` for isolated animations

---

## PERF RULE 12: DEBUG PERFORMANCE
When debugging performance:
1. Run in profile mode: `flutter run --profile`
2. Use Flutter DevTools Performance tab
3. Look for jank (frames >16ms)
4. Check widget rebuild counts
5. Profile on real devices, not emulators

