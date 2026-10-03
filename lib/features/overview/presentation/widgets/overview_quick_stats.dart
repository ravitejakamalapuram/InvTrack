/// Quick Stats row (MOIC and cash flow count) on the overview screen.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/utils/return_display.dart';
import 'package:inv_tracker/features/overview/presentation/widgets/quick_stat_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Shows the portfolio MOIC and the number of cash flows.
class OverviewQuickStats extends StatelessWidget {
  /// Stats of the whole portfolio, converted to the base currency.
  final InvestmentStats stats;

  /// Stats of the open investments within [stats].
  final InvestmentStats openStats;

  const OverviewQuickStats({
    super.key,
    required this.stats,
    required this.openStats,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    // Same classification as the hero card: while open investments have no
    // terminal value, MOIC would read as a total loss.
    final display = ReturnDisplay.resolve(stats: stats, openStats: openStats);
    final awaiting = display.isAwaitingValue;
    return Row(
      children: [
        Expanded(
          child: QuickStatCard(
            icon: Icons.trending_up,
            label: l10n.moicLabel,
            value: awaiting
                ? ReturnDisplay.dash
                : '${NumberFormat('#,##0.00').format(stats.moic)}x',
            color: awaiting
                ? AppColors.neutral500Light
                : AppColors.successLight,
            subtitle: awaiting
                ? display.secondaryText(l10n)
                : stats.durationFormatted != null
                ? l10n.overDuration(stats.durationFormatted!)
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: QuickStatCard(
            icon: Icons.receipt_long,
            label: l10n.cashFlowsLabel,
            value: '${stats.cashFlowCount}',
            color: AppColors.primaryLight,
            isSensitive: false, // Count is not sensitive
          ),
        ),
      ],
    );
  }
}
