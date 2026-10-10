// #936: a custom investment type is free text typed by the user. It is cleaned
// one way everywhere (form, notifier, import), and two labels are the same
// type when their lower-cased cleaned texts are equal.
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/custom_type_label.dart';

void main() {
  group('clean', () {
    test('trims and keeps the casing the user typed', () {
      expect(CustomTypeLabel.clean('  Art Prints '), 'Art Prints');
    });

    test('collapses every whitespace run to one space', () {
      expect(CustomTypeLabel.clean('Vintage   Cars'), 'Vintage Cars');
      expect(CustomTypeLabel.clean('Vintage\t\tCars'), 'Vintage Cars');
      expect(CustomTypeLabel.clean('Vintage\n\r\nCars'), 'Vintage Cars');
      // No-break space, ideographic space, line separator, next line.
      expect(
        CustomTypeLabel.clean('a\u00A0b\u3000c\u2028d\u0085e'),
        'a b c d e',
      );
    });

    test('drops zero-width characters', () {
      expect(
        CustomTypeLabel.clean('Art\u200B \u200CPri\u200Dnts\u2060\uFEFF'),
        'Art Prints',
      );
    });

    test('drops bidi control characters', () {
      expect(
        CustomTypeLabel.clean(
          '\u202EArt\u202C \u200EPrints\u200F\u2066\u2069\u061C',
        ),
        'Art Prints',
      );
    });

    test('drops other control characters', () {
      expect(
        CustomTypeLabel.clean('Art\u0000\u0007 Prints\u007F\u009F'),
        'Art Prints',
      );
    });

    test('is empty for null, blank and invisible-only input', () {
      expect(CustomTypeLabel.clean(null), '');
      expect(CustomTypeLabel.clean('   '), '');
      expect(CustomTypeLabel.clean('\u200B\u202E \t'), '');
    });

    test('is idempotent', () {
      const messy = ' \u200BArt \u00A0 Prints\t';
      final once = CustomTypeLabel.clean(messy);
      expect(CustomTypeLabel.clean(once), once);
    });
  });

  group('keyOf', () {
    test('case and spacing variants share one key', () {
      final keys = {
        for (final v in [
          'Art Prints',
          'art prints',
          ' ART   PRINTS ',
          'Art\u00A0Prints',
        ])
          CustomTypeLabel.keyOf(CustomTypeLabel.clean(v)),
      };
      expect(keys, {'art prints'});
    });

    test('different words are different keys', () {
      expect(
        CustomTypeLabel.keyOf('Art Prints') ==
            CustomTypeLabel.keyOf('Art Print'),
        isFalse,
      );
    });
  });

  group('length', () {
    test('the limit is 40', () {
      expect(CustomTypeLabel.maxLength, 40);
    });

    test('40 characters fit and 41 do not', () {
      expect(CustomTypeLabel.exceedsMaxLength('a' * 40), isFalse);
      expect(CustomTypeLabel.exceedsMaxLength('a' * 41), isTrue);
    });

    test('counts what the user sees (grapheme clusters), not code units', () {
      // "e" plus a combining acute accent is one visible character.
      expect(CustomTypeLabel.exceedsMaxLength('e\u0301' * 40), isFalse);
      expect(CustomTypeLabel.exceedsMaxLength('e\u0301' * 41), isTrue);
    });
  });

  test('an account holds at most 50 active custom types', () {
    expect(CustomTypeLabel.maxActiveDefinitions, 50);
  });
}
