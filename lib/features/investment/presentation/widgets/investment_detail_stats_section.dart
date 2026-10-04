import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/calculations/investment_projector.dart';
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
import 'package:inv_tracker/features/investment/presentation/utils/return_display.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Stats section widget for investment detail screen.
/// Displays net position, cash flow summary, XIRR/MOIC, and maturity info.
class InvestmentDetailStatsSection extends StatelessWidget {
  final InvestmentStats stats;
  final InvestmentEntity investment;
  final bool isDark;
  final NumberFormat currencyFormat;
  final bool isPrivacyMode;

  /// Opens the editor for the investment's current value, or null to offer
  /// none.
  final VoidCallback? onUpdateCurrentValue;

  const InvestmentDetailStatsSection({
    super.key,
    required this.stats,
    required this.investment,
    required this.isDark,
    required this.currencyFormat,
    required this.isPrivacyMode,
    this.onUpdateCurrentValue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPositive = stats.netCashFlow >= 0;
    final display = ReturnDisplay.resolve(
      stats: stats,
      openStats: investment.isOpen ? stats : null,
    );
    final hasReturnFigure =
        display.kind == ReturnDisplayKind.annualised ||
        display.kind == ReturnDisplayKind.shortHolding;
    final xirr = stats.xirr;
    final returnIsPositive = display.kind == ReturnDisplayKind.shortHolding
        ? stats.absoluteReturn >= 0
        : xirr != null && xirr >= 0;
    final projection =
        display.kind == ReturnDisplayKind.awaitingFirstPayout ||
            (investment.isOpen &&
                stats.totalReturned == 0 &&
                stats.currentValueIsEstimate)
        ? _projectedMaturityText(l10n)
        : null;

    return Column(
      children: [
        // Net Position Hero Card
        _buildNetPositionCard(context, isPositive, display),
        if (investment.isOpen) ...[
          const SizedBox(height: 10),
          _CurrentValueCard(
            stats: stats,
            isDark: isDark,
            currencyFormat: currencyFormat,
            isPrivacyMode: isPrivacyMode,
            onUpdate: onUpdateCurrentValue,
          ),
        ],
        if (projection != null) ...[
          const SizedBox(height: 6),
          Text(
            projection,
            style: AppTypography.small.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
        ],
        const SizedBox(height: 10),
        // Cash Out and Cash In row
        _buildCashFlowSummaryCard(),
        const SizedBox(height: 10),
        // XIRR and MOIC row
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                label: display.metricLabel(l10n),
                value: display.primaryText(l10n),
                color: !hasReturnFigure
                    ? _neutralColor
                    : returnIsPositive
                    ? AppColors.graphCyan
                    : AppColors.errorLight,
                isDark: isDark,
                // The annualised rate is a return figure: hide it in privacy
                // mode like the primary value. The hint is not sensitive.
                subtitle: isPrivacyMode && !display.isAwaitingValue
                    ? null
                    : display.secondaryText(l10n),
                isPrivacyMode: isPrivacyMode,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MiniStatCard(
                label: 'MOIC',
                value: display.isAwaitingValue
                    ? ReturnDisplay.dash
                    : formatMultiplier(stats.moic),
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

  Color get _neutralColor =>
      isDark ? AppColors.neutral400Dark : AppColors.neutral500Light;

  /// "Projected at maturity ₹1,23,144 (7.19% p.a.)" for an open investment
  /// that has not paid out yet, when its rate and tenure are known. Periodic
  /// payouts are skipped: their interest is paid out, not compounded.
  String? _projectedMaturityText(AppLocalizations l10n) {
    if (isPrivacyMode ||
        investment.interestPayoutMode == InterestPayoutMode.periodic) {
      return null;
    }
    final summary = InvestmentProjector.getProjectionSummary(
      principal: stats.totalInvested,
      annualRate: investment.expectedRate,
      tenureMonths: investment.tenureMonths,
      compounding: investment.compoundingFrequency,
    );
    if (summary == null) return null;
    return l10n.projectedAtMaturity(
      currencyFormat.format(summary.maturityValue),
      formatPercent(summary.effectiveRate, decimals: 2),
    );
  }

  Widget _buildNetPositionCard(
    BuildContext context,
    bool isPositive,
    ReturnDisplay display,
  ) {
    final l10n = AppLocalizations.of(context);
    final status = display.statusLabel(l10n);
    // Neutral while the investment has no terminal value: a negative net
    // cash flow is money still invested, not a loss.
    final accent = status != null
        ? _neutralColor
        : isPositive
        ? AppColors.successLight
        : AppColors.errorLight;
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
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              status != null
                  ? Icons.hourglass_top_rounded
                  : isPositive
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 28,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  investment.isOpen ? l10n.netCashFlowSoFar : l10n.netPosition,
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
          _buildReturnBadge(isPositive, status),
        ],
      ),
    );
  }

  Widget _buildReturnBadge(bool isPositive, String? status) {
    if (status != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _neutralColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          status,
          style: AppTypography.small.copyWith(
            color: _neutralColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

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

/// What an open investment is worth today, how that value was obtained, and
/// a button to add or update the user's own value.
class _CurrentValueCard extends StatelessWidget {
  final InvestmentStats stats;
  final bool isDark;
  final NumberFormat currencyFormat;
  final bool isPrivacyMode;
  final VoidCallback? onUpdate;

  const _CurrentValueCard({
    required this.stats,
    required this.isDark,
    required this.currencyFormat,
    required this.isPrivacyMode,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = stats.currentValue;
    final mutedColor = isDark
        ? AppColors.neutral400Dark
        : AppColors.neutral500Light;
    final amountText = value == null ? null : currencyFormat.format(value);
    final basis = _basis(l10n, value);
    final semanticsLabel = isPrivacyMode && value != null
        ? l10n.currentValueHidden
        : [l10n.currentValueLabel, ?amountText, basis].join(', ');

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label: semanticsLabel,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentValueLabel,
                      style: AppTypography.small.copyWith(color: mutedColor),
                    ),
                    if (amountText != null) ...[
                      const SizedBox(height: 2),
                      MaskedAmountText(
                        text: amountText,
                        style: AppTypography.bodyMedium.copyWith(
                          color: isDark
                              ? Colors.white
                              : AppColors.neutral900Light,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      basis,
                      style: AppTypography.small.copyWith(color: mutedColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onUpdate != null)
            TextButton(
              onPressed: onUpdate,
              child: Text(
                value == null ? l10n.currentValueAdd : l10n.currentValueUpdate,
              ),
            ),
        ],
      ),
    );
  }

  String _basis(AppLocalizations l10n, double? value) {
    if (value == null) return l10n.currentValueNone;
    if (!stats.currentValueIsEstimate) {
      final date = stats.currentValueDate;
      return date == null
          ? l10n.currentValueLabel
          : l10n.currentValueUpdatedOn(AppDateUtils.formatShort(date));
    }
    final rate = stats.currentValueRate;
    return rate != null
        ? l10n.currentValueEstimatedAtRate(ReturnDisplay.formatRate(rate))
        : l10n.currentValueEstimatedPrincipal;
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
                textAlign: TextAlign.center,
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
