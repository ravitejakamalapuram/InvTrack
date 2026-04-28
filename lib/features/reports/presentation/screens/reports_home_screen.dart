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

/// Reports home screen
class ReportsHomeScreen extends ConsumerWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

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
              'Quick Reports',
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
                  onTap: () => context.push('/reports/weekly'),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.calendar_month_rounded,
                  title: l10n.monthlyIncome,
                  subtitle: l10n.thisMonth,
                  onTap: () => context.push('/reports/monthly'),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.calendar_today_rounded,
                  title: l10n.fyReport,
                  subtitle: 'FY 2023-24',
                  onTap: () => context.push('/reports/fy'),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.trending_up_rounded,
                  title: l10n.performance,
                  subtitle: l10n.topPerformers,
                  onTap: () => context.push('/reports/performance'),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.flag_rounded,
                  title: l10n.goals,
                  subtitle: '5 Active Goals',
                  onTap: () => context.push('/reports/goals'),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.event_available_rounded,
                  title: l10n.maturity,
                  subtitle: l10n.upcoming,
                  onTap: () => context.push('/reports/maturity'),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.notification_important_rounded,
                  title: l10n.actionRequired,
                  subtitle: '3 Items',
                  onTap: () => context.push('/reports/actions'),
                ),
                _buildReportCard(
                  context,
                  l10n,
                  icon: Icons.health_and_safety_rounded,
                  title: l10n.portfolioHealth,
                  subtitle: 'Score: 85/100',
                  onTap: () => context.push('/reports/health'),
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

            // Placeholder for historical reports
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: Text(
                    l10n.noHistoricalReportsYet,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
