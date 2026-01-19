## 2024-05-22 - O(N) XIRR Calculation in List Sorting

**Learning:**
Reactive lists that depend on computed properties for sorting can trigger expensive calculations for EVERY item in the list, even if the item is off-screen. In this case, `filteredInvestmentsProvider` was calculating XIRR (an iterative solver) for every investment just to sort them by date.

**Action:**
Split expensive computations into separate providers or optional flags. We created `investmentBasicStatsProvider` which skips XIRR calculation, reducing the sorting cost from O(N * Iterations) to O(N) for basic arithmetic. Only used the expensive provider when explicitly sorting by XIRR.

## 2024-05-23 - Blocking UI with Synchronous XIRR Calculation

**Learning:**
Even with separate providers, performing iterative calculations (like XIRR) synchronously on the main thread inside a `Provider` body causes UI jank. This is because `ref.watch` triggers immediate re-evaluation when dependencies change, blocking the frame.

**Action:**
Offloaded the calculation to a background isolate using `compute`. Converted the provider to a `FutureProvider` and used `ref.watch(provider.selectAsync(...))` to maintain reactivity while allowing the heavy lifting to happen in parallel.

## 2024-05-24 - Implicit BackdropFilter in List Items

**Learning:**
The `GlassCard` widget defaults to `blur: 10`, which triggers `BackdropFilter` and `saveLayer`. Using this widget in a `ListView` (like `InvestmentCard`) without explicitly setting `blur: 0` causes massive GPU overdraw and scrolling jank, even if the background is solid and the blur is visually redundant.

**Action:**
Explicitly set `blur: 0` on `GlassCard` when used in scrollable lists. This bypasses the expensive filter pipeline while maintaining the semi-transparent "glass" look via alpha blending.
