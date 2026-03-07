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

## 2025-05-15 - Fast Array Minimum/Maximum with loop
**Learning:** In Dart, calculating the minimum/maximum of a list or finding extremes by comparing elements using `reduce` is significantly slower than using a simple `for` loop. `reduce((a, b) => a.isBefore(b) ? a : b)` takes ~2.5x longer than keeping a `min` variable and updating it in a single loop (`minDate = dates[i]`). Furthermore, checking multiple conditions (`min` and `max` limits) in a single loop rather than mapping the list twice using two separate `.reduce` closures halves the execution time overhead in a tight algorithmic loop like numerical analysis code.
**Action:** Prefer basic `for` loop updates for `min`/`max` over `List.reduce` operations for performance-critical path scenarios where overhead of closures impacts hot code execution time. Combine multiple loops that traverse the same list array into single passes where applicable.
