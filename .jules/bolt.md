## 2024-05-11 - O(N) Array Operations in Dart
**Learning:** Multiple functional array methods in Dart such as `.map().toList()`, `.reduce()`, and `.where().length` when chained sequentially allocate multiple intermediate lists and iterate over the same data numerous times.
**Action:** Always combine operations into a single O(N) `for` loop to compute averages, condition counts, and summations when evaluating large datasets, particularly inside reporting services. Further, finding medians is an O(1) operation if a sorted list already exists.
