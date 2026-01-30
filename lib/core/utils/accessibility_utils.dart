import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Utility class for accessibility helpers
class AccessibilityUtils {
  /// Formats currency for screen readers
  static String formatCurrencyForScreenReader(double amount, String symbol) {
    final formatter = NumberFormat.decimalPattern();
    final formattedAmount = formatter.format(amount.abs());
    final sign = amount < 0 ? 'negative' : '';
    return '$sign $formattedAmount ${_currencyName(symbol)}';
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
    return DateFormat('MMMM d, y').format(date);
  }

  /// Creates a semantic label for investment cards
  static String investmentCardLabel({
    required String name,
    required String type,
    required double currentValue,
    required double? returnPercent,
    required String currencySymbol,
    required bool isClosed,
    DateTime? maturityDate,
  }) {
    final status = isClosed ? 'Closed investment' : 'Open investment';
    final value = formatCurrencyForScreenReader(currentValue, currencySymbol);
    final returns = returnPercent != null
        ? 'Returns: ${formatPercentageForScreenReader(returnPercent)}'
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

    final mainLabel =
        '$status: $name, Type: $type, Current value: $value. $returns';
    return maturityInfo.isNotEmpty ? '$mainLabel. $maturityInfo' : mainLabel;
  }

  /// Creates a semantic label for transaction/cash flow items
  static String transactionLabel({
    required String type,
    required double amount,
    required DateTime date,
    required String currencySymbol,
  }) {
    final formattedDate = formatDateForScreenReader(date);
    final formattedAmount = formatCurrencyForScreenReader(
      amount,
      currencySymbol,
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
