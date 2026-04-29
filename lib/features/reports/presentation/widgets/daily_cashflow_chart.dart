/// Daily cashflow trend chart for weekly summary reports
///
/// Displays a simple bar chart showing daily cashflows grouped by type
/// (INVEST, RETURN, INCOME, FEE)
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/reports/domain/entities/weekly_summary.dart';

/// Daily cashflow chart widget
class DailyCashFlowChart extends ConsumerWidget {
  final List<DailyCashFlow> dailyCashFlows;
  final double height;

  const DailyCashFlowChart({
    super.key,
    required this.dailyCashFlows,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context).toString();

    // Helper to get localized day name
    String getDayName(DateTime date) {
      return DateFormat.E(locale).format(date);
    }

    if (dailyCashFlows.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No cashflows this week',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.neutral400Dark
                      : AppColors.neutral500Light,
                ),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _getMaxY(),
          minY: _getMinY(),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (groupIndex >= dailyCashFlows.length) {
                  return null;
                }
                final data = dailyCashFlows[groupIndex];
                final amount = rod.toY;
                return BarTooltipItem(
                  '${getDayName(data.date)}\n${NumberFormat.compactSimpleCurrency(locale: locale).format(amount)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value < 0 || value >= dailyCashFlows.length) {
                    return const SizedBox.shrink();
                  }
                  final data = dailyCashFlows[value.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      getDayName(data.date),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isDark
                                ? AppColors.neutral400Dark
                                : AppColors.neutral500Light,
                          ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _getGridInterval(),
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
          barGroups: _buildBarGroups(isDark),
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups(bool isDark) {
    return dailyCashFlows.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      final amount = data.net;
      final isPositive = amount >= 0;

      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: amount,
            color: isPositive ? Colors.green : Colors.red,
            width: 16,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();
  }

  double _getMaxY() {
    if (dailyCashFlows.isEmpty) return 100;
    final nets = dailyCashFlows.map((d) => d.net).toList();
    final maxValue = nets.reduce((a, b) => a > b ? a : b);
    return maxValue > 0 ? maxValue * 1.2 : 100;
  }

  double _getMinY() {
    if (dailyCashFlows.isEmpty) return 0;
    final nets = dailyCashFlows.map((d) => d.net).toList();
    final minValue = nets.reduce((a, b) => a < b ? a : b);
    return minValue < 0 ? minValue * 1.2 : 0;
  }

  double _getGridInterval() {
    final range = _getMaxY() - _getMinY();
    return range / 5; // 5 grid lines
  }
}
