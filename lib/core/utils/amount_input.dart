import 'package:flutter/services.dart';

/// Parses an amount typed by the user. Grouping commas ("75,000",
/// "1,25,000") and spaces are ignored. Null when the text is not a finite,
/// non-negative number, so callers can show an error instead of silently
/// using another value.
double? parseAmountInput(String text) {
  final cleaned = text.replaceAll(RegExp(r'[,\s]'), '');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || !value.isFinite || value < 0) return null;
  return value;
}

/// Lets through digits, a decimal point and grouping commas.
final amountInputFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
];

/// [value] as an amount field's starting text: whole amounts without
/// ".0", others exactly, so saving it unchanged stores the same amount.
String amountInputText(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';
