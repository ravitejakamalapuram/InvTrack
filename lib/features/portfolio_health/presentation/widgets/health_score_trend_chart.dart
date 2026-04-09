/// Historical trend chart for Portfolio Health Score
///
/// Displays last 12 weeks of health scores as a line chart
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Trend chart showing health score over time
class HealthScoreTrendChart extends ConsumerStatefulWidget {
  final double height;

  const HealthScoreTrendChart({
    super.key,
    this.height = 200,
  });

  @override
  ConsumerState<HealthScoreTrendChart> createState() =>
      _HealthScoreTrendChartState();
}

class _HealthScoreTrendChartState extends ConsumerState<HealthScoreTrendChart> {
  bool _showComponentScores = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chartDataAsync = ref.watch(healthScoreChartDataProvider);

    return chartDataAsync.when(
      data: (chartData) {
        if (chartData.isEmpty || chartData.length < 2) {
          return _buildEmptyState(context, isDark);
        }
        return _buildChart(context, isDark, chartData);
      },
      loading: () => SizedBox(
        height: widget.height,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => _buildEmptyState(context, isDark),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: widget.height,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Semantics(
              label: l10n.healthScoreTrendNoData,
              child: Icon(
                Icons.show_chart,
                size: 48,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.healthScoreTrendNoData,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.healthScoreTrendCheckBack,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(BuildContext context, bool isDark, List<Map<String, dynamic>> chartData) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with toggle
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.healthScoreTrendWeeks(chartData.length),
              style: AppTypography.h4.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _showComponentScores = !_showComponentScores;
                });
              },
              icon: Icon(
                _showComponentScores ? Icons.remove_circle_outline : Icons.add_circle_outline,
                size: 16,
              ),
              label: Text(
                _showComponentScores ? l10n.hideDetails : l10n.showDetails,
                style: AppTypography.caption,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Chart
        SizedBox(
          height: widget.height,
          child: LineChart(
            _buildLineChartData(isDark, chartData),
          ),
        ),
      ],
    );
  }

  LineChartData _buildLineChartData(
    bool isDark,
    List<Map<String, dynamic>> chartData,
  ) {
    final textColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final gridColor = isDark ? Colors.grey.shade800 : Colors.grey.shade300;

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: 20,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: gridColor,
            strokeWidth: 1,
          );
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 20,
            getTitlesWidget: (value, meta) {
              return Text(
                value.toInt().toString(),
                style: TextStyle(color: textColor, fontSize: 10),
              );
            },
            reservedSize: 32,
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              if (value.toInt() < 0 || value.toInt() >= chartData.length) {
                return const SizedBox.shrink();
              }
              final date = DateTime.fromMillisecondsSinceEpoch(
                chartData[value.toInt()]['date'] as int,
              );
              final locale = Localizations.localeOf(context).toString();
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  DateFormat('M/d', locale).format(date),
                  style: TextStyle(color: textColor, fontSize: 10),
                ),
              );
            },
            reservedSize: 32,
          ),
        ),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: 0,
      maxY: 100,
      lineBarsData: _buildLineBars(isDark, chartData),
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final date = DateTime.fromMillisecondsSinceEpoch(
                chartData[spot.x.toInt()]['date'] as int,
              );
              final locale = Localizations.localeOf(context).toString();
              return LineTooltipItem(
                '${DateFormat.MMMd(locale).format(date)}\n${spot.y.toInt()}/100',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              );
            }).toList();
          },
        ),
      ),
    );
  }

  List<LineChartBarData> _buildLineBars(
    bool isDark,
    List<Map<String, dynamic>> chartData,
  ) {
    final List<LineChartBarData> bars = [];

    // Overall score (always shown)
    bars.add(
      LineChartBarData(
        spots: chartData
            .asMap()
            .entries
            .map((e) => FlSpot(
                  e.key.toDouble(),
                  (e.value['score'] as int).toDouble(),
                ))
            .toList(),
        isCurved: true,
        color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
        barWidth: 3,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            colors: [
              (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                  .withValues(alpha: 0.2),
              (isDark ? const Color(0xFF10B981) : const Color(0xFF059669))
                  .withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
    );

    // Component scores (conditional)
    if (_showComponentScores) {
      // Returns (blue)
      bars.add(_buildComponentBar(chartData, 'returns', Colors.blue, 1.5));
      // Diversification (purple)
      bars.add(_buildComponentBar(chartData, 'diversification', Colors.purple, 1.5));
      // Liquidity (orange)
      bars.add(_buildComponentBar(chartData, 'liquidity', Colors.orange, 1.5));
      // Goals (teal)
      bars.add(_buildComponentBar(chartData, 'goals', Colors.teal, 1.5));
      // Actions (pink)
      bars.add(_buildComponentBar(chartData, 'actions', Colors.pink, 1.5));
    }

    return bars;
  }

  LineChartBarData _buildComponentBar(
    List<Map<String, dynamic>> chartData,
    String key,
    Color color,
    double width,
  ) {
    return LineChartBarData(
      spots: chartData
          .asMap()
          .entries
          .map((e) => FlSpot(
                e.key.toDouble(),
                (e.value[key] as int).toDouble(),
              ))
          .toList(),
      isCurved: true,
      color: color.withValues(alpha: 0.6),
      barWidth: width,
      dotData: const FlDotData(show: false),
    );
  }
}

