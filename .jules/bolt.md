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
