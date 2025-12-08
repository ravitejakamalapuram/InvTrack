import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/premium_animations.dart';
import 'package:inv_tracker/features/insights/presentation/providers/insights_provider.dart';
import 'package:inv_tracker/features/investment/presentation/screens/investment_detail_screen.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightsAsync = ref.watch(insightsDataProvider);
    final selectedPeriod = ref.watch(insightsPeriodProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencyFormat = ref.watch(currencyFormatProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 100,
            floating: true,
            pinned: true,
            backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Insights',
                style: AppTypography.h2.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            ),
          ),

          // Period Selector
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: _buildPeriodSelector(ref, selectedPeriod, isDark),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: insightsAsync.when(
              data: (data) => SliverList(
                delegate: SliverChildListDelegate([
                  // Performance Metrics
                  _buildSectionHeader('Performance', isDark),
                  const SizedBox(height: 12),
                  _buildPerformanceCard(data, currencyFormat, isDark),
                  const SizedBox(height: 24),

                  // Allocation Chart
                  _buildSectionHeader('Allocation by Type', isDark),
                  const SizedBox(height: 12),
                  _buildAllocationCard(data, isDark),
                  const SizedBox(height: 24),

                  // Investment Rankings
                  _buildSectionHeader('Investment Breakdown', isDark),
                  const SizedBox(height: 12),
                  ...data.investments.asMap().entries.map((entry) =>
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StaggeredFadeIn(
                        index: entry.key,
                        child: _buildInvestmentRow(context, entry.value, currencyFormat, isDark),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ]),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(child: Text('Error: $e')),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(WidgetRef ref, InsightsPeriod selected, bool isDark) {
    final periods = [
      (InsightsPeriod.oneMonth, '1M'),
      (InsightsPeriod.threeMonths, '3M'),
      (InsightsPeriod.sixMonths, '6M'),
      (InsightsPeriod.oneYear, '1Y'),
      (InsightsPeriod.all, 'All'),
    ];

    return Row(
      children: periods.map((p) {
        final isSelected = p.$1 == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => ref.read(insightsPeriodProvider.notifier).state = p.$1,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryLight
                    : (isDark ? AppColors.cardDark : AppColors.cardLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  p.$2,
                  style: AppTypography.labelMedium.copyWith(
                    color: isSelected
                        ? Colors.white
                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: AppTypography.h4.copyWith(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }

  Widget _buildPerformanceCard(InsightsData data, NumberFormat fmt, bool isDark) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildMetricItem('Total Value', fmt.format(data.totalValue), isDark)),
              Expanded(child: _buildMetricItem('Invested', fmt.format(data.totalInvested), isDark)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricItem(
                'Returns',
                '${data.totalProfitLoss >= 0 ? '+' : ''}${fmt.format(data.totalProfitLoss)}',
                isDark,
                valueColor: data.totalProfitLoss >= 0 ? AppColors.successLight : AppColors.dangerLight,
              )),
              Expanded(child: _buildMetricItem(
                'XIRR',
                '${data.portfolioXirr >= 0 ? '+' : ''}${data.portfolioXirr.toStringAsFixed(1)}%',
                isDark,
                valueColor: data.portfolioXirr >= 0 ? AppColors.successLight : AppColors.dangerLight,
              )),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricItem(
                'MOIC',
                '${data.portfolioMoic.toStringAsFixed(2)}x',
                isDark,
              )),
              Expanded(child: _buildMetricItem(
                'Return %',
                '${data.totalProfitLossPercent >= 0 ? '+' : ''}${data.totalProfitLossPercent.toStringAsFixed(1)}%',
                isDark,
                valueColor: data.totalProfitLossPercent >= 0 ? AppColors.successLight : AppColors.dangerLight,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value, bool isDark, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.h4.copyWith(
            color: valueColor ?? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildAllocationCard(InsightsData data, bool isDark) {
    if (data.allocationByType.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Text(
            'No allocation data',
            style: AppTypography.body.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
      );
    }

    final colors = [
      AppColors.graphBlue,
      AppColors.graphPurple,
      AppColors.graphPink,
      AppColors.graphAmber,
      AppColors.graphEmerald,
      AppColors.graphCyan,
    ];

    final total = data.allocationByType.values.fold(0.0, (sum, v) => sum + v);
    final entries = data.allocationByType.entries.toList();

    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        height: 200,
        child: Row(
          children: [
            Expanded(
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: entries.asMap().entries.map((e) {
                    final percent = (e.value.value / total) * 100;
                    return PieChartSectionData(
                      color: colors[e.key % colors.length],
                      value: e.value.value,
                      title: '${percent.toStringAsFixed(0)}%',
                      radius: 50,
                      titleStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colors[e.key % colors.length],
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        e.value.key,
                        style: AppTypography.caption.copyWith(
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvestmentRow(BuildContext context, InvestmentInsight insight, NumberFormat fmt, bool isDark) {
    final isPositive = insight.profitLoss >= 0;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => InvestmentDetailScreen(investment: insight.investment),
          ),
        );
      },
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isDark ? AppColors.primaryDark : AppColors.primaryLight).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  insight.investment.name.substring(0, 1).toUpperCase(),
                  style: AppTypography.h4.copyWith(
                    color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Name & Type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.investment.name,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${insight.investment.type} • ${insight.allocationPercent.toStringAsFixed(1)}%',
                    style: AppTypography.caption.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            // Value & Return
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmt.format(insight.currentValue),
                  style: AppTypography.bodyMedium.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${isPositive ? '+' : ''}${insight.profitLossPercent.toStringAsFixed(1)}%',
                  style: AppTypography.caption.copyWith(
                    color: isPositive ? AppColors.successLight : AppColors.dangerLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

