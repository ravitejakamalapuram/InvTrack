/// Investment card widget for the list view.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
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
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
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
    final currencyFormat = ref.watch(currencyFormatProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);

    // OPTIMIZATION: Use basic stats provider which skips expensive XIRR calculation
    // for the main card render. Only calculate XIRR where strictly needed.
    final statsAsync =
        investment.isArchived
            ? ref.watch(archivedInvestmentBasicStatsProvider(investment.id))
            : ref.watch(investmentBasicStatsProvider(investment.id));

    // Build accessibility label
    final semanticLabel = statsAsync.maybeWhen(
      data: (stats) => AccessibilityUtils.investmentCardLabel(
        name: investment.name,
        type: investment.type.displayName,
        currentValue: stats.netCashFlow,
        // XIRR might be 0.0 if not calculated, which is acceptable for semantic label
        // rather than blocking UI for calculation
        returnPercent: stats.xirr != 0 ? stats.xirr * 100 : null,
        currencySymbol: currencySymbol,
        isClosed: isClosed,
      ),
      orElse: () =>
          '${isClosed ? "Closed" : "Open"} investment: ${investment.name}, Type: ${investment.type.displayName}',
    );

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        semanticLabel: semanticLabel,
        // OPTIMIZATION: Disable blur on list items to avoid expensive BackdropFilter/saveLayer.
        // Since the background is solid, blurring it has no visual effect but high cost.
        blur: 0,
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
                    _TypeIcon(
                      typeColor: typeColor,
                      isClosed: isClosed,
                      icon: investment.type.icon,
                    ),
                    SizedBox(width: AppSpacing.md),
                    // Name and type
                    Expanded(
                      child: _InvestmentInfo(
                        investment: investment,
                        isDark: isDark,
                        typeColor: typeColor,
                        isClosed: isClosed,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm),
                    // Stats
                    _InvestmentValueColumn(
                      investmentId: investment.id,
                      isArchived: investment.isArchived,
                      isDark: isDark,
                      statsAsync: statsAsync,
                      currencyFormat: currencyFormat,
                      isPrivacyMode: isPrivacyMode,
                    ),
                  ],
                ),
              ),
              // Bottom info strip with stats
              _InvestmentBottomStrip(
                investment: investment,
                isDark: isDark,
                statsAsync: statsAsync,
                currencyFormat: currencyFormat,
                isPrivacyMode: isPrivacyMode,
              ),
            ],
          ),
        ),
    );
  }
}

/// Extracted widget for type icon to avoid rebuilds during selection toggling.
class _TypeIcon extends StatelessWidget {
  final Color typeColor;
  final bool isClosed;
  final IconData icon;

  const _TypeIcon({
    required this.typeColor,
    required this.isClosed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
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
          icon,
          color: Colors.white,
          size: AppSizes.iconMd,
        ),
      ),
    );
  }
}

/// Extracted widget for name and type info to avoid rebuilds during selection toggling.
class _InvestmentInfo extends StatelessWidget {
  final InvestmentEntity investment;
  final bool isDark;
  final Color typeColor;
  final bool isClosed;

  const _InvestmentInfo({
    required this.investment,
    required this.isDark,
    required this.typeColor,
    required this.isClosed,
  });

  @override
  Widget build(BuildContext context) {
    final maturityInfo = _getMaturityInfo();

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
            if (maturityInfo != null && !isClosed)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: maturityInfo.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      maturityInfo.icon,
                      size: 10,
                      color: maturityInfo.color,
                    ),
                    SizedBox(width: 3),
                    Text(
                      maturityInfo.label,
                      style: AppTypography.small.copyWith(
                        color: maturityInfo.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Returns maturity info if the investment has an upcoming maturity date
  _MaturityInfo? _getMaturityInfo() {
    final maturityDate = investment.maturityDate;
    if (maturityDate == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maturity = DateTime(
      maturityDate.year,
      maturityDate.month,
      maturityDate.day,
    );
    final daysUntilMaturity = maturity.difference(today).inDays;

    // Already matured
    if (daysUntilMaturity < 0) {
      return _MaturityInfo(
        label: 'MATURED',
        color: AppColors.successLight,
        icon: Icons.check_circle_rounded,
      );
    }

    // Maturing today
    if (daysUntilMaturity == 0) {
      return _MaturityInfo(
        label: 'MATURES TODAY',
        color: AppColors.warningLight,
        icon: Icons.schedule_rounded,
      );
    }

    // Within 7 days - urgent
    if (daysUntilMaturity <= 7) {
      return _MaturityInfo(
        label: '${daysUntilMaturity}d TO MATURITY',
        color: AppColors.warningLight,
        icon: Icons.schedule_rounded,
      );
    }

    // Within 30 days - upcoming
    if (daysUntilMaturity <= 30) {
      return _MaturityInfo(
        label: '${daysUntilMaturity}d TO MATURITY',
        color: AppColors.accentLight,
        icon: Icons.event_rounded,
      );
    }

    return null;
  }
}

/// Helper class for maturity badge info
class _MaturityInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _MaturityInfo({
    required this.label,
    required this.color,
    required this.icon,
  });
}

/// Displays the investment value and return percentage.
class _InvestmentValueColumn extends ConsumerWidget {
  final String investmentId;
  final bool isArchived;
  final bool isDark;
  final AsyncValue<InvestmentStats> statsAsync;
  final NumberFormat currencyFormat;
  final bool isPrivacyMode;

  const _InvestmentValueColumn({
    required this.investmentId,
    required this.isArchived,
    required this.isDark,
    required this.statsAsync,
    required this.currencyFormat,
    required this.isPrivacyMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // OPTIMIZATION: Removed redundant provider watches. Data is passed from parent.
    // Also allows parent to manage rebuilds more effectively.

    // Watch XIRR separately (slow) - this must still be watched here as it's separate
    final xirrAsync =
        isArchived
            ? ref.watch(archivedInvestmentXirrProvider(investmentId))
            : ref.watch(investmentXirrProvider(investmentId));

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

        final valueStyle = AppTypography.bodyLarge.copyWith(
          fontWeight: FontWeight.w600,
          color: plColor,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Net Position (cash in - cash out)
            isPrivacyMode
                ? MaskedAmountText(
                    text:
                        '${isPositive ? '+' : '-'}${currencyFormat.formatCompact(stats.netCashFlow.abs())}',
                    style: valueStyle,
                  )
                : CompactAmountText(
                    amount: stats.netCashFlow.abs(),
                    compactText: currencyFormat.formatCompact(
                      stats.netCashFlow.abs(),
                    ),
                    currencySymbol: currencyFormat.currencySymbol,
                    prefix: isPositive ? '+' : '-',
                    style: valueStyle,
                  ),
            SizedBox(height: AppSpacing.xxs),

            // XIRR - only show if valid and loaded
            xirrAsync.when(
              data: (xirr) {
                final xirrColor = xirr >= 0
                    ? AppColors.graphEmerald
                    : AppColors.errorLight;
                final xirrFormatted = formatXirr(xirr);

                if (xirrFormatted == null) return const SizedBox.shrink();

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isPrivacyMode ? 0.0 : 1.0,
                  child: Container(
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
                );
              },
              loading: () => SizedBox(
                height: 14,
                width: 40,
                // Optional: show skeleton or nothing while loading XIRR
                // Showing nothing avoids UI jumping if it loads fast
                child: const SizedBox.shrink(),
              ),
              error: (_, _) => const SizedBox.shrink(),
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
/// OPTIMIZATION: Converted to StatelessWidget to avoid unnecessary provider listeners.
class _InvestmentBottomStrip extends StatelessWidget {
  final InvestmentEntity investment;
  final bool isDark;
  final AsyncValue<InvestmentStats> statsAsync;
  final NumberFormat currencyFormat;
  final bool isPrivacyMode;

  const _InvestmentBottomStrip({
    required this.investment,
    required this.isDark,
    required this.statsAsync,
    required this.currencyFormat,
    required this.isPrivacyMode,
  });

  @override
  Widget build(BuildContext context) {
    // OPTIMIZATION: Using passed data instead of watching providers again.
    // This reduces listener count by ~3 per list item.

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

          final subtleTextStyle = AppTypography.small.copyWith(
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
          );

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
                style: subtleTextStyle,
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
                style: subtleTextStyle,
              ),
              Spacer(),
              // Total invested
              if (stats.totalInvested > 0) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Invested: ',
                      style: subtleTextStyle.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    isPrivacyMode
                        ? MaskedAmountText(
                            text: currencyFormat.formatCompact(
                              stats.totalInvested,
                            ),
                            style: subtleTextStyle.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          )
                        : CompactAmountText(
                            amount: stats.totalInvested,
                            compactText: currencyFormat.formatCompact(
                              stats.totalInvested,
                            ),
                            currencySymbol: currencyFormat.currencySymbol,
                            style: subtleTextStyle.copyWith(
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
