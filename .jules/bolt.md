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
