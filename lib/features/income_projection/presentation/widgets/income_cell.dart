/// Income Cell Widget
///
/// Displays a single cell in the income calendar grid:
/// - Color-coded by status (Received, Expected, Overdue, Dismissed)
/// - Shows amount (compact format)
/// - Tappable to show details
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';
import 'package:inv_tracker/features/security/presentation/widgets/privacy_protection_wrapper.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class IncomeCell extends ConsumerWidget {
  final ExpectedCashFlowEntity? expected;
  final bool isDark;
  final VoidCallback? onTap;

  const IncomeCell({
    super.key,
    required this.expected,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(currencyLocaleProvider);
    final currencySymbol = ref.watch(currencySymbolProvider);
    final baseCurrency = ref.watch(currencyCodeProvider);
    if (expected == null) {
      // Empty cell
      return Container(
        width: 100,
        height: 80,
        decoration: BoxDecoration(
          color: isDark ? AppColors.neutral900Dark : Colors.white,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
            ),
            right: BorderSide(
              color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
            ),
          ),
        ),
      );
    }

    final status = expected!.status;
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 80,
        padding: EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
            ),
            right: BorderSide(
              color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
            ),
            left: BorderSide(
              color: statusColor,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(
                  statusIcon,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildConvertedAmount(ref, expected!, baseCurrency, currencySymbol, locale, statusColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _getStatusDisplayName(context, status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.caption.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral600Light,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(ExpectedCashFlowStatus status) {
    switch (status) {
      case ExpectedCashFlowStatus.received:
        return AppColors.successLight;
      case ExpectedCashFlowStatus.upcoming:
        return AppColors.accentLight;
      case ExpectedCashFlowStatus.dueSoon:
        return AppColors.warningDark;
      case ExpectedCashFlowStatus.gracePeriod:
        return AppColors.warningLight;
      case ExpectedCashFlowStatus.overdue:
        return AppColors.errorLight;
      case ExpectedCashFlowStatus.dismissed:
        return isDark ? AppColors.neutral600Dark : AppColors.neutral400Light;
    }
  }

  IconData _getStatusIcon(ExpectedCashFlowStatus status) {
    switch (status) {
      case ExpectedCashFlowStatus.received:
        return Icons.check_circle_rounded;
      case ExpectedCashFlowStatus.upcoming:
        return Icons.schedule_rounded;
      case ExpectedCashFlowStatus.dueSoon:
        return Icons.pending_rounded;
      case ExpectedCashFlowStatus.gracePeriod:
        return Icons.timelapse_rounded;
      case ExpectedCashFlowStatus.overdue:
        return Icons.warning_rounded;
      case ExpectedCashFlowStatus.dismissed:
        return Icons.cancel_rounded;
    }
  }

  /// Build currency-converted amount display (Rule 21 compliant)
  Widget _buildConvertedAmount(
    WidgetRef ref,
    ExpectedCashFlowEntity expected,
    String baseCurrency,
    String currencySymbol,
    String locale,
    Color statusColor,
  ) {
    // Check if conversion is needed
    if (expected.currency == baseCurrency) {
      // Same currency - display directly
      return PrivacyProtectionWrapper(
        child: Text(
          formatCompactCurrency(
            expected.expectedAmount,
            symbol: currencySymbol,
            locale: locale,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      );
    }

    // Different currency - convert before display
    final conversionService = ref.watch(currencyConversionServiceProvider);

    // Handle null service (unauthenticated user)
    if (conversionService == null) {
      return PrivacyProtectionWrapper(
        child: Text(
          formatCompactCurrency(
            expected.expectedAmount,
            symbol: currencySymbol,
            locale: locale,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.small.copyWith(
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      );
    }

    return FutureBuilder<double>(
      future: conversionService.convert(
        amount: expected.expectedAmount,
        from: expected.currency,
        to: baseCurrency,
        date: expected.expectedDate,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          // Loading - show compact placeholder
          return Text(
            '...',
            maxLines: 1,
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          );
        }

        final convertedAmount = snapshot.data!;
        return PrivacyProtectionWrapper(
          child: Text(
            formatCompactCurrency(
              convertedAmount,
              symbol: currencySymbol,
              locale: locale,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.small.copyWith(
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        );
      },
    );
  }
}

/// Helper to get localized display names for status
String _getStatusDisplayName(BuildContext context, ExpectedCashFlowStatus status) {
  final l10n = AppLocalizations.of(context);
  switch (status) {
    case ExpectedCashFlowStatus.upcoming:
      return l10n.incomeStatusUpcoming;
    case ExpectedCashFlowStatus.dueSoon:
      return l10n.incomeStatusDueSoon;
    case ExpectedCashFlowStatus.gracePeriod:
      return l10n.incomeStatusGracePeriod;
    case ExpectedCashFlowStatus.overdue:
      return l10n.incomeStatusOverdue;
    case ExpectedCashFlowStatus.received:
      return l10n.incomeStatusReceived;
    case ExpectedCashFlowStatus.dismissed:
      return l10n.incomeStatusDismissed;
  }
}
