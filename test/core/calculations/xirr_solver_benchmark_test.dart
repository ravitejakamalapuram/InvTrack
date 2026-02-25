// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';

void main() {
  test('Benchmark calculateXirr - Large Dataset', () {
    // Generate large dataset (5 years of weekly investments)
    final dates = <DateTime>[];
    final amounts = <double>[];

    // 260 weekly investments
    for (int i = 0; i < 260; i++) {
      dates.add(DateTime(2020, 1, 1).add(Duration(days: i * 7)));
      amounts.add(-1000.0);
    }

    // Final redemption
    dates.add(DateTime(2025, 1, 1));
    amounts.add(350000.0); // Good return

    const iterations = 1000;

    // Warmup
    for (int i = 0; i < 100; i++) {
      XirrSolver.calculateXirr(dates, amounts);
    }

    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < iterations; i++) {
      XirrSolver.calculateXirr(dates, amounts);
    }

    stopwatch.stop();

    print('Benchmark Result: Time taken for $iterations XIRR calculations (260 cash flows each): ${stopwatch.elapsedMilliseconds}ms');
    print('Average time per calculation: ${stopwatch.elapsedMicroseconds / iterations}µs');

    // Sanity check
    expect(XirrSolver.calculateXirr(dates, amounts), isNotNull);
  });
}
