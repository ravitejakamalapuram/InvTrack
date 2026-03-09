import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/utils/number_format_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';

/// Stats section widget for investment detail screen.
/// Displays net position, cash flow summary, XIRR/MOIC, and maturity info.
class InvestmentDetailStatsSection extends StatelessWidget {
  final InvestmentStats stats;
  final InvestmentEntity investment;
  final bool isDark;
  final NumberFormat currencyFormat;
  final bool isPrivacyMode;

  const InvestmentDetailStatsSection({
    super.key,
    required this.stats,
    required this.investment,
    required this.isDark,
    required this.currencyFormat,
    required this.isPrivacyMode,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = stats.netCashFlow >= 0;
    final xirrFormatted = formatXirr(stats.xirr) ?? '0.0%';
    final xirrIsPositive = stats.xirr >= 0;

    return Column(
      children: [
        // Net Position Hero Card
        _buildNetPositionCard(isPositive),
        const SizedBox(height: 10),
        // Cash Out and Cash In row
        _buildCashFlowSummaryCard(),
        const SizedBox(height: 10),
        // XIRR and MOIC row
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                label: 'XIRR',
                value: xirrFormatted,
                color: xirrIsPositive
                    ? AppColors.graphCyan
                    : AppColors.errorLight,
                isDark: isDark,
                isPrivacyMode: isPrivacyMode,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStatCard(
                label: 'MOIC',
                value: formatMultiplier(stats.moic),
                color: AppColors.graphPurple,
                isDark: isDark,
                subtitle: stats.durationFormatted,
                isPrivacyMode: isPrivacyMode,
              ),
            ),
          ],
        ),
        // Maturity date card (if applicable)
        if (investment.hasMaturityDate) ...[
          const SizedBox(height: 10),
          _MaturityCard(maturityDate: investment.maturityDate!, isDark: isDark),
        ],
      ],
    );
  }

  Widget _buildNetPositionCard(bool isPositive) {
    final netPositionStyle = AppTypography.h2.copyWith(
      color: isDark ? Colors.white : AppColors.neutral900Light,
      fontWeight: FontWeight.w700,
    );

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  (isPositive ? AppColors.successLight : AppColors.errorLight)
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isPositive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 28,
              color: isPositive ? AppColors.successLight : AppColors.errorLight,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net Position',
                  style: AppTypography.small.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
                ),
                const SizedBox(height: 4),
                isPrivacyMode
                    ? MaskedAmountText(
                        text: currencyFormat.formatSmart(stats.netCashFlow),
                        style: netPositionStyle,
                      )
                    : CompactAmountText(
                        amount: stats.netCashFlow,
                        compactText: currencyFormat.formatSmart(
                          stats.netCashFlow,
                        ),
                        currencySymbol: currencyFormat.currencySymbol,
                        style: netPositionStyle,
                      ),
              ],
            ),
          ),
          // Return percentage badge
          _buildReturnBadge(isPositive),
        ],
      ),
    );
  }

  Widget _buildReturnBadge(bool isPositive) {
    if (isPrivacyMode) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const MaskedAmountText(text: '••••'),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isPositive ? AppColors.successLight : AppColors.errorLight)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${stats.absoluteReturn >= 0 ? '+' : ''}${stats.absoluteReturn.toStringAsFixed(1)}%',
        style: AppTypography.bodyMedium.copyWith(
          color: isPositive ? AppColors.successLight : AppColors.errorLight,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildCashFlowSummaryCard() {
    final cashFlowStyle = AppTypography.bodyMedium.copyWith(
      color: isDark ? Colors.white : AppColors.neutral900Light,
      fontWeight: FontWeight.w600,
    );

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Cash Out
          Icon(
            Icons.arrow_upward_rounded,
            size: 16,
            color: AppColors.errorLight,
          ),
          const SizedBox(width: 4),
          isPrivacyMode
              ? MaskedAmountText(
                  text: currencyFormat.formatCompact(stats.totalInvested),
                  style: cashFlowStyle,
                )
              : CompactAmountText(
                  amount: stats.totalInvested,
                  compactText: currencyFormat.formatCompact(
                    stats.totalInvested,
                  ),
                  currencySymbol: currencyFormat.currencySymbol,
                  style: cashFlowStyle,
                ),
          Text(
            ' out',
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          const SizedBox(width: 16),
          // Cash In
          Icon(
            Icons.arrow_downward_rounded,
            size: 16,
            color: AppColors.successLight,
          ),
          const SizedBox(width: 4),
          isPrivacyMode
              ? MaskedAmountText(
                  text: currencyFormat.formatCompact(stats.totalReturned),
                  style: cashFlowStyle,
                )
              : CompactAmountText(
                  amount: stats.totalReturned,
                  compactText: currencyFormat.formatCompact(
                    stats.totalReturned,
                  ),
                  currencySymbol: currencyFormat.currencySymbol,
                  style: cashFlowStyle,
                ),
          Text(
            ' in',
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          const Spacer(),
          Text(
            '${stats.cashFlowCount} txns',
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini stat card for XIRR/MOIC display.
class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final String? subtitle;
  final bool isPrivacyMode;

  const _MiniStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.subtitle,
    this.isPrivacyMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final valueStyle = AppTypography.bodyMedium.copyWith(
      color: color,
      fontWeight: FontWeight.w700,
    );

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        children: [
          Text(
            label,
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          isPrivacyMode
              ? MaskedAmountText(text: value, style: valueStyle)
              : Text(value, style: valueStyle),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                subtitle!,
                style: AppTypography.small.copyWith(
                  color: isDark
                      ? AppColors.neutral500Dark
                      : AppColors.neutral400Light,
                  fontSize: 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Maturity card showing days until maturity.
class _MaturityCard extends StatelessWidget {
  final DateTime maturityDate;
  final bool isDark;

  const _MaturityCard({required this.maturityDate, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maturity = DateTime(
      maturityDate.year,
      maturityDate.month,
      maturityDate.day,
    );
    final daysUntilMaturity = maturity.difference(today).inDays;

    final (statusColor, statusIcon, statusText) = _getMaturityStatus(
      daysUntilMaturity,
    );

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, size: 18, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Maturity Date',
                  style: AppTypography.small.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppDateUtils.formatShort(maturityDate),
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusText,
              style: AppTypography.small.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _getMaturityStatus(int daysUntilMaturity) {
    final bool isMatured = daysUntilMaturity < 0;
    final bool isUrgent = daysUntilMaturity >= 0 && daysUntilMaturity <= 7;
    final bool isUpcoming = daysUntilMaturity > 7 && daysUntilMaturity <= 30;

    if (isMatured) {
      return (
        AppColors.successLight,
        Icons.check_circle_rounded,
        'Matured ${-daysUntilMaturity} days ago',
      );
    } else if (daysUntilMaturity == 0) {
      return (AppColors.warningLight, Icons.schedule_rounded, 'Matures today!');
    } else if (isUrgent) {
      return (
        AppColors.warningLight,
        Icons.schedule_rounded,
        '$daysUntilMaturity days until maturity',
      );
    } else if (isUpcoming) {
      return (
        AppColors.accentLight,
        Icons.event_rounded,
        '$daysUntilMaturity days until maturity',
      );
    } else {
      return (
        isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
        Icons.event_rounded,
        '$daysUntilMaturity days until maturity',
      );
    }
  }
}
