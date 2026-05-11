1. **Optimize Average/Median XIRR Calculation in `PerformanceReportService`**
   - The file `lib/features/reports/data/services/performance_report_service.dart` computes `averageXIRR` and `profitableCount`/`lossCount` using multiple `.map()`, `.reduce()`, and `.where().length` calls on the `performances` list. This iterates over the list multiple times and allocates an intermediate `xirrValues` list.
   - I will replace this with a single `for` loop that computes the sum of XIRR values and the counts of profitable/loss investments simultaneously.
   - Since `xirrValues` is also sorted to compute `medianXIRR`, I will modify `sortedByXIRR` (which is already sorted by XIRR descending) to extract the median in `O(1)` time by looking up the middle element(s) of `sortedByXIRR`.

2. **Verify changes and run tests**
   - Run `dart format` on `lib/features/reports/data/services/performance_report_service.dart`.
   - Run `flutter test test/features/reports/data/services/performance_report_service_test.dart` to verify no functionality is broken.
   - Run linter using `flutter analyze`.

3. Complete pre-commit steps to ensure proper testing, verification, review, and reflection are done.
