/// Income Trend Report Screen
///
/// Displays comprehensive income trend analysis with:
/// - Monthly income chart (last 12 months)
/// - Growth metrics (MoM, QoQ)
/// - Platform reliability scores
/// - Income diversification analysis
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_trend_provider.dart';
import 'package:inv_tracker/features/security/presentation/widgets/privacy_protection_wrapper.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';

/// Income Trend Report Screen
class IncomeTrendReportScreen extends ConsumerWidget {
  const IncomeTrendReportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final reportAsync = ref.watch(incomeTrendReportProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.incomeTrendReport),
      ),
      body: reportAsync.when(
        data: (report) => _buildContent(context, ref, report, l10n),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, ref, l10n),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, dynamic report, AppLocalizations l10n) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final locale = ref.watch(currencyLocaleProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with total income
          _buildHeaderCard(context, report, currencySymbol, locale, l10n),
          const SizedBox(height: AppSpacing.md),

          // 2. Growth Metrics
          _buildGrowthMetrics(context, report),
          const SizedBox(height: AppSpacing.md),

          // 3. Monthly Trend Chart
          _buildMonthlyChart(context, report, isDark),
          const SizedBox(height: AppSpacing.md),

          // 4. Platform Reliability
          _buildPlatformReliability(context, report),
          const SizedBox(height: AppSpacing.md),

          // 5. Income Diversification
          _buildDiversification(context, report),
          const SizedBox(height: AppSpacing.md),

          // 6. Auto-Insights
          if (report.insights.isNotEmpty) _buildInsights(context, report),
          
          const SizedBox(height: AppSpacing.fabBottomPadding),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, dynamic report, String currencySymbol, String locale, AppLocalizations l10n) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.totalIncomeLast12Months,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            PrivacyProtectionWrapper(
              child: Text(
                formatCompactCurrency(
                  report.totalIncome,
                  symbol: currencySymbol,
                  locale: locale,
                ),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            PrivacyProtectionWrapper(
              child: Text(
                '${l10n.averageMonthly}: ${formatCompactCurrency(report.averageMonthlyIncome, symbol: currencySymbol, locale: locale)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrowthMetrics(BuildContext context, dynamic report) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.growthMetrics,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: l10n.monthOverMonth,
                    value: '${report.momGrowth.toStringAsFixed(1)}%',
                    isPositive: report.momGrowth >= 0,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildMetricTile(
                    context,
                    label: l10n.quarterOverQuarter,
                    value: '${report.qoqGrowth.toStringAsFixed(1)}%',
                    isPositive: report.qoqGrowth >= 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? Colors.green : Colors.red,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChart(BuildContext context, dynamic report, bool isDark) {
    final l10n = AppLocalizations.of(context);

    if (report.monthlyData.isEmpty) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.monthlyIncomeTrend,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: report.monthlyData.asMap().entries.map<FlSpot>((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.totalIncome);
                      }).toList(),
                      isCurved: true,
                      color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: (isDark ? AppColors.primaryDark : AppColors.primaryLight).withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= report.monthlyData.length) {
                            return const SizedBox();
                          }
                          final month = report.monthlyData[value.toInt()].month;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('MMM').format(month),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: isDark
                            ? AppColors.neutral700Dark.withValues(alpha: 0.5)
                            : AppColors.neutral300Light.withValues(alpha: 0.5),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformReliability(BuildContext context, dynamic report) {
    final l10n = AppLocalizations.of(context);

    if (report.platformReliability.isEmpty) {
      return const SizedBox();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.platformReliability,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            ...report.platformReliability.take(5).map((p) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.platform,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getReliabilityColor(p.onTimeRate).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${(p.onTimeRate * 100).toStringAsFixed(0)}% on-time',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _getReliabilityColor(p.onTimeRate),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Color _getReliabilityColor(double rate) {
    if (rate >= 0.95) return Colors.green;
    if (rate >= 0.80) return Colors.orange;
    return Colors.red;
  }

  Widget _buildDiversification(BuildContext context, dynamic report) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.incomeDiversification,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _getDiversificationLabel(context, report.diversificationScore),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: _getDiversificationColor(report.diversificationScore),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (report.incomeSources.isNotEmpty) ...[
              ...report.incomeSources.take(3).map((source) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              source.investmentName,
                              style: Theme.of(context).textTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${source.percentage.toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: source.percentage / 100,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  String _getDiversificationLabel(BuildContext context, double score) {
    final l10n = AppLocalizations.of(context);
    if (score < 0.15) return l10n.diversificationExcellent;
    if (score < 0.30) return l10n.diversificationModerate;
    if (score < 0.50) return l10n.diversificationHigh;
    return l10n.diversificationRisky;
  }

  Color _getDiversificationColor(double score) {
    if (score < 0.15) return Colors.green;
    if (score < 0.30) return Colors.blue;
    if (score < 0.50) return Colors.orange;
    return Colors.red;
  }

  Widget _buildInsights(BuildContext context, dynamic report) {
    final l10n = AppLocalizations.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.keyInsights,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            ...report.insights.map((insight) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        insight,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: AppColors.errorLight,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.trendReportLoadFailed,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: () => ref.invalidate(incomeTrendReportProvider),
              child: Text(l10n.trendReportRetry),
            ),
          ],
        ),
      ),
    );
  }
}

