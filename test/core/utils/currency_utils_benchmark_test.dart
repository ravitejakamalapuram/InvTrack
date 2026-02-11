// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';

void main() {
  test('Benchmark formatCurrency', () {
    final stopwatch = Stopwatch()..start();
    const iterations = 10000;

    // Warmup
    for (int i = 0; i < 100; i++) {
      formatCurrency(1234.56, '₹', 'en_IN');
    }

    // Benchmark
    stopwatch.reset();
    stopwatch.start();
    for (int i = 0; i < iterations; i++) {
      formatCurrency(1234.56, '₹', 'en_IN');
      formatCurrency(9876.54, '\$', 'en_US');
      formatCompactCurrency(1234567.89, symbol: '₹', locale: 'en_IN');
    }
    stopwatch.stop();

    print('Benchmark Result: Time taken for $iterations iterations: ${stopwatch.elapsedMilliseconds}ms');
    print('Average time per iteration: ${stopwatch.elapsedMicroseconds / iterations}µs');
  });
}
