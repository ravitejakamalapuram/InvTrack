// A11 (#755) review: a comma typed as the decimal mark ("1500,50" from a
// German keyboard, or by a EUR user whose amounts read 1.500,50) was
// stripped as grouping and saved 100 times too large.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/amount_input.dart';

void main() {
  group('parseAmountInput', () {
    test('a comma-decimal locale reads the comma as the decimal mark', () {
      expect(parseAmountInput('1500,50', 'de_DE'), 1500.50);
      expect(parseAmountInput('1.500,50', 'de_DE'), 1500.50);
      expect(parseAmountInput('1.500.000', 'de_DE'), 1500000);
      expect(parseAmountInput('0,05', 'de_DE'), 0.05);
    });

    test('Indian and Western grouping is ignored', () {
      expect(parseAmountInput('1,50,000', 'en_IN'), 150000);
      expect(parseAmountInput('75,000', 'en_IN'), 75000);
      expect(parseAmountInput('1,25,000.75', 'en_IN'), 125000.75);
      expect(parseAmountInput('1,500,000.50', 'en_US'), 1500000.50);
      expect(parseAmountInput(' 1 500 ', 'en_US'), 1500);
    });

    test('a comma that cannot be grouping is a decimal mark anywhere', () {
      // Two digits after a single comma is never a thousands group.
      expect(parseAmountInput('1500,50', 'en_IN'), 1500.50);
      expect(parseAmountInput('1500,5', 'en_US'), 1500.5);
      // Likewise a single point under a comma-decimal locale.
      expect(parseAmountInput('1500.50', 'de_DE'), 1500.50);
    });

    test('ambiguous or malformed input is rejected, not rescaled', () {
      expect(parseAmountInput('1,5000', 'en_IN'), isNull);
      expect(parseAmountInput('1,50,00', 'en_IN'), isNull);
      expect(parseAmountInput('1.500.50', 'en_US'), isNull);
      expect(parseAmountInput('1,500.50.25', 'en_US'), isNull);
      expect(parseAmountInput('1.5000', 'de_DE'), isNull);
      expect(parseAmountInput(',', 'de_DE'), isNull);
      expect(parseAmountInput('', 'en_IN'), isNull);
      expect(parseAmountInput('-5', 'en_IN'), isNull);
      expect(parseAmountInput('abc', 'en_IN'), isNull);
    });
  });

  group('amountInputText', () {
    test('writes the locale decimal mark, so it parses back exactly', () {
      expect(amountInputText(1234.56, 'de_DE'), '1234,56');
      expect(amountInputText(1234.56, 'en_IN'), '1234.56');
      expect(amountInputText(1500, 'de_DE'), '1500');
      for (final locale in ['de_DE', 'en_IN', 'en_US']) {
        for (final value in [1234.56, 1500.125, 0.05, 75000.0]) {
          expect(
            parseAmountInput(amountInputText(value, locale), locale),
            value,
            reason: '$value in $locale',
          );
        }
      }
    });
  });
}
