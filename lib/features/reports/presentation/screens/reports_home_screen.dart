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

/// Reports home screen
class ReportsHomeScreen extends ConsumerWidget {
  const ReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
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
                  icon: Icons.calendar_view_week_rounded,
                  title: 'Weekly Summary',
                  subtitle: 'This Week',
                  onTap: () => context.push('/reports/weekly'),
                ),
                _buildReportCard(
                  context,
                  icon: Icons.calendar_month_rounded,
                  title: 'Monthly Income',
                  subtitle: 'This Month',
                  onTap: () => context.push('/reports/monthly'),
                ),
                _buildReportCard(
                  context,
                  icon: Icons.calendar_today_rounded,
                  title: 'FY Report',
                  subtitle: 'FY 2023-24',
                  onTap: () => context.push('/reports/fy'),
                ),
                _buildReportCard(
                  context,
                  icon: Icons.trending_up_rounded,
                  title: 'Performance',
                  subtitle: 'Top Performers',
                  onTap: () => context.push('/reports/performance'),
                ),
                _buildReportCard(
                  context,
                  icon: Icons.flag_rounded,
                  title: 'Goals',
                  subtitle: '5 Active Goals',
                  onTap: () => context.push('/reports/goals'),
                ),
                _buildReportCard(
                  context,
                  icon: Icons.event_available_rounded,
                  title: 'Maturity',
                  subtitle: 'Upcoming',
                  onTap: () => context.push('/reports/maturity'),
                ),
                _buildReportCard(
                  context,
                  icon: Icons.notification_important_rounded,
                  title: 'Action Required',
                  subtitle: '3 Items',
                  onTap: () => context.push('/reports/actions'),
                ),
                _buildReportCard(
                  context,
                  icon: Icons.health_and_safety_rounded,
                  title: 'Portfolio Health',
                  subtitle: 'Score: 85/100',
                  onTap: () => context.push('/reports/health'),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // Historical Reports Section
            Text(
              'Historical Reports',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),

            // Placeholder for historical reports
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: Text(
                    'No historical reports yet',
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
    BuildContext context, {
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
