import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/domain/entities/investment.dart';
import 'package:inv_tracker/presentation/providers/repository_providers.dart';

/// Analytics screen with charts and metrics.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final investmentsAsync = ref.watch(investmentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: investmentsAsync.when(
        data: (investments) => investments.isEmpty
            ? _buildEmptyState(context)
            : SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Allocation', style: Theme.of(context).textTheme.titleMedium),
                    AppSpacing.gapVerticalMd,
                    _AllocationPieChart(investments: investments),
                    AppSpacing.gapVerticalXl,
                    Text('Portfolio Value', style: Theme.of(context).textTheme.titleMedium),
                    AppSpacing.gapVerticalMd,
                    _PortfolioLineChart(investments: investments),
                  ],
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppSpacing.screenPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[400]),
            AppSpacing.gapVerticalXl,
            Text('No Data Yet', style: Theme.of(context).textTheme.titleLarge),
            AppSpacing.gapVerticalSm,
            Text('Add investments to see analytics', textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

/// Allocation pie chart by category.
class _AllocationPieChart extends StatelessWidget {
  final List<Investment> investments;
  const _AllocationPieChart({required this.investments});

  @override
  Widget build(BuildContext context) {
    final categoryData = <String, int>{};
    for (final inv in investments) {
      categoryData[inv.category] = (categoryData[inv.category] ?? 0) + 1;
    }
    final total = investments.length;
    final sections = categoryData.entries.map((e) {
      final percentage = (e.value / total) * 100;
      final color = AppColors.getCategoryColor(e.key);
      return PieChartSectionData(
        value: e.value.toDouble(),
        title: percentage > 10 ? '${percentage.toStringAsFixed(0)}%' : '',
        color: color,
        radius: 80,
        titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      );
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 40, sectionsSpace: 2)),
        ),
        AppSpacing.gapVerticalMd,
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.sm,
          children: categoryData.entries.map((e) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: AppColors.getCategoryColor(e.key), shape: BoxShape.circle)),
              AppSpacing.gapHorizontalXs,
              Text('${_formatCategory(e.key)} (${e.value})', style: Theme.of(context).textTheme.bodySmall),
            ],
          )).toList(),
        ),
      ],
    );
  }

  String _formatCategory(String category) => category.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m.group(1)}').trim();
}

/// Portfolio value line chart.
class _PortfolioLineChart extends StatelessWidget {
  final List<Investment> investments;
  const _PortfolioLineChart({required this.investments});

  @override
  Widget build(BuildContext context) {
    // Generate sample data points based on investment count over time
    final spots = <FlSpot>[];
    final sortedInvestments = List<Investment>.from(investments)..sort((a, b) => a.startDate.compareTo(b.startDate));
    for (int i = 0; i < sortedInvestments.length; i++) {
      spots.add(FlSpot(i.toDouble(), (i + 1).toDouble()));
    }
    if (spots.isEmpty) spots.add(const FlSpot(0, 0));

    final isPositive = spots.length > 1;
    final color = isPositive ? AppColors.profit : AppColors.primary;

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
          ],
          titlesData: const FlTitlesData(show: false),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

