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

## 2025-01-20 - Pre-filter zero-value cash flows before XIRR solver

**Learning:** In the XIRR calculation, zero-amount cash flows don't affect the final result but add unnecessary elements to the input arrays, increasing iteration cycles and calculation overhead inside the numerical solver (Newton-Raphson method).
**Action:** When preparing inputs for mathematically intensive solvers like XIRR, iterate and pre-filter zero-value elements (`amount == 0.0`) using an early `continue` in the mapping loop. This simple `O(N)` filter reduces array sizes and avoids redundant iterations inside the $O(N \times M)$ solver loop.
