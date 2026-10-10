import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/money_precision.dart';

void main() {
  group('MoneyPrecision.fractionDigitsFor', () {
    test('uses currency minor units instead of assuming two decimals', () {
      expect(MoneyPrecision.fractionDigitsFor('JPY'), 0);
      expect(MoneyPrecision.fractionDigitsFor('clp'), 0);
      expect(MoneyPrecision.fractionDigitsFor('INR'), 2);
      expect(MoneyPrecision.fractionDigitsFor('USD'), 2);
      expect(MoneyPrecision.fractionDigitsFor('KWD'), 3);
      expect(MoneyPrecision.fractionDigitsFor('  kwd '), 3);
      expect(() => MoneyPrecision.fractionDigitsFor(' '), throwsArgumentError);
    });
  });

  group('MoneyPrecision.round', () {
    test('rounds zero-decimal currency to whole minor units', () {
      expect(MoneyPrecision.round(123.6, currencyCode: 'JPY'), 124);
      expect(MoneyPrecision.round(-123.6, currencyCode: 'JPY'), -124);
      expect(MoneyPrecision.round(123.4, currencyCode: 'JPY'), 123);
    });

    test('rounds two-decimal currency at decimal half boundaries', () {
      expect(MoneyPrecision.round(1.005, currencyCode: 'INR'), 1.01);
      expect(MoneyPrecision.round(-1.005, currencyCode: 'INR'), -1.01);
      expect(MoneyPrecision.round(1.004, currencyCode: 'USD'), 1.00);
    });

    test('preserves three-decimal currency precision', () {
      expect(MoneyPrecision.round(1.2345, currencyCode: 'KWD'), 1.235);
      expect(MoneyPrecision.round(-1.2345, currencyCode: 'KWD'), -1.235);
    });

    test('normalizes rounded negative zero to zero', () {
      expect(MoneyPrecision.round(-0.004, currencyCode: 'INR'), 0.0);
    });

    test('rejects non-finite amounts', () {
      expect(
        () => MoneyPrecision.round(double.nan, currencyCode: 'INR'),
        throwsArgumentError,
      );
      expect(
        () => MoneyPrecision.round(double.infinity, currencyCode: 'INR'),
        throwsArgumentError,
      );
    });
  });
}
