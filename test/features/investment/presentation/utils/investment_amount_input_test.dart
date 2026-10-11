// A40 (#783) PR-2: the amount invested field is optional. Blank means no
// amount; anything typed must be a positive amount below 15 digits, read the
// way the amount's currency writes numbers, and rounded to that currency's
// minor unit. A misread amount (100 or 1000 times off) is an error, never a
// guess.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/presentation/utils/investment_amount_input.dart';

InvestmentAmountInput _parse(String text, {String currency = 'INR'}) =>
    InvestmentAmountInput.parse(text, currencyCode: currency);

void main() {
  group('blank', () {
    test('empty and spaces mean no amount and no problem', () {
      for (final text in ['', '  ', ' \t ']) {
        final input = _parse(text);

        expect(input.isBlank, isTrue, reason: '"$text"');
        expect(input.amount, isNull, reason: '"$text"');
        expect(input.problem, isNull, reason: '"$text"');
      }
    });
  });

  group('valid amounts', () {
    test('plain, Indian and Western grouping read to the paisa', () {
      expect(_parse('100000').amount, 100000.0);
      expect(_parse('1,00,000').amount, 100000.0);
      expect(_parse('1,50,000').amount, 150000.0);
      expect(_parse('100,000', currency: 'USD').amount, 100000.0);
      expect(_parse('1500.50').amount, 1500.5);
    });

    test('a comma before two digits is the decimal mark: "1,50" is 1.50', () {
      // The readout under the field (Rs 1.5) is what tells the user.
      final input = _parse('1,50');

      expect(input.amount, 1.5);
      expect(input.problem, isNull);
      expect(input.isBlank, isFalse);
    });

    test('rounds to the currency minor unit', () {
      expect(_parse('1234.5678').amount, 1234.57);
      expect(_parse('1234.5644').amount, 1234.56);
      expect(_parse('1234.5', currency: 'JPY').amount, 1235.0);
    });

    test('the largest accepted amount has 15 digits', () {
      final input = _parse('999999999999999');

      expect(input.amount, 999999999999999.0);
      expect(input.problem, isNull);
    });

    test('European writing: 1.500,50 is 1500.50 in EUR', () {
      expect(_parse('1.500,50', currency: 'EUR').amount, 1500.5);
      expect(_parse('1.500', currency: 'EUR').amount, 1500.0);
    });
  });

  group('problems', () {
    test('zero, however written, is not above 0', () {
      for (final text in ['0', '0.00', '000', '0,00']) {
        final input = _parse(text);

        expect(input.problem, AmountInputProblem.notPositive, reason: text);
        expect(input.amount, isNull, reason: text);
        expect(input.isBlank, isFalse, reason: text);
      }
    });

    test('an amount that rounds to zero is not above 0', () {
      expect(_parse('0.0001').problem, AmountInputProblem.notPositive);
      expect(
        _parse('0.4', currency: 'JPY').problem,
        AmountInputProblem.notPositive,
      );
    });

    test('a minus sign is invalid, not silently dropped', () {
      for (final text in ['-5', '-0', '--5', '5-']) {
        expect(_parse(text).problem, AmountInputProblem.invalid, reason: text);
        expect(_parse(text).amount, isNull, reason: text);
      }
    });

    test('separators that fit no reading are invalid', () {
      expect(_parse('1,5000').problem, AmountInputProblem.invalid);
      expect(_parse('1,50,00').problem, AmountInputProblem.invalid);
      expect(_parse('abc').problem, AmountInputProblem.invalid);
      expect(_parse('.').problem, AmountInputProblem.invalid);
    });

    test(
      'a mark that could be grouping or decimal is invalid, not guessed',
      () {
        // de_DE writes 1,500 with a decimal comma: 1.5 or 1500? Ask the user.
        expect(
          _parse('1,500', currency: 'EUR').problem,
          AmountInputProblem.invalid,
        );
        // en_US: 1.500 is 1.5 or 1500.
        expect(
          _parse('1.500', currency: 'USD').problem,
          AmountInputProblem.invalid,
        );
      },
    );

    test('16 digits and more are too large', () {
      for (final text in [
        '1000000000000000',
        '9999999999999999',
        '1,00,00,00,00,00,00,000',
      ]) {
        final input = _parse(text);

        expect(input.problem, AmountInputProblem.tooLarge, reason: text);
        expect(input.amount, isNull, reason: text);
      }
    });

    test('an amount that rounds up to 16 digits is too large', () {
      // 999999999999999.5 JPY has no minor unit and rounds up to 1e15.
      expect(
        _parse('999999999999999.5', currency: 'JPY').problem,
        AmountInputProblem.tooLarge,
      );
    });
  });
}
