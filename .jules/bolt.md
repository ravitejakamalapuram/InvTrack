## 2024-05-19 - Fast Date diff optimization in Dart
**Learning:** `DateTime.difference` and then calling `inDays` is quite slow in tight loops.
**Action:** When calculating difference between two dates in days inside a large loop (like in XIRR preprocessing), convert them to `millisecondsSinceEpoch` and do simple integer division (`(ms1 - ms2) ~/ 86400000`). This is significantly faster while still returning mathematically equivalent output.

## 2024-05-19 - `List.reduce` vs loops for Finding Minimum Date
**Learning:** Calling `List.reduce` with `a.isBefore(b)` is somewhat slow compared to extracting `millisecondsSinceEpoch` and performing a basic loop comparison.
**Action:** When finding the min/max of many dates, try using `millisecondsSinceEpoch` inside a basic `for` loop if this proves to be a bottleneck.

## 2024-05-19 - Fast Date diff optimization in Dart
**Learning:** `DateTime.difference` and then calling `inDays` is quite slow in tight loops.
**Action:** When calculating difference between two dates in days inside a large loop (like in XIRR preprocessing), convert them to `millisecondsSinceEpoch` and do simple integer division (`(ms1 - ms2) ~/ 86400000`). This is significantly faster while still returning mathematically equivalent output.

## 2024-05-19 - `List.reduce` vs loops for Finding Minimum Date
**Learning:** Calling `List.reduce` with `a.isBefore(b)` is somewhat slow compared to extracting `millisecondsSinceEpoch` and performing a basic loop comparison.
**Action:** When finding the min/max of many dates, try using `millisecondsSinceEpoch` inside a basic `for` loop if this proves to be a bottleneck.

## 2024-05-19 - Replace .where().fold() with O(N) map
**Learning:** Chaining `.where().fold()` inside a loop (like iterating through investments and filtering all cash flows) results in `O(N * M)` complexity and creates unnecessary iterable allocations and closures.
**Action:** Pre-calculate grouped totals in a single `O(N)` pass using a `Map`, then access them in `O(1)` during the secondary loop. This changes complexity to `O(N + M)` and significantly improves performance for list aggregations.

## 2024-05-19 - Replace .fold() with standard loop

**Learning:** Using `.fold()` in Dart incurs closure overhead for every iteration, which can be slow in tight loops or large collections.
**Action:** Replace `.fold()` with standard `for` loops in performance-critical sections to eliminate closure overhead and improve execution time.

## 2024-05-19 - Fast Multiple Filter Optimization

**Learning:** Chaining multiple `.where().toList()` operations in Dart creates intermediate lists and iterates over the data multiple times, causing O(N*M) time complexity overhead.
**Action:** Replace multiple sequential `.where().toList()` calls with a single `for` loop pass that applies all filter conditions using `continue` statements to skip non-matching elements. This results in an O(N) operation with only a single list allocation.

## 2024-05-19 - Single Pass Multiple Metric Extraction

**Learning:** When extracting multiple metrics (e.g., counting different statuses or summing different values) from the same collection, using multiple sequential `.where()` calls causes the application to iterate over the entire collection multiple times unnecessarily.
**Action:** Replace sequential `.where()` aggregations with a single `O(N)` `for` loop that calculates all necessary metrics simultaneously. This eliminates redundant iterations and intermediate iterable allocations, significantly improving performance on large collections.

## 2024-05-19 - Fast Batch Conversion Optimization

**Learning:** Iterating through a list and making sequential `await` calls to a service method inside a loop creates an N+1 problem, which is extremely slow when dealing with network or complex cache operations (like currency conversion of cash flows).
**Action:** Replace sequential asynchronous calls inside a loop with a single bulk operation like `BatchCurrencyConverter.batchConvert()`, which handles data deduplication and enables parallel asynchronous processing, significantly improving processing speeds.

## 2024-05-20 - Single Pass Multiple Metric Extraction in Goal Progress Provider

**Learning:** When extracting multiple metrics (e.g., counting achieved, on-track, behind goals, and separating active vs completed goals) from the same collection, using multiple sequential `.where()` and `.toList()` calls causes the application to iterate over the entire collection multiple times unnecessarily, generating intermediate lists and closures.
**Action:** Replace sequential aggregations with a single `O(N)` `for` loop that calculates all necessary metrics simultaneously. This eliminates redundant iterations and intermediate iterable allocations, significantly improving performance on large collections.

## 2024-05-20 - O(N*M) Multiple Iterable Generation

**Learning:** When calculating values that group multiple subsets together (e.g. associating cash flows to recently closed investments), iterating over the smaller set and filtering the larger list on every pass via `.where(...).toList()` allocates multiple closures and intermediate lists with an O(N * M) cost.
**Action:** Replace nested `.where(...).toList()` loops with an optimized single-pass O(N + M) implementation: loop over the large list once to populate a `Map` that groups items by the joining key, and then use O(1) lookups inside the smaller list iteration.

## 2024-05-20 - Parallel Async Calculations in Loops


**Learning:** In Dart, iterating over a list and running an asynchronous function sequentially inside a `for` loop using `await` creates an N+1 sequential waiting bottleneck.
**Action:** Replace sequential `await` calls inside a loop with parallel execution using `Future.wait(list.map((item) async { ... }))`. This allows all futures to resolve concurrently, drastically improving performance. Ensure the underlying async operations are safe to run in parallel (e.g., they implement request coalescing to prevent cache stampedes).

## 2024-04-12 - Dart Performance Optimization: Replacing .where().toList() with for-loops

**Learning:** Replacing Dart's native `.where().toList()` and `.reduce()` functional methods with standard `for` loops in performance-critical sections avoids closure allocation overhead per iteration, improving overall execution time.

**Action:** Identify and replace instances of `.where().toList()` and `.reduce()` in core service calculations, particularly in list aggregations and filtering within providers and business logic, to achieve significant performance improvements.

## 2026-04-15 - Optimize Collection Emptiness Checks
**Learning:** In Dart, checking if a filtered collection is empty using `.where(...).toList().isEmpty` is an anti-pattern that causes unnecessary O(N) memory allocation and iteration.
**Action:** Replace `.where(...).toList().isEmpty` with `!any(...)` (and `.where(...).toList().isNotEmpty` with `any(...)`) to enable short-circuiting, stopping iteration early on the first match and achieving O(1) memory and O(k) time complexity.

## 2024-05-24 - Avoid Micro-Optimizations that Mask Regressions

**Learning:** Attempting extreme micro-optimizations (like changing `.where().length` to `.length` on pre-validated lists) can lead to unintended consequences if data class contracts are violated or if unit tests are artificially altered to accommodate the change.
**Action:** Focus on measurable performance bottlenecks. Crucially, never modify existing unit test data (e.g., removing invalid rows from a test suite) simply to force an optimization to pass, as this destroys test coverage and masks regressions.

## 2024-05-25 - Single Pass Multiple Metric Extraction in Merge Dialog
**Learning:** When calculating `investmentTypes` to pass to a dialog, combining multiple iterations over `toMerge` (like finding the most common type via `.fold()`/`reduce()` or counting and making `.map().toSet().toList()`) causes multiple list and closure allocations.
**Action:** Replace multiple sequential operations (like `.where().toList()` and `.map().toSet().toList()`) with a single `O(N)` pass `for` loop to build the required lists/sets simultaneously and eliminate overhead.

## 2026-05-02 - Single Pass Multiple Metric Extraction in WeeklySummaryService
**Learning:** Chaining multiple `.where().fold()` operations to compute multiple metrics across a collection results in excessive iteration and closure allocation overhead, operating essentially at O(K*N) complexity.
**Action:** Replace multiple chained operations with a single, standard `for` loop to process all items in a single O(N) pass, accumulating required metrics concurrently to optimize processing speed.
## 2026-05-06 - Optimize O(N*M) nested iterations in Dart
**Learning:** The `.firstWhere()` lookup inside loops is an anti-pattern when finding matches between two arrays, resulting in O(N*M) time complexity. Using unhandled `.firstWhere()` (without `orElse`) can also lead to `StateError` exceptions that crash processing when matching records are missing. Pre-grouping data in a `Map` or `HashMap` before nested iterations eliminates O(N*M) bottlenecks. Grouping data in Dart is simple with operations like `putIfAbsent()` and dictionary comprehensions (e.g. `{for (final item in items) item.id: item}`).
**Action:** Use a pre-computed dictionary comprehension (e.g. `final map = {for (final item in items) item.id: item};`) before the loop. This converts performance from O(N*M) to O(N+M) while enabling safe null-checks (`if (item == null) continue;`) to avoid crashes on missing data. Always replace `.where(...).toList()` operations inside a loop with a single `Map` lookup by pre-computing mappings outside the loop.
## 2026-05-10 - Pre-Group Iterations by Date to Change O(D*N) to O(N+D)
**Learning:** In scenarios where multiple iterations over a single array are bounded by sequential variables (like dates in a `while` loop), putting a `.where` condition inside the loop introduces a heavy O(D*N) execution time.
**Action:** Use a pre-computed dictionary to bucket or group values (e.g. by date format) outside of the loop first. It modifies the complexity to O(N+D), dramatically enhancing loop execution times.
## 2024-06-25 - Avoid nested iterable lookups in loop optimizations
**Learning:** Dart's `.where()` iteration is O(N) when performed over collections. Nesting `.where().toList()` inside a loop (like iterating through investments and looking up their cash flows) creates an O(N*M) time complexity bottleneck. Furthermore, calculating multiple aggregated metrics from the same subset using chained `.where().fold()` causes unnecessary passes over the data.
**Action:** Always group data into an O(1) map lookup outside the loop (e.g. `final Map<String, List<Entity>> entitiesById = {}`). When calculating multiple metrics, replace `.where().fold()` chains with a single standard `for` loop to accumulate all totals simultaneously, avoiding redundant closures and passes.

## 2024-06-25 - Avoid Chaining Functional Operators for Multiple Disjoint Aggregations
**Learning:** Chaining functional operations like `.where().toList()` to partition an array followed by `.map().reduce()` to sum up the values causes O(N) intermediate allocations and up to 4 iterations over the same data.
**Action:** Replace disjoint `.where().toList()` and `.map().reduce()` subsets with a single `for` loop that iterates exactly once while concurrently accumulating the sum and counts for all conditions to achieve O(N) processing with zero intermediate collections.
## 2024-05-25 - Single Pass Aggregate Calculations with Hoisted Date Boundaries
**Learning:** In reporting services, calculating multiple aggregates sequentially using `where().fold()` across the same dataset creates an O(K*N) problem. Filtering by an invariant condition (like whether a date falls between two calculated boundaries) inside the loop results in redundant object allocation or computation per item.
**Action:** Replace multiple chains of `where().fold()` with a single O(N) `for` loop that computes all required metrics simultaneously. Furthermore, calculate loop-invariant boundaries (e.g. `startDate` and `endDate`) outside the iteration entirely to prevent redundant date arithmetic during the aggregation.
## 2026-05-15 - Replace O(N log N) sorting with O(N) linear scan for extremum finding
**Learning:** Using `array.sort()` followed by accessing `.first` or `.last` just to find the maximum or minimum element in a list (such as the most recent date) is an anti-pattern. It incurs an unnecessary O(N log N) time complexity and array mutation overhead.
**Action:** Replace `.sort()` followed by extremum access with a simple O(N) linear scan using a `for` loop. This avoids sorting the entire array and finds the minimum or maximum element efficiently in a single pass.

## 2024-05-30 - Single Pass Optimization in Monthly Income Report
**Learning:** Consolidating sequential `.where().toList()` filters and aggregations into a single loop over `allCashFlows` prevents redundant iterations and avoids intermediate array allocations, saving memory and processor time.
**Action:** Always refactor sequential `.where()` and list operations over the same dataset into a single pass loop.

## 2026-06-02 - Avoid Re-Sorting Primitive Arrays Extracted from Sorted Objects
**Learning:** If an object array is already sorted by a property, extracting that property into a primitive array and sorting it again is wasteful O(N log N) work.
**Action:** Reuse the existing object sort order when possible. For median calculations, directly access the middle element of the sorted object array instead of creating a new sorted primitive array.

## 2024-06-25 - Avoid Nested Iterable Lookups in Loop Optimizations
**Learning:** Dart's `.where()` iteration is O(N) when performed over collections. Nesting `.where().toList()` inside a loop (like iterating through investments and looking up their cash flows) creates an O(N*M) time complexity bottleneck. Furthermore, calculating multiple aggregated metrics from the same subset using chained `.where().fold()` causes unnecessary passes over the data.
**Action:** Always group data into an O(1) map lookup outside the loop (e.g. `final Map<String, List<Entity>> entitiesById = {}`). When calculating multiple metrics, replace `.where().fold()` chains with a single standard `for` loop to accumulate all totals simultaneously, avoiding redundant closures and passes.

## 2024-07-15 - Optimize Multiple Sequential Fold Operations
**Learning:** Using multiple sequential `.where(...).fold(...)` operations on the same dataset to aggregate different metrics operates at O(K*N) complexity and creates closure overhead.
**Action:** Replace multiple sequential `.where().fold()` calls with a single standard `for` loop to accumulate all required metrics concurrently in an O(N) pass, avoiding redundant iterations and closure allocations.

## 2026-05-16 - Redundant await in pre-computed iterations
**Learning:** In InvTrack's reporting services, collections named `baseCashFlows` are pre-converted to the base currency (e.g., via `batchConvert`). Performing redundant asynchronous `_engine.currency.convert` calls on these cash flows within loops introduces severe N+1 performance bottlenecks because `await` yields to the Dart event loop each time, even if the result resolves immediately.
**Action:** When calculating portfolio values or totals on `baseCashFlows`, strip `async`/`await` and extract values synchronously to allow entirely synchronous execution and eliminate N+1 bottlenecks.

## 2026-06-03 - Optimize Repeated Functional Operations on Same Dataset
**Learning:** In Dart, chaining multiple functional collection operations (`.where().toList()`, `.map()`, `.reduce()`) over the same dataset results in redundant iterations and unnecessary intermediate object allocations (like primitive lists and closures). This becomes a severe bottleneck in data processing logic where multiple aggregates or subset groupings are required.
**Action:** Consolidate chained operations into a single standard `for` loop to compute all required metrics concurrently. This reduces time complexity from multiple O(N) passes to a single O(N) pass, eliminating intermediate arrays and closure overhead.

## 2026-06-25 - Avoid Intermediate List Allocations in Filtering
**Learning:** Using `.where(...).toList()` simply to filter an array allocates closures and an intermediate primitive list. This increases memory footprint and garbage collection overhead unnecessarily in performance-critical code paths.
**Action:** Replace `.where(...).toList()` with a manual `for` loop that iterates over the array and adds matching elements to a pre-allocated or dynamically-grown list. This eliminates intermediate closures and chained iterations.
## 2026-06-25 - Maintain Bounded Top Elements List
**Learning:** Sorting an entire array just to extract the top few elements introduces a heavy O(N log N) penalty, which scales poorly when only the extremes (e.g., top 3) are needed. Gathering the items in an intermediate list only exacerbates the allocation cost.
**Action:** When extracting a bounded number of top elements (e.g., 'top 3 most recently closed investments') from an unsorted collection in Dart, use a single-pass O(N) linear scan maintaining a bounded list rather than gathering all items and sorting them in O(N log N) time. This eliminates intermediate memory allocations and significant sorting overhead.
