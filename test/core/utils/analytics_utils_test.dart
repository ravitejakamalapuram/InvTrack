/// Unit tests for analytics utility functions.
///
/// Tests verify privacy-safe amount range bucketing for analytics tracking,
/// ensuring compliance with InvTrack Enterprise Rules (Rule 9 and Rule 17.4).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/analytics_utils.dart';

void main() {
  group('getAmountRange', () {
    group('boundary tests', () {
      test('999 -> under_1k', () {
        expect(getAmountRange(999), 'under_1k');
      });

      test('1000 -> 1k_10k', () {
        expect(getAmountRange(1000), '1k_10k');
      });

      test('9999 -> 1k_10k', () {
        expect(getAmountRange(9999), '1k_10k');
      });

      test('10000 -> 10k_50k', () {
        expect(getAmountRange(10000), '10k_50k');
      });

      test('49999 -> 10k_50k', () {
        expect(getAmountRange(49999), '10k_50k');
      });

      test('50000 -> 50k_1L', () {
        expect(getAmountRange(50000), '50k_1L');
      });

      test('99999 -> 50k_1L', () {
        expect(getAmountRange(99999), '50k_1L');
      });

      test('100000 -> 1L_5L', () {
        expect(getAmountRange(100000), '1L_5L');
      });

      test('499999 -> 1L_5L', () {
        expect(getAmountRange(499999), '1L_5L');
      });

      test('500000 -> 5L_10L', () {
        expect(getAmountRange(500000), '5L_10L');
      });

      test('999999 -> 5L_10L', () {
        expect(getAmountRange(999999), '5L_10L');
      });

      test('1000000 -> over_10L', () {
        expect(getAmountRange(1000000), 'over_10L');
      });
    });

    group('edge cases', () {
      test('0 -> under_1k', () {
        expect(getAmountRange(0), 'under_1k');
      });

      test('0.01 -> under_1k', () {
        expect(getAmountRange(0.01), 'under_1k');
      });

      test('very large amount -> over_10L', () {
        expect(getAmountRange(10000000), 'over_10L');
      });

      test('decimal values round correctly - 999.99 -> under_1k', () {
        expect(getAmountRange(999.99), 'under_1k');
      });

      test('decimal values round correctly - 1000.01 -> 1k_10k', () {
        expect(getAmountRange(1000.01), '1k_10k');
      });
    });

    group('privacy compliance', () {
      test('exact amounts are masked to ranges', () {
        // Verify that different exact amounts in same range
        // return the same bucket (privacy-preserving)
        expect(getAmountRange(5000), '1k_10k');
        expect(getAmountRange(5500), '1k_10k');
        expect(getAmountRange(6000), '1k_10k');
      });

      test('sensitive amounts are properly bucketed', () {
        // Test typical investment amounts
        expect(getAmountRange(25000), '10k_50k');
        expect(getAmountRange(75000), '50k_1L');
        expect(getAmountRange(250000), '1L_5L');
        expect(getAmountRange(750000), '5L_10L');
        expect(getAmountRange(2500000), 'over_10L');
      });
    });
  });
}
