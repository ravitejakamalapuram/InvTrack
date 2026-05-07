/// Reports home screen
///
/// Main entry point for the Reports section, showing:
/// - Quick reports (Weekly, Monthly, FY)
/// - All reports grid
/// - Historical reports list
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/reports/domain/entities/report_configuration.dart';
import 'package:inv_tracker/features/reports/presentation/providers/action_required_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/historical_reports_list.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';

/// Reports home screen
class ReportsHomeScreen extends ConsumerWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Watch dynamic counts for report cards
    final activeGoalsAsync = ref.watch(activeGoalsProvider);
    final actionRequiredAsync = ref.watch(actionRequiredReportProvider);
    final portfolioHealthAsync = ref.watch(portfolioHealthProvider);

    // Extract counts with defaults
    final activeGoalsCount = activeGoalsAsync.maybeWhen(
      data: (goals) => goals.length,
      orElse: () => 0,
    );

    final actionItemsCount = actionRequiredAsync.maybeWhen(
      data: (report) => report.totalActions,
      orElse: () => 0,
    );

    final healthScore = portfolioHealthAsync.maybeWhen(
      data: (health) => health?.overallScore.round() ?? 0,
      orElse: () => 0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quick Reports Section
            Text(
              l10n.quickReports,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),

            // Report cards grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 1.2,
              children: [
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.calendar_view_week_rounded,
                  title: l10n.weeklySummary,
                  subtitle: l10n.thisWeek,
                  onTap: () => _navigateToReport(
                    context,
                    ReportConfiguration.weeklySummary(),
                  ),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.calendar_month_rounded,
                  title: l10n.monthlyIncome,
                  subtitle: l10n.thisMonth,
                  onTap: () => _navigateToReport(
                    context,
                    ReportConfiguration.monthlyIncome(),
                  ),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.calendar_today_rounded,
                  title: l10n.fyReport,
                  subtitle: l10n.currentFY('2023', '24'),
                  onTap: () => _navigateToReport(
                    context,
                    ReportConfiguration.fyReport(),
                  ),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.trending_up_rounded,
                  title: l10n.performance,
                  subtitle: l10n.topPerformers,
                  onTap: () => _navigateToReport(
                    context,
                    ReportConfiguration.performance(),
                  ),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.flag_rounded,
                  title: l10n.goals,
                  subtitle: l10n.activeGoalsCount(activeGoalsCount),
                  onTap: () => _navigateToReport(
                    context,
                    ReportConfiguration.goalProgress(),
                  ),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.event_available_rounded,
                  title: l10n.maturity,
                  subtitle: l10n.upcoming,
                  onTap: () => _navigateToReport(
                    context,
                    ReportConfiguration.maturityCalendar(),
                  ),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.notification_important_rounded,
                  title: l10n.actionRequired,
                  subtitle: l10n.actionItemsCount(actionItemsCount),
                  onTap: () => _navigateToReport(
                    context,
                    ReportConfiguration.actionRequired(),
                  ),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.health_and_safety_rounded,
                  title: l10n.portfolioHealth,
                  subtitle: l10n.healthScore(healthScore),
                  onTap: () => _navigateToReport(
                    context,
                    ReportConfiguration.portfolioHealth(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Historical Reports Section
            Text(
              l10n.historicalReports,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),

            // Historical reports list
            const HistoricalReportsList(),
          ],
        ),
      ),
    );
  }

  /// Navigate to dynamic report screen with configuration
  void _navigateToReport(BuildContext context, ReportConfiguration config) {
    final queryParams = config.toQueryParams();
    final uri = Uri(path: '/reports/builder', queryParameters: queryParams);
    context.push(uri.toString());
  }

  Widget _buildReportCard(
    BuildContext context,
    AppLocalizations l10n, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
