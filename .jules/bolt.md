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

## 2026-03-26 - Single pass iteration over multiple .where() partitions

**Learning:** When partitioning a list into multiple categories (e.g., separating items by status or counting them simultaneously), using sequential `.where().length` or `.where().toList()` operations creates unnecessary iterations and intermediate list allocations.
**Action:** Replace multiple sequential `.where()` calls on the same collection with a single `O(N)` `for` loop. You can use standard `if/else` branches to simultaneously partition lists and sum/count values in a single pass.
