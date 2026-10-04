import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

    // en_IN compact amounts use lakh (L) and crore (Cr) with up to 2 decimals.
    // Below one lakh the full amount is shown; intl's own en_IN compact format
    // printed '₹1L' for 99,999 and '₹1.5K' for 1,500 (A18).
    group('formatCompactCurrency (Indian)', () {
      test('formats crores correctly', () {
        expect(
          formatCompactCurrency(10000000, symbol: '₹', locale: 'en_IN'),
          '₹1 Cr',
        );
        expect(
          formatCompactCurrency(15000000, symbol: '₹', locale: 'en_IN'),
          '₹1.5 Cr',
        );
        expect(
          formatCompactCurrency(25600000, symbol: '₹', locale: 'en_IN'),
          '₹2.56 Cr',
        );
      });

      test('formats lakhs correctly', () {
        expect(
          formatCompactCurrency(100000, symbol: '₹', locale: 'en_IN'),
          '₹1 L',
        );
        expect(
          formatCompactCurrency(150000, symbol: '₹', locale: 'en_IN'),
          '₹1.5 L',
        );
        expect(
          formatCompactCurrency(256000, symbol: '₹', locale: 'en_IN'),
          '₹2.56 L',
        );
      });

      test('shows amounts below one lakh in full', () {
        expect(
          formatCompactCurrency(1000, symbol: '₹', locale: 'en_IN'),
          '₹1,000',
        );
        expect(
          formatCompactCurrency(1500, symbol: '₹', locale: 'en_IN'),
          '₹1,500',
        );
        expect(
          formatCompactCurrency(2600, symbol: '₹', locale: 'en_IN'),
          '₹2,600',
        );
      });

      test('formats small amounts without suffix', () {
        expect(
          formatCompactCurrency(500, symbol: '₹', locale: 'en_IN'),
          '₹500',
        );
        expect(
          formatCompactCurrency(999, symbol: '₹', locale: 'en_IN'),
          '₹999',
        );
      });

      test('handles negative amounts', () {
        expect(
          formatCompactCurrency(-100000, symbol: '₹', locale: 'en_IN'),
          '-₹1 L',
        );
        expect(
          formatCompactCurrency(-1500, symbol: '₹', locale: 'en_IN'),
          '-₹1,500',
        );
      });

      test('uses custom symbol', () {
        expect(
          formatCompactCurrency(100000, symbol: '\$', locale: 'en_IN'),
          '\$1 L',
        );
      });

      test('rounds to 2 decimals', () {
        expect(
          formatCompactCurrency(156789, symbol: '₹', locale: 'en_IN'),
          '₹1.57 L',
        );
        expect(
          formatCompactCurrency(123456789.9, symbol: '₹', locale: 'en_IN'),
          '₹12.35 Cr',
        );
      });

      group('boundaries', () {
        String inr(double v) =>
            formatCompactCurrency(v, symbol: '₹', locale: 'en_IN');

        test('99,999 stays below the lakh', () {
          expect(inr(99999), '₹99,999');
        });

        test('an amount that rounds to one lakh is shown as 1 L', () {
          expect(inr(99999.996), '₹1 L');
        });

        test('9,994,999 is 99.95 L, not 0.999 Cr', () {
          expect(inr(9994999), '₹99.95 L');
        });

        test('100.00 L is promoted to 1 Cr', () {
          expect(inr(9999999), '₹1 Cr');
          expect(inr(9999500), '₹1 Cr');
        });

        test('1e10 is 1,000 Cr, not 1KCr', () {
          expect(inr(1e10), '₹1,000 Cr');
        });

        test('negatives keep the sign once', () {
          expect(inr(-9994999), '-₹99.95 L');
          expect(inr(-1e10), '-₹1,000 Cr');
          expect(inr(-99999), '-₹99,999');
        });

        test('a value that rounds to zero has no minus sign', () {
          expect(inr(-0.001), '₹0');
        });

        test('formatSmartCurrency and formatCompact use the same rules', () {
          expect(
            formatSmartCurrency(9994999, symbol: '₹', locale: 'en_IN'),
            '₹99.95 L',
          );
          final format = NumberFormat.currency(
            locale: 'en_IN',
            symbol: '₹',
            decimalDigits: 0,
          );
          expect(format.formatCompact(1e10), '₹1,000 Cr');
          expect(format.formatSmart(9994999), '₹99.95 L');
          expect(format.formatCompactShort(9994999), '₹99.9 L');
        });
      });
    });

    group('formatCompactCurrency (other currencies)', () {
      test('uses K, M and B with up to 2 decimals', () {
        expect(
          formatCompactCurrency(1234567, symbol: '\$', locale: 'en_US'),
          '\$1.23M',
        );
        expect(
          formatCompactCurrency(123456789, symbol: '\$', locale: 'en_US'),
          '\$123.46M',
        );
        expect(
          formatCompactCurrency(-25000, symbol: '\$', locale: 'en_US'),
          '-\$25K',
        );
        expect(
          formatCompactCurrency(2500000000, symbol: '\$', locale: 'en_US'),
          '\$2.5B',
        );
        expect(
          formatCompactCurrency(999, symbol: '\$', locale: 'en_US'),
          '\$999',
        );
      });

      test('promotes 1,000K to 1M', () {
        expect(
          formatCompactCurrency(999999.999, symbol: '\$', locale: 'en_US'),
          '\$1M',
        );
        expect(
          formatCompactCurrency(999.999, symbol: '\$', locale: 'en_US'),
          '\$1K',
        );
      });

      test("keeps the currency's separators and symbol position", () {
        expect(
          formatCompactCurrency(1234567, symbol: '€', locale: 'de_DE'),
          '1,23M €',
        );
        expect(
          formatCompactCurrency(-25000, symbol: 'KSh', locale: 'sw_KE'),
          '-KSh 25K',
        );
        expect(
          formatCompactCurrency(1234567, symbol: '¥', locale: 'ja_JP'),
          '¥1.23M',
        );
      });
    });

    // Every supported currency must print Latin digits and no words from
    // another script in the English UI (A18: BDT and EGP printed Bengali and
    // Arabic-Indic digits; AED, LKR and PKR compact amounts had Arabic,
    // Sinhala and Urdu words).
    group('every supported currency', () {
      final letter = RegExp(r'\p{L}', unicode: true);
      final anyDigit = RegExp(r'\p{Nd}', unicode: true);
      final suffix = RegExp(r'(?<=\d)(K|M|B|T| L| Cr)');

      void expectLatin(String code, String text) {
        final symbol = getCurrencySymbol(code);
        final rest = text.replaceFirst(symbol, '').replaceFirst(suffix, '');
        expect(
          rest.contains(letter),
          isFalse,
          reason: '$code: "$text" has letters other than the symbol and suffix',
        );
        for (final m in anyDigit.allMatches(rest)) {
          expect(
            RegExp(r'[0-9]').hasMatch(m.group(0)!),
            isTrue,
            reason: '$code: "$text" has a non-Latin digit',
          );
        }
      }

      for (final code in getValidCurrencyCodes()) {
        test('$code uses Latin digits in full and compact amounts', () {
          final symbol = getCurrencySymbol(code);
          final locale = getCurrencyLocale(code);
          expectLatin(
            code,
            formatCurrency(-1234567.89, symbol, locale, decimalDigits: 2),
          );
          expectLatin(code, formatNumber(1234567, locale));
          for (final v in [
            -25000.0,
            99999.0,
            1234567.0,
            9994999.0,
            123456789.9,
            1e10,
          ]) {
            expectLatin(
              code,
              formatCompactCurrency(v, symbol: symbol, locale: locale),
            );
            expectLatin(
              code,
              formatSmartCurrency(v, symbol: symbol, locale: locale),
            );
          }
        });

        test('$code compact amounts never show 1,000 of a unit', () {
          final symbol = getCurrencySymbol(code);
          final locale = getCurrencyLocale(code);
          for (final v in [999.999, 999999.999, 999999999.999, 9999999.999]) {
            final text = formatCompactCurrency(
              v,
              symbol: symbol,
              locale: locale,
            );
            expect(
              text,
              isNot(matches(RegExp(r'1\D?000(K|M|B)|100 L'))),
              reason: '$code: $v gave "$text"',
            );
          }
        });
      }

      test('AED, BDT, EGP and LKR amounts use Latin digits', () {
        String full(String code) => formatCurrency(
          1234567,
          getCurrencySymbol(code),
          getCurrencyLocale(code),
        );
        String compact(String code) => formatCompactCurrency(
          1234567,
          symbol: getCurrencySymbol(code),
          locale: getCurrencyLocale(code),
        );

        expect(full('BDT'), '৳12,34,567');
        expect(compact('BDT'), '৳12.35 L');
        expect(full('EGP'), 'E£1,234,567');
        expect(compact('EGP'), 'E£1.23M');
        expect(compact('AED'), '‏1.23M د.إ');
        expect(compact('LKR'), 'Rs1.23M');
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
          locale: 'en_US',
          compactThreshold: 10000,
        );
        expect(result, '₹50K');
      });
    });
  });
}
