/// Investment card widget for the list view.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/accessibility_utils.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/utils/number_format_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

/// A card displaying an investment's summary information.
class InvestmentCard extends ConsumerWidget {
  final InvestmentEntity investment;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool?>? onCheckboxChanged;

  const InvestmentCard({
    super.key,
    required this.investment,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
    this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = investment.type.color;
    final isClosed = investment.status == InvestmentStatus.closed;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final statsAsync = ref.watch(investmentStatsProvider(investment.id));

    // Build accessibility label
    final semanticLabel = statsAsync.maybeWhen(
      data: (stats) => AccessibilityUtils.investmentCardLabel(
        name: investment.name,
        type: investment.type.displayName,
        currentValue: stats.netCashFlow,
        returnPercent: stats.hasData ? stats.xirr * 100 : null,
        currencySymbol: currencySymbol,
        isClosed: isClosed,
      ),
      orElse: () =>
          '${isClosed ? "Closed" : "Open"} investment: ${investment.name}, Type: ${investment.type.displayName}',
    );

    return Semantics(
      label: semanticLabel,
      button: true,
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: GlassCard(
          onTap: onTap,
          onLongPress: onLongPress,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    // Checkbox in selection mode
                    if (isSelectionMode) ...[
                      Checkbox(
                        value: isSelected,
                        onChanged: onCheckboxChanged,
                        activeColor: AppColors.primaryLight,
                      ),
                      SizedBox(width: AppSpacing.xs),
                    ],
                    // Icon with type icon
                    _buildTypeIcon(typeColor, isClosed),
                    SizedBox(width: AppSpacing.md),
                    // Name and type
                    Expanded(
                      child: _buildNameAndType(isDark, typeColor, isClosed),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    // Stats
                    _InvestmentValueColumn(
                      investmentId: investment.id,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              // Bottom info strip with stats
              _InvestmentBottomStrip(investment: investment, isDark: isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeIcon(Color typeColor, bool isClosed) {
    return Container(
      width: AppSizes.iconXl,
      height: AppSizes.iconXl,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isClosed
              ? [Colors.grey, Colors.grey.withValues(alpha: 0.7)]
              : [typeColor, typeColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSizes.radiusMd + 2),
        boxShadow: [
          BoxShadow(
            color: (isClosed ? Colors.grey : typeColor).withValues(alpha: 0.3),
            blurRadius: AppSpacing.xs,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          investment.type.icon,
          color: Colors.white,
          size: AppSizes.iconMd,
        ),
      ),
    );
  }

  Widget _buildNameAndType(bool isDark, Color typeColor, bool isClosed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          investment.name,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: AppSpacing.xxs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                investment.type.displayName,
                style: AppTypography.small.copyWith(
                  color: typeColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isClosed)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'CLOSED',
                  style: AppTypography.small.copyWith(
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Displays the investment value and return percentage.
class _InvestmentValueColumn extends ConsumerWidget {
  final String investmentId;
  final bool isDark;

  const _InvestmentValueColumn({
    required this.investmentId,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = ref.watch(currencyFormatProvider);
    final statsAsync = ref.watch(investmentStatsProvider(investmentId));

    return statsAsync.when(
      data: (stats) {
        if (!stats.hasData) {
          return Icon(
            Icons.chevron_right_rounded,
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral400Light,
          );
        }

        final isPositive = stats.netCashFlow >= 0;
        final plColor = isPositive
            ? AppColors.graphEmerald
            : AppColors.errorLight;
        final xirrColor = stats.xirr >= 0
            ? AppColors.graphEmerald
            : AppColors.errorLight;
        final xirrFormatted = formatXirr(stats.xirr);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Net Position (cash in - cash out)
            CompactAmountText(
              amount: stats.netCashFlow.abs(),
              compactText: currencyFormat.formatCompact(
                stats.netCashFlow.abs(),
              ),
              currencySymbol: currencyFormat.currencySymbol,
              prefix: isPositive ? '+' : '-',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: plColor,
              ),
            ),
            SizedBox(height: AppSpacing.xxs),
            // XIRR - only show if valid
            if (xirrFormatted != null)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: xirrColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$xirrFormatted IRR',
                  style: AppTypography.small.copyWith(
                    color: xirrColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        );
      },
      loading: () => SizedBox(
        width: AppSpacing.md,
        height: AppSpacing.md,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, s) => Icon(
        Icons.chevron_right_rounded,
        color: isDark ? AppColors.neutral400Dark : AppColors.neutral400Light,
      ),
    );
  }
}

/// Bottom strip showing investment stats.
class _InvestmentBottomStrip extends ConsumerWidget {
  final InvestmentEntity investment;
  final bool isDark;

  const _InvestmentBottomStrip({
    required this.investment,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencyFormat = ref.watch(currencyFormatProvider);
    final statsAsync = ref.watch(investmentStatsProvider(investment.id));

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(AppSizes.radiusXl),
          bottomRight: Radius.circular(AppSizes.radiusXl),
        ),
      ),
      child: statsAsync.when(
        data: (stats) {
          final lastActivityDate =
              stats.lastCashFlowDate ?? investment.createdAt;
          final cashFlowCount = stats.cashFlowCount;

          return Row(
            children: [
              // Last activity
              Icon(
                Icons.update_rounded,
                size: 12,
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
              SizedBox(width: 4),
              Text(
                AppDateUtils.formatRelative(lastActivityDate),
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              // Cash flow count
              Icon(
                Icons.receipt_long_rounded,
                size: 12,
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
              SizedBox(width: 4),
              Text(
                '$cashFlowCount ${cashFlowCount == 1 ? 'entry' : 'entries'}',
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
              ),
              Spacer(),
              // Total invested
              if (stats.totalInvested > 0) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Invested: ',
                      style: AppTypography.small.copyWith(
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral500Light,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    CompactAmountText(
                      amount: stats.totalInvested,
                      compactText: currencyFormat.formatCompact(
                        stats.totalInvested,
                      ),
                      currencySymbol: currencyFormat.currencySymbol,
                      style: AppTypography.small.copyWith(
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral500Light,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  'View Details',
                  style: AppTypography.small.copyWith(
                    color: AppColors.primaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
        },
        loading: () => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Loading...',
              style: AppTypography.small.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
          ],
        ),
        error: (e, s) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Added ${AppDateUtils.formatRelative(investment.createdAt)}',
              style: AppTypography.small.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            ),
            Text(
              'View Details',
              style: AppTypography.small.copyWith(
                color: AppColors.primaryLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
