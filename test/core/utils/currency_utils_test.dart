import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';

void main() {
  group('Currency Utils', () {
    group('getCurrencySymbol', () {
      test('returns correct symbol for INR', () {
        expect(getCurrencySymbol('INR'), '₹');
      });

      test('returns correct symbol for USD', () {
        expect(getCurrencySymbol('USD'), '\$');
      });

      test('returns correct symbol for EUR', () {
        expect(getCurrencySymbol('EUR'), '€');
      });

      test('returns correct symbol for GBP', () {
        expect(getCurrencySymbol('GBP'), '£');
      });

      test('returns correct symbol for JPY', () {
        expect(getCurrencySymbol('JPY'), '¥');
      });

      test('returns INR symbol for unknown currency', () {
        expect(getCurrencySymbol('XYZ'), '₹');
      });
    });

    group('getCurrencyLocale', () {
      test('returns correct locale for INR', () {
        expect(getCurrencyLocale('INR'), 'en_IN');
      });

      test('returns correct locale for USD', () {
        expect(getCurrencyLocale('USD'), 'en_US');
      });

      test('returns correct locale for EUR', () {
        expect(getCurrencyLocale('EUR'), 'de_DE');
      });

      test('returns correct locale for GBP', () {
        expect(getCurrencyLocale('GBP'), 'en_GB');
      });

      test('returns en_IN for unknown currency', () {
        expect(getCurrencyLocale('XYZ'), 'en_IN');
      });
    });

    group('formatCurrency', () {
      test('formats INR with Indian locale', () {
        final result = formatCurrency(100000, '₹', 'en_IN');
        expect(result, contains('₹'));
        expect(result, contains('1,00,000'));
      });

      test('formats USD with US locale', () {
        final result = formatCurrency(100000, '\$', 'en_US');
        expect(result, contains('\$'));
        expect(result, contains('100,000'));
      });

      test('formats with decimal digits', () {
        final result = formatCurrency(1000.5, '₹', 'en_IN', decimalDigits: 2);
        expect(result, contains('.50'));
      });
    });

    group('formatNumber', () {
      test('formats number without currency symbol', () {
        final result = formatNumber(100000, 'en_IN');
        expect(result, isNot(contains('₹')));
        expect(result, contains('1,00,000'));
      });

      test('formats with decimal digits', () {
        final result = formatNumber(1000.55, 'en_US', decimalDigits: 2);
        expect(result, contains('.55'));
      });
    });

    group('formatCompactIndian (deprecated - use formatCompactCurrency)', () {
      test('formats crores correctly', () {
        expect(formatCompactCurrency(10000000, symbol: '₹', locale: 'en_IN'), '₹1Cr');
        expect(formatCompactCurrency(15000000, symbol: '₹', locale: 'en_IN'), '₹1.5Cr');
        expect(formatCompactCurrency(25600000, symbol: '₹', locale: 'en_IN'), '₹2.6Cr');
      });

      test('formats lakhs correctly', () {
        expect(formatCompactCurrency(100000, symbol: '₹', locale: 'en_IN'), '₹1L');
        expect(formatCompactCurrency(150000, symbol: '₹', locale: 'en_IN'), '₹1.5L');
        expect(formatCompactCurrency(256000, symbol: '₹', locale: 'en_IN'), '₹2.6L');
      });

      test('formats thousands correctly', () {
        expect(formatCompactCurrency(1000, symbol: '₹', locale: 'en_IN'), '₹1K');
        expect(formatCompactCurrency(1500, symbol: '₹', locale: 'en_IN'), '₹1.5K');
        expect(formatCompactCurrency(2600, symbol: '₹', locale: 'en_IN'), '₹2.6K');
      });

      test('formats small amounts without suffix', () {
        expect(formatCompactCurrency(500, symbol: '₹', locale: 'en_IN'), '₹500');
        expect(formatCompactCurrency(999, symbol: '₹', locale: 'en_IN'), '₹999');
      });

      test('handles negative amounts', () {
        expect(formatCompactCurrency(-100000, symbol: '₹', locale: 'en_IN'), '-₹1L');
        expect(formatCompactCurrency(-1500, symbol: '₹', locale: 'en_IN'), '-₹1.5K');
      });

      test('uses custom symbol', () {
        expect(formatCompactCurrency(100000, symbol: '\$', locale: 'en_IN'), '\$1L');
      });

      test('formats with appropriate precision', () {
        final result = formatCompactCurrency(156789, symbol: '₹', locale: 'en_IN');
        expect(result, contains('1.5'));
      });

      test('formats round amounts correctly', () {
        final result = formatCompactCurrency(
          100000,
          symbol: '₹',
          locale: 'en_IN',
        );
        expect(result, '₹1L');
      });
    });

    group('formatSmartCurrency', () {
      test('uses compact format above threshold', () {
        final result = formatSmartCurrency(
          150000,
          symbol: '₹',
          locale: 'en_IN',
        );
        expect(result, contains('L'));
      });

      test('uses full format below threshold', () {
        final result = formatSmartCurrency(
          50000,
          symbol: '₹',
          locale: 'en_IN',
        );
        expect(result, contains('50,000'));
        expect(result, isNot(contains('K')));
      });

      test('respects custom threshold', () {
        final result = formatSmartCurrency(
          50000,
          symbol: '₹',
          locale: 'en_IN',
          compactThreshold: 10000,
        );
        expect(result, contains('K'));
      });
    });
  });
}
