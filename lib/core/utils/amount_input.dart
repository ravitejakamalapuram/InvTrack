import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Parses an amount typed by the user in [locale] (the amount's currency
/// locale, e.g. 'en_IN' or 'de_DE'). Spaces and grouping ("1,25,000",
/// "1.500.000") are ignored, and either mark is read as the decimal mark
/// where grouping cannot explain it ("1500,50" from a comma keyboard).
///
/// Null when the text is not a finite, non-negative number or its
/// separators fit neither reading ("1,5000", "1,50,00"), so callers show an
/// error instead of saving an amount 100 or 1000 times off.
double? parseAmountInput(String text, String locale) {
  final cleaned = text.replaceAll(RegExp(r'\s'), '');
  if (!RegExp(r'^[0-9.,]*[0-9][0-9.,]*$').hasMatch(cleaned)) return null;

  final commas = ','.allMatches(cleaned).length;
  final points = '.'.allMatches(cleaned).length;
  String? decimalMark;
  if (commas > 0 && points > 0) {
    // "1,500.50" or "1.500,50": the last mark is the decimal one.
    decimalMark = cleaned.lastIndexOf(',') > cleaned.lastIndexOf('.')
        ? ','
        : '.';
  } else if (commas + points == 1) {
    final mark = commas == 1 ? ',' : '.';
    final digitsAfter = cleaned.length - cleaned.indexOf(mark) - 1;
    if (mark == _localeDecimalMark(locale) ||
        digitsAfter == 1 ||
        digitsAfter == 2) {
      decimalMark = mark;
    } else if (digitsAfter != 3) {
      return null;
    }
  }

  var whole = cleaned;
  var fraction = '';
  if (decimalMark != null) {
    final at = cleaned.indexOf(decimalMark);
    if (at != cleaned.lastIndexOf(decimalMark)) return null;
    whole = cleaned.substring(0, at);
    fraction = cleaned.substring(at + 1);
  }
  final groups = whole.split(RegExp('[.,]'));
  if (groups.length > 1) {
    // First group 1–3 digits, last 3, Indian middle groups 2 ("1,50,000").
    final middleOk = groups
        .sublist(1, groups.length - 1)
        .every((g) => g.length == 2 || g.length == 3);
    if (groups.first.isEmpty ||
        groups.first.length > 3 ||
        groups.last.length != 3 ||
        !middleOk) {
      return null;
    }
  }

  final value = double.tryParse('${groups.join()}.${fraction}0');
  if (value == null || !value.isFinite) return null;
  return value;
}

/// Lets through digits, decimal marks and grouping separators.
final amountInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
];

/// [value] as an amount field's starting text in [locale]: whole amounts
/// without ".0", others exactly and with the locale's decimal mark, so
/// saving it unchanged stores the same amount.
String amountInputText(double value, String locale) =>
    value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : '$value'.replaceAll('.', _localeDecimalMark(locale));

/// ',' for locales that write 1.500,50 (de_DE, pt_BR …), otherwise '.'.
String _localeDecimalMark(String locale) {
  try {
    final mark = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
    return mark == ',' ? ',' : '.';
  } on ArgumentError {
    return '.';
  }
}
