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

## 2024-05-25 - Unoptimized Image Thumbnails

**Learning:**
`Image.file` decodes images at their native resolution by default. For a document list displaying 12MP photos in 48x48 thumbnails, this causes massive memory usage (approx 48MB per image) and decoding overhead, leading to OOMs and scroll jank.

**Action:**
Added `cacheWidth: 150` to `Image.file` in list items. This instructs the engine to decode the image to a specified width (approx 3x display size for high-DPI screens), reducing memory usage by >99% for large photos while maintaining visual quality.

## 2024-05-26 - Invisible Shadows in Clipped Containers

**Learning:**
`ClipRRect` clips the painted output of its child. If the child is a `Container` with `boxShadow`, the shadow is painted outside the box and immediately clipped (making it invisible). However, the engine still calculates the shadow blur (e.g., radius 24), wasting GPU cycles for no visual benefit.

**Action:**
Explicitly remove `boxShadow` (set to `[]`) when a container is wrapped in `ClipRRect`, unless the shadow is applied to a parent widget outside the clip.

## 2024-05-27 - Uncapped Staggered Animation Delays

**Learning:**
Using `index * delay` for staggered animations in a virtualized list (`SliverList`) causes massive delays for items deep in the list (e.g., index 50 = 2.5s delay), making them appear blank initially.

**Action:**
Clamp the index used for delay calculation (e.g., `min(index, 5)`) so that items deep in the list animate in quickly (relative to their appearance time) while still preserving the stagger effect for the initial batch.

## 2024-05-28 - DateFormat Instantiation Overhead

**Learning:**
Creating a new `DateFormat` instance (e.g., `DateFormat('MMM d, y')`) involves parsing the pattern string and loading locale data, which is computationally expensive. Doing this inside a list item build method (or a frequently called utility) causes significant CPU overhead and garbage collection pressure, reducing scroll performance.

**Action:**
Cache `DateFormat` instances as `static final` fields in utility classes. This reduces the cost from O(Parsing) to O(1). Note: Cached instances capture the locale at initialization time, which is acceptable for single-locale apps but requires invalidation logic for dynamic locale switching.

## 2026-01-30 - Rebuilding Static Subtrees in Animations

**Learning:**
`AnimatedBuilder` rebuilds its builder closure on every animation tick. If `widget.child` (or a complex static subtree) is accessed directly inside the closure, it conceptually re-inserts the widget into the tree. While Flutter's element diffing handles this, constructing the widget tree (e.g. `Container(decoration: ... child: widget.child)`) inside the builder adds CPU overhead on every frame.

**Action:**
Pass static subtrees (like `widget.child` or pre-built `Container`s) to the `child` parameter of `AnimatedBuilder`. This allows the builder to reuse the same widget instance, and in the case of hoisted subtrees, prevents `BoxDecoration` and other objects from being recreated 60 times per second.

## 2024-05-30 - Redundant `pow` Calls in Iterative Solvers

**Learning:**
Iterative numerical methods like Newton-Raphson often compute $f(x)$ and $f'(x)$ separately. In financial formulas like XNPV, both functions share expensive terms like $(1+x)^t$. Calculating these separately doubles the cost of `pow`, which is a significant CPU consumer in tight loops.

**Action:**
Combined $f(x)$ and $f'(x)$ calculation into a single pass that returns a record `(double, double)`. This allows reusing the expensive `pow((1+x), t)` result for both terms, reducing execution time by ~45% for XIRR calculations.

## 2026-02-12 - Replacing pow() with exp() in Tight Loops

**Learning:**
In Dart (and many languages), `pow(base, exponent)` is implemented as `exp(exponent * log(base))`. When the base is constant inside a loop (like `(1+x)` in XIRR calculations), calling `pow` repeatedly re-calculates `log(base)` O(N) times. By hoisting `log(base)` out of the loop and using `exp(p * lnBase)`, we save N expensive log calculations.

**Action:**
Identify loops where `pow(base, variable)` is called with a loop-invariant base. Replace with pre-calculated log and `exp()` for a ~2x speedup. Also, avoid redundant verification steps in iterative solvers if the convergence criteria already implies the result is correct.

## 2026-02-13 - Replacing `reduce` with `for` loop for min/max calculations

**Learning:**
Using `reduce` to find the minimum or maximum value in a list (e.g., `dates.reduce((a, b) => a.isBefore(b) ? a : b)`) is significantly slower than using a simple `for` loop. The overhead of calling the closure function for every element in the list is substantial, especially for large lists or complex objects like `DateTime`. Furthermore, extracting comparable primitives like `millisecondsSinceEpoch` before the loop and using that for comparison can boost the performance even further.

**Action:**
When finding the minimum or maximum of a list, especially in performance-critical code or tight loops, replace `.reduce()` with a standard `for` loop. For objects, compare primitive properties (like `int` or `double`) directly.

## 2026-02-13 - Pre-negating loop-invariant values in tight loops

**Learning:**
In mathematically intensive loops, operations like `-p * lnBase` or `val * (-p)` execute a negation on every iteration. Pre-computing the negated loop-invariant value (e.g., `negLnBase = -log(base)`) and changing the mathematical operation (e.g., `sum += val * (-p)` to `sum -= val * p`) avoids these unnecessary per-iteration negations. This micro-optimization measurably improves execution speed in large loops.

**Action:**
When optimizing tight mathematical loops, identify loop-invariant values and pre-negate them if they are used in a negation context. Also, simplify additions of negative products to subtractions to avoid the negation operation altogether.
