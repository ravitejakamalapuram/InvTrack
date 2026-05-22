/// Income Cell Widget
///
/// Displays a single cell in the income calendar grid:
/// - Color-coded by status (Received, Expected, Overdue, Dismissed)
/// - Shows amount (compact format)
/// - Tappable to show details
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/expected_cash_flow_entity.dart';

class IncomeCell extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                  child: Text(
                    formatCompactCurrency(
                      expected!.expectedAmount,
                      symbol: expected!.currency,
                      locale: 'en_IN', // TODO: Get from settings
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.small.copyWith(
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              status.displayName,
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
}

/// Extension to get display names for status
extension ExpectedCashFlowStatusDisplay on ExpectedCashFlowStatus {
  String get displayName {
    switch (this) {
      case ExpectedCashFlowStatus.upcoming:
        return 'Upcoming';
      case ExpectedCashFlowStatus.dueSoon:
        return 'Due Soon';
      case ExpectedCashFlowStatus.gracePeriod:
        return 'Grace Period';
      case ExpectedCashFlowStatus.overdue:
        return 'Overdue';
      case ExpectedCashFlowStatus.received:
        return 'Received';
      case ExpectedCashFlowStatus.dismissed:
        return 'Dismissed';
    }
  }
}
