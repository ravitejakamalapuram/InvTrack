/// Portfolio Health Screen
///
/// Shows portfolio health assessment
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/reports/domain/entities/portfolio_health_report.dart';
import 'package:inv_tracker/features/reports/presentation/providers/portfolio_health_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/base_report_screen.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_stat_card.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/ui_extensions/investment_ui.dart';

class PortfolioHealthScreen extends BaseReportScreen<PortfolioHealthReport> {
  const PortfolioHealthScreen({super.key});

  @override
  String getTitle(BuildContext context) {
    return 'Portfolio Health';
  }

  @override
  FutureProvider<PortfolioHealthReport> getDataProvider(WidgetRef ref) {
    return portfolioHealthReportProvider;
  }

  @override
  Widget buildContent(
    BuildContext context,
    WidgetRef ref,
    PortfolioHealthReport report,
  ) {
    final currencySymbol = ref.watch(currencySymbolProvider);
    final locale = ref.watch(currencyLocaleProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overall Health Score
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  report.overallScore.emoji,
                  style: const TextStyle(fontSize: 64),
                ),
                const SizedBox(height: 12),
                Text(
                  '${report.scoreValue}/100',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  report.overallScore.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Health Metrics
        Row(
          children: [
            Expanded(
              child: ReportStatCard(
                icon: Icons.donut_small_rounded,
                label: 'Diversification',
                value: '${report.diversificationScore.toStringAsFixed(0)}%',
                iconColor: _getScoreColor(report.diversificationScore),
                isPrivacySensitive: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ReportStatCard(
                icon: Icons.trending_up_rounded,
                label: 'Performance',
                value: '${report.performanceScore.toStringAsFixed(0)}%',
                iconColor: _getScoreColor(report.performanceScore),
                isPrivacySensitive: false,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ReportStatCard(
                icon: Icons.local_activity_rounded,
                label: 'Activity',
                value: '${report.activityScore.toStringAsFixed(0)}%',
                iconColor: _getScoreColor(report.activityScore),
                isPrivacySensitive: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ReportStatCard(
                icon: Icons.pie_chart_rounded,
                label: 'Types',
                value: '${report.typeCount}',
                iconColor: Colors.blue,
                isPrivacySensitive: false,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Diversification Breakdown
        if (report.diversification.isNotEmpty) ...[
          Text(
            '📊 Diversification Breakdown',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...report.diversification.map((item) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  item.type.icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                title: Text(item.type.displayName),
                subtitle: Text('${item.count} investments'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.percentage.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      formatCompactCurrency(
                        item.amount,
                        symbol: currencySymbol,
                        locale: locale,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],

        // Risk Distribution
        Text(
          '⚖️ Risk Distribution',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _buildRiskCard(
          context,
          'Low Risk',
          report.riskDistribution.lowRiskPercentage,
          report.riskDistribution.lowRiskAmount,
          Colors.green,
          currencySymbol,
          locale,
        ),
        _buildRiskCard(
          context,
          'Medium Risk',
          report.riskDistribution.mediumRiskPercentage,
          report.riskDistribution.mediumRiskAmount,
          Colors.amber,
          currencySymbol,
          locale,
        ),
        _buildRiskCard(
          context,
          'High Risk',
          report.riskDistribution.highRiskPercentage,
          report.riskDistribution.highRiskAmount,
          Colors.red,
          currencySymbol,
          locale,
        ),

        const SizedBox(height: 24),

        // Recommendations
        if (report.recommendations.isNotEmpty) ...[
          Text(
            '💡 Recommendations',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          ...report.recommendations.map((rec) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(
                  _getRecommendationIcon(rec.priority),
                  color: _getRecommendationColor(rec.priority),
                  size: 32,
                ),
                title: Text(rec.title),
                subtitle: Text(rec.description),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildRiskCard(
    BuildContext context,
    String label,
    double percentage,
    double amount,
    Color color,
    String currencySymbol,
    String locale,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: percentage / 100,
                    backgroundColor: color.withValues(alpha: 0.2),
                    color: color,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${percentage.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: color),
                ),
                Text(
                  formatCompactCurrency(amount, symbol: currencySymbol, locale: locale),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.amber;
    return Colors.red;
  }

  IconData _getRecommendationIcon(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.high:
        return Icons.priority_high_rounded;
      case RecommendationPriority.medium:
        return Icons.info_rounded;
      case RecommendationPriority.low:
        return Icons.lightbulb_rounded;
    }
  }

  Color _getRecommendationColor(RecommendationPriority priority) {
    switch (priority) {
      case RecommendationPriority.high:
        return Colors.red;
      case RecommendationPriority.medium:
        return Colors.orange;
      case RecommendationPriority.low:
        return Colors.blue;
    }
  }
}
