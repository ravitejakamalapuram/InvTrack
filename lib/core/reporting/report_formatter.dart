/// The one place a [MetricValue] becomes text, for the screen, CSV and PDF.
/// Unknown is an em dash, never "0" or "0%". With [privacy] on, money is a
/// mask, so nothing downstream can leak an amount (money rule 8).
library;

import 'package:inv_tracker/core/reporting/metric_value.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';

class ReportFormatter {
  static const unknown = '—';
  static const masked = '••••••';

  final String symbol;
  final String locale;
  final bool privacy;

  const ReportFormatter({
    required this.symbol,
    required this.locale,
    this.privacy = false,
  });

  String money(MetricValue value) {
    final v = value.valueOrNull;
    if (v == null) return unknown;
    if (privacy) return masked;
    return formatCurrency(v, symbol, locale, decimalDigits: 2);
  }

  /// A percentage with one decimal; [value] is already in percent (20 = 20%).
  String percent(MetricValue value, {bool signed = false}) {
    final v = value.valueOrNull;
    if (v == null) return unknown;
    final sign = signed && v > 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(1)}%';
  }
}
