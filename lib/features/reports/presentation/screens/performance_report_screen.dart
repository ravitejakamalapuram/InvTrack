/// Performance Report Screen
///
/// Shows investment performance analysis including:
/// - Top and bottom performers
/// - Recent milestone achievements
/// - Performance distribution
/// - Average/median XIRR
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/reports/domain/entities/performance_report.dart';
import 'package:inv_tracker/features/reports/presentation/providers/performance_report_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/base_report_screen.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_stat_card.dart';

class PerformanceReportScreen extends BaseReportScreen<PerformanceReport> {
  const PerformanceReportScreen({super.key});

  @override
  String getTitle(BuildContext context) {
    return 'Performance Report';
  }

  @override
  FutureProvider<PerformanceReport> getDataProvider(WidgetRef ref) {
    return performanceReportProvider;
  }

  @override
  Widget buildContent(BuildContext context, WidgetRef ref, PerformanceReport report) {
    final locale = ref.watch(currencyLocaleProvider);
    final symbol = ref.watch(currencySymbolProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Stats
        Text(
          'Portfolio Performance',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ReportStatCard(
                icon: Icons.trending_up_rounded,
                label: 'Avg XIRR',
                value: '${(report.averageXIRR * 100).toStringAsFixed(2)}%',
                iconColor: report.averageXIRR >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ReportStatCard(
                icon: Icons.analytics_rounded,
                label: 'Median XIRR',
                value: '${(report.medianXIRR * 100).toStringAsFixed(2)}%',
                iconColor: report.medianXIRR >= 0 ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ReportStatCard(
                icon: Icons.thumb_up_rounded,
                label: 'Profitable',
                value: '${report.profitableCount}/${report.totalInvestments}',
                iconColor: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ReportStatCard(
                icon: Icons.thumb_down_rounded,
                label: 'Loss Making',
                value: '${report.lossCount}/${report.totalInvestments}',
                iconColor: Colors.red,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Top Performers
        _buildTopPerformers(context, report, symbol, locale),

        const SizedBox(height: 24),

        // Bottom Performers
        _buildBottomPerformers(context, report, symbol, locale),

        const SizedBox(height: 24),

        // Recent Milestones
        _buildMilestones(context, report, symbol, locale),
      ],
    );
  }

  Widget _buildTopPerformers(
    BuildContext context,
    PerformanceReport report,
    String symbol,
    String locale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🏆 Top Performers',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...report.topPerformers.take(5).map((perf) {
          return Card(
            child: ListTile(
              title: Text(perf.investment.name),
              subtitle: Text('XIRR: ${(perf.xirr * 100).toStringAsFixed(2)}%'),
              trailing: PrivacyMask(
                child: Text(
                  '+${formatCompactCurrency(perf.absoluteReturn, symbol: symbol, locale: locale)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBottomPerformers(
    BuildContext context,
    PerformanceReport report,
    String symbol,
    String locale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📉 Bottom Performers',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...report.bottomPerformers.take(5).map((perf) {
          return Card(
            child: ListTile(
              title: Text(perf.investment.name),
              subtitle: Text('XIRR: ${(perf.xirr * 100).toStringAsFixed(2)}%'),
              trailing: PrivacyMask(
                child: Text(
                  formatCompactCurrency(perf.absoluteReturn, symbol: symbol, locale: locale),
                  style: TextStyle(
                    color: perf.absoluteReturn >= 0 ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMilestones(
    BuildContext context,
    PerformanceReport report,
    String symbol,
    String locale,
  ) {
    if (report.recentMilestones.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🎯 Recent Milestones',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...report.recentMilestones.take(10).map((milestone) {
          return Card(
            child: ListTile(
              leading: Text(
                milestone.emoji,
                style: const TextStyle(fontSize: 32),
              ),
              title: Text(milestone.investment.name),
              subtitle: Text(milestone.label),
              trailing: PrivacyMask(
                child: Text(
                  '+${formatCompactCurrency(milestone.amountGained, symbol: symbol, locale: locale)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
