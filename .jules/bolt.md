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

## 2024-05-26 - Unbounded Animation Delays in Infinite Lists

**Learning:**
Widgets that calculate animation delays based on their list index (e.g., `delay * index`) without clamping cause excessive wait times for items deeper in the list. For a 100-item list, the 100th item waits 5 seconds to appear, creating a "broken" UX where users see empty space.

**Action:**
Always clamp delay calculations to a small maximum (e.g., first 5-10 items) or use modulo arithmetic to ensure items further down the list appear promptly while maintaining the stagger effect for the initial screen.

## 2024-05-26 - Invisible Shadows in Clipped Containers

**Learning:**
`ClipRRect` clips the painted output of its child. If the child is a `Container` with `boxShadow`, the shadow is painted outside the box and immediately clipped (making it invisible). However, the engine still calculates the shadow blur (e.g., radius 24), wasting GPU cycles for no visual benefit.

**Action:**
Explicitly remove `boxShadow` (set to `[]`) when a container is wrapped in `ClipRRect`, unless the shadow is applied to a parent widget outside the clip.
