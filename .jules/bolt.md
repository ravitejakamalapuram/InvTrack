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
