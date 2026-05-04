/// Currency Badge Widget
///
/// Displays a currency code badge with optional exchange rate information.
/// Used for multi-currency compliance (Rule 21) to show:
/// - Original currency when different from base currency
/// - Exchange rate transparency
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';

/// Currency badge showing currency code and optional exchange rate
class CurrencyBadge extends StatelessWidget {
  /// The currency code (e.g., 'USD', 'EUR')
  final String currencyCode;

  /// Optional exchange rate to display (e.g., 1 USD = 83.12 INR)
  final double? exchangeRate;

  /// Target currency for exchange rate display (e.g., 'INR')
  final String? targetCurrency;

  /// Whether to show compact format (e.g., "USD" vs "USD | 1 = ₹83.12")
  final bool compact;

  const CurrencyBadge({
    super.key,
    required this.currencyCode,
    this.exchangeRate,
    this.targetCurrency,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = getCurrencySymbol(currencyCode);
    final targetSymbol = targetCurrency != null ? getCurrencySymbol(targetCurrency!) : '';

    // Compact mode: just show currency code
    if (compact || exchangeRate == null || targetCurrency == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primaryDark.withValues(alpha: 0.2)
              : AppColors.primaryLight.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isDark
                ? AppColors.primaryDark.withValues(alpha: 0.3)
                : AppColors.primaryLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          currencyCode,
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
          ),
        ),
      );
    }

    // Full mode: show currency code + exchange rate
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.neutral800Dark.withValues(alpha: 0.5)
            : AppColors.neutral100Light.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? AppColors.neutral700Dark.withValues(alpha: 0.5)
              : AppColors.neutral300Light.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Currency code
          Text(
            currencyCode,
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.primaryDark
                  : AppColors.primaryLight,
            ),
          ),
          
          // Separator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '|',
              style: AppTypography.caption.copyWith(
                fontSize: 10,
                color: isDark
                    ? AppColors.neutral500Dark
                    : AppColors.neutral400Light,
              ),
            ),
          ),
          
          // Exchange rate
          Text(
            '1 $symbol = $targetSymbol${exchangeRate!.toStringAsFixed(2)}',
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral600Light,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact currency badge for use in tight spaces
class CompactCurrencyBadge extends StatelessWidget {
  final String currencyCode;

  const CompactCurrencyBadge({
    super.key,
    required this.currencyCode,
  });

  @override
  Widget build(BuildContext context) {
    return CurrencyBadge(
      currencyCode: currencyCode,
      compact: true,
    );
  }
}
