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
import 'package:inv_tracker/features/reports/presentation/providers/smart_insights_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/historical_reports_list.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/smart_insight_card.dart';
import 'package:inv_tracker/features/portfolio_health/presentation/providers/portfolio_health_provider.dart';

/// Reports home screen
class ReportsHomeScreen extends ConsumerWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // Watch smart insights (pass l10n for localization)
    final smartInsightsAsync = ref.watch(smartInsightsProvider(l10n));
    final priorityInsightsAsync = ref.watch(priorityInsightsProvider(l10n));

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
            // Smart Insights Section
            Text(
              l10n.smartInsights,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Smart Insights Cards
            smartInsightsAsync.when(
              data: (insights) {
                if (insights.isEmpty) {
                  return GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        children: [
                          Icon(
                            Icons.insights_outlined,
                            size: 48,
                            color: Theme.of(context).disabledColor,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            l10n.startTrackingToSeeReports,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: insights.take(3).map((insight) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: SmartInsightCard(insight: insight),
                  )).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Needs Attention Section (Priority Insights)
            priorityInsightsAsync.when(
              data: (priorityInsights) {
                if (priorityInsights.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 20,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          l10n.needsAttention,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${priorityInsights.length}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...priorityInsights.map((insight) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: SmartInsightCard(insight: insight),
                    )),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (error, stackTrace) => const SizedBox.shrink(),
            ),

            // Quick Reports Section with Create Custom Report Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.quickReports,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton.tonalIcon(
                  onPressed: () => context.push('/reports/builder'),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: Text(l10n.createReport),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ],
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
