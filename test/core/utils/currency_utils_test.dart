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

    group('formatCompactIndian', () {
      test('formats crores correctly', () {
        expect(formatCompactIndian(10000000), '₹1Cr');
        expect(formatCompactIndian(15000000), '₹1.5Cr');
        expect(formatCompactIndian(25600000), '₹2.6Cr');
      });

      test('formats lakhs correctly', () {
        expect(formatCompactIndian(100000), '₹1L');
        expect(formatCompactIndian(150000), '₹1.5L');
        expect(formatCompactIndian(256000), '₹2.6L');
      });

      test('formats thousands correctly', () {
        expect(formatCompactIndian(1000), '₹1K');
        expect(formatCompactIndian(1500), '₹1.5K');
        expect(formatCompactIndian(2600), '₹2.6K');
      });

      test('formats small amounts without suffix', () {
        expect(formatCompactIndian(500), '₹500');
        expect(formatCompactIndian(999), '₹999');
      });

      test('handles negative amounts', () {
        expect(formatCompactIndian(-100000), '-₹1L');
        expect(formatCompactIndian(-1500), '-₹1.5K');
      });

      test('uses custom symbol', () {
        expect(formatCompactIndian(100000, symbol: '\$'), '\$1L');
      });

      test('respects maxDecimals', () {
        final result = formatCompactIndian(156789, maxDecimals: 2);
        expect(result, contains('1.5'));
      });

      test('always shows decimals when requested', () {
        final result = formatCompactIndian(
          100000,
          alwaysShowDecimals: true,
          maxDecimals: 1,
        );
        expect(result, '₹1.0L');
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
        final result = formatSmartCurrency(50000, symbol: '₹', locale: 'en_IN');
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
