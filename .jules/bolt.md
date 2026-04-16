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
