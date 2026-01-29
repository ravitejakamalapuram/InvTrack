import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';

void main() {
  group('AccessibilityUtils', () {
    group('formatCurrencyForScreenReader', () {
      test('formats positive amounts correctly', () {
        expect(
          AccessibilityUtils.formatCurrencyForScreenReader(1500, '₹'),
          ' 1,500 rupees',
        );
        expect(
          AccessibilityUtils.formatCurrencyForScreenReader(1234.56, '\$'),
          ' 1,234.56 dollars',
        );
      });

      test('formats negative amounts correctly', () {
        expect(
          AccessibilityUtils.formatCurrencyForScreenReader(-500, '€'),
          'negative 500 euros',
        );
      });

      test('formats large amounts correctly', () {
        expect(
          AccessibilityUtils.formatCurrencyForScreenReader(1000000, '£'),
          ' 1,000,000 pounds',
        );
      });

      test('handles unknown currency symbols', () {
        expect(
          AccessibilityUtils.formatCurrencyForScreenReader(100, '¥'),
          ' 100 ¥',
        );
      });
    });

    group('formatDateForScreenReader', () {
      test('formats date correctly', () {
        final date = DateTime(2024, 12, 25);
        expect(
          AccessibilityUtils.formatDateForScreenReader(date),
          'December 25, 2024',
        );
      });

      test('formats single digit days correctly', () {
        final date = DateTime(2024, 1, 5);
        expect(
          AccessibilityUtils.formatDateForScreenReader(date),
          'January 5, 2024',
        );
      });
    });
  });
}
