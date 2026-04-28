/// Weekly Investment Summary Report Screen
///
/// Displays a comprehensive weekly summary including:
/// - Total invested, returns, income
/// - Net position with week-over-week comparison
/// - Top performer by XIRR
/// - Daily cashflow chart
/// - New investments and upcoming maturities
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/reports/domain/entities/weekly_summary.dart';
import 'package:inv_tracker/features/reports/presentation/providers/weekly_summary_provider.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/base_report_screen.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_stat_card.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/daily_cashflow_chart.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_export_button.dart';

/// Weekly summary screen
class WeeklySummaryScreen extends BaseReportScreen<WeeklySummary> {
  const WeeklySummaryScreen({super.key});

  @override
  String getTitle(BuildContext context) {
    return 'Weekly Summary';
  }

  @override
  FutureProvider<WeeklySummary> getDataProvider(WidgetRef ref) {
    return currentWeeklySummaryProvider;
  }

  @override
  List<Widget> buildActions(BuildContext context, WidgetRef ref, WeeklySummary data) {
    return [
      ReportExportButton(
        reportData: data,
        reportType: ReportType.weeklySummary,
      ),
    ];
  }

  @override
  Widget buildContent(
    BuildContext context,
    WidgetRef ref,
    WeeklySummary data,
  ) {
    final locale = ref.watch(currencyLocaleProvider);
    final symbol = ref.watch(currencySymbolProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Period header
        Text(
          '${DateFormat.MMMd().format(data.periodStart)} - ${DateFormat.MMMd().format(data.periodEnd)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.md),

        // Key metrics grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.5,
          children: [
            ReportStatCard(
              icon: Icons.trending_down_rounded,
              label: 'Total Invested',
              value: formatCompactCurrency(
                data.totalInvested,
                symbol: symbol,
                locale: locale,
              ),
            ),
            ReportStatCard(
              icon: Icons.trending_up_rounded,
              label: 'Total Returns',
              value: formatCompactCurrency(
                data.totalReturns,
                symbol: symbol,
                locale: locale,
              ),
            ),
            ReportStatCard(
              icon: data.isPositiveWeek
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              label: 'Net Position',
              value: formatCompactCurrency(
                data.netPosition,
                symbol: symbol,
                locale: locale,
              ),
              iconColor: data.isPositiveWeek ? Colors.green : Colors.red,
              trendValue: data.weekOverWeekChange,
              isTrendPositive: data.weekOverWeekChange != null &&
                  data.weekOverWeekChange! > 0,
            ),
            ReportStatCard(
              icon: Icons.payments_rounded,
              label: 'Total Income',
              value: formatCompactCurrency(
                data.totalIncome,
                symbol: symbol,
                locale: locale,
              ),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.lg),

        // Top Performer
        if (data.topPerformer != null) ...[
          _buildTopPerformer(context, ref, data),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Daily cashflow chart
        _buildDailyChart(context, ref, data),

        const SizedBox(height: AppSpacing.lg),

        // New investments
        if (data.newInvestments.isNotEmpty) ...[
          _buildNewInvestments(context, ref, data),
          const SizedBox(height: AppSpacing.lg),
        ],

        // Upcoming maturities
        if (data.upcomingMaturities.isNotEmpty) ...[
          _buildUpcomingMaturities(context, ref, data),
        ],
      ],
    );
  }

  Widget _buildTopPerformer(
    BuildContext context,
    WidgetRef ref,
    WeeklySummary data,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Colors.amber),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Top Performer',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.topPerformer!.name,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'XIRR: ${(data.topPerformerXirr! * 100).toStringAsFixed(2)}%',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyChart(
    BuildContext context,
    WidgetRef ref,
    WeeklySummary data,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Cashflow Trend',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.md),
          DailyCashFlowChart(
            dailyCashFlows: data.dailyCashFlows,
            height: 200,
          ),
        ],
      ),
    );
  }

  Widget _buildNewInvestments(
    BuildContext context,
    WidgetRef ref,
    WeeklySummary data,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New Investments (${data.newInvestments.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.newInvestments.map((inv) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, size: 8),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: Text(inv.name)),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildUpcomingMaturities(
    BuildContext context,
    WidgetRef ref,
    WeeklySummary data,
  ) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Maturing Next Week (${data.upcomingMaturities.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...data.upcomingMaturities.map((inv) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, size: 8),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        '${inv.name} - ${DateFormat.MMMd().format(inv.maturityDate!)}',
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
