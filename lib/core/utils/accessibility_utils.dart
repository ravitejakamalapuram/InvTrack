import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';

/// Utility class for accessibility helpers
class AccessibilityUtils {
  // OPTIMIZATION: Cache formatters to avoid expensive parsing on every call.
  // We check Intl.defaultLocale to ensure we respect dynamic language changes.
  static String? _lastLocale;
  static NumberFormat? _cachedCurrencyFormatter;
  static DateFormat? _cachedDateFormatter;

  static void _checkLocale() {
    final currentLocale = Intl.defaultLocale;
    if (_lastLocale != currentLocale) {
      _lastLocale = currentLocale;
      _cachedCurrencyFormatter = null;
      _cachedDateFormatter = null;
    }
  }

  static NumberFormat get _currencyFormatter {
    _checkLocale();
    return _cachedCurrencyFormatter ??= NumberFormat.decimalPattern();
  }

  static DateFormat get _dateFormatter {
    _checkLocale();
    return _cachedDateFormatter ??= DateFormat('MMMM d, y');
  }

  static final NumberFormat _indianNumberFormatter =
      NumberFormat.decimalPattern('en_IN')..maximumFractionDigits = 2;

  static const Map<String, String> _indianUnitNames = {
    'L': 'lakh',
    'Cr': 'crore',
  };

  /// Formats currency for screen readers.
  ///
  /// [locale] is the currency's number locale ([currencyLocaleProvider]).
  /// For en_IN the amount is read as on screen, with the same rounding as the
  /// compact format: 10505000 → '1.05 crore rupees', 99999 → '99,999 rupees'.
  static String formatCurrencyForScreenReader(
    double amount,
    String symbol, {
    required String locale,
  }) {
    final String formattedAmount;
    final bool isZero;
    if (locale == 'en_IN') {
      final parts = indianCompactParts(amount.abs());
      final number = _indianNumberFormatter.format(parts.value);
      final unit = _indianUnitNames[parts.unit];
      formattedAmount = unit == null ? number : '$number $unit';
      isZero = parts.value == 0;
    } else {
      formattedAmount = _currencyFormatter.format(amount.abs());
      isZero = amount == 0;
    }
    final sign = amount < 0 && !isZero ? 'negative ' : '';
    return '$sign$formattedAmount ${_currencyName(symbol)}';
  }

  /// Gets full currency name from symbol
  static String _currencyName(String symbol) {
    switch (symbol) {
      case '₹':
        return 'rupees';
      case '\$':
        return 'dollars';
      case '€':
        return 'euros';
      case '£':
        return 'pounds';
      default:
        return symbol;
    }
  }

  /// Formats percentage for screen readers
  static String formatPercentageForScreenReader(double? percentage) {
    if (percentage == null || percentage.isNaN || percentage.isInfinite) {
      return 'not available';
    }
    final sign = percentage >= 0 ? 'positive' : 'negative';
    return '$sign ${percentage.abs().toStringAsFixed(1)} percent';
  }

  /// Formats date for screen readers
  static String formatDateForScreenReader(DateTime date) {
    return _dateFormatter.format(date);
  }

  /// Creates a semantic label for investment cards.
  ///
  /// [returnStatus] (e.g. "Awaiting first payout") replaces [returnPercent]
  /// when the return cannot be calculated yet. [returnIsApproximate] reads
  /// [returnPercent] as approximate.
  static String investmentCardLabel({
    required String name,
    required String type,
    required double currentValue,
    required double? returnPercent,
    required String currencySymbol,
    required String currencyLocale,
    required bool isClosed,
    String? returnStatus,
    bool returnIsApproximate = false,
    DateTime? maturityDate,
    double? totalInvested,
    DateTime? lastActivityDate,
    bool shouldMask = false,
  }) {
    final status = isClosed ? 'Closed investment' : 'Open investment';
    final value = shouldMask
        ? 'Hidden amount'
        : formatCurrencyForScreenReader(
            currentValue,
            currencySymbol,
            locale: currencyLocale,
          );
    final invested = totalInvested != null && totalInvested > 0
        ? 'Invested: ${shouldMask ? "Hidden amount" : formatCurrencyForScreenReader(totalInvested, currencySymbol, locale: currencyLocale)}'
        : '';
    final approx = returnIsApproximate ? 'approximately ' : '';
    final returns = returnStatus != null
        ? 'Returns: $returnStatus'
        : returnPercent != null
        ? 'Returns: ${shouldMask ? "Hidden percentage" : '$approx${formatPercentageForScreenReader(returnPercent)}'}'
        : '';
    final lastActivity = lastActivityDate != null
        ? 'Last activity: ${formatDateForScreenReader(lastActivityDate)}'
        : '';

    String maturityInfo = '';
    if (maturityDate != null && !isClosed) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final maturity = DateTime(
        maturityDate.year,
        maturityDate.month,
        maturityDate.day,
      );
      final daysUntilMaturity = maturity.difference(today).inDays;

      if (daysUntilMaturity < 0) {
        maturityInfo = 'Matured';
      } else if (daysUntilMaturity == 0) {
        maturityInfo = 'Matures today';
      } else if (daysUntilMaturity <= 30) {
        maturityInfo = 'Matures in $daysUntilMaturity days';
      }
    }

    final mainLabel = [
      '$status: $name',
      'Type: $type',
      'Current value: $value',
      if (invested.isNotEmpty) invested,
      if (returns.isNotEmpty) returns,
      if (lastActivity.isNotEmpty) lastActivity,
    ].join('. ');

    return maturityInfo.isNotEmpty ? '$mainLabel. $maturityInfo' : mainLabel;
  }

  /// Creates a semantic label for transaction/cash flow items
  static String transactionLabel({
    required String type,
    required double amount,
    required DateTime date,
    required String currencySymbol,
    required String currencyLocale,
  }) {
    final formattedDate = formatDateForScreenReader(date);
    final formattedAmount = formatCurrencyForScreenReader(
      amount,
      currencySymbol,
      locale: currencyLocale,
    );
    return '$type of $formattedAmount on $formattedDate';
  }

  /// Creates a semantic label for stat cards
  static String statCardLabel({
    required String title,
    required String value,
    String? subtitle,
  }) {
    return subtitle != null ? '$title: $value. $subtitle' : '$title: $value';
  }
}

/// Semantic wrapper for interactive list items
class SemanticListItem extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;
  final bool isButton;

  const SemanticListItem({
    super.key,
    required this.label,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.isButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: isButton,
      enabled: true,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// Semantic wrapper for value displays
class SemanticValue extends StatelessWidget {
  final String label;
  final Widget child;
  final bool isHeader;

  const SemanticValue({
    super.key,
    required this.label,
    required this.child,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      header: isHeader,
      child: ExcludeSemantics(child: child),
    );
  }
}
