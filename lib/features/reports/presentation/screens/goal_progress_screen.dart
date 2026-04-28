/// Goal Progress Report Screen
///
/// Shows progress tracking for all financial goals including:
/// - On-track vs at-risk goals
/// - Achievement status
/// - Progress percentages
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/reports/domain/entities/goal_progress_report.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';
import 'package:inv_tracker/features/reports/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/base_report_screen.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_stat_card.dart';
import 'package:inv_tracker/features/reports/presentation/widgets/report_export_button.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class GoalProgressScreen extends BaseReportScreen<GoalProgressReport> {
  const GoalProgressScreen({super.key});

  @override
  String getTitle(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return l10n.goalProgressTitle;
  }

  @override
  FutureProvider<GoalProgressReport> getDataProvider(WidgetRef ref) {
    return goalProgressReportProvider;
  }

  @override
  List<Widget> buildActions(BuildContext context, WidgetRef ref, GoalProgressReport data) {
    return [
      ReportExportButton(
        reportData: data,
        reportType: ReportType.goalProgress,
      ),
    ];
  }

  @override
  Widget buildContent(BuildContext context, WidgetRef ref, GoalProgressReport report) {
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(currencyLocaleProvider);
    final symbol = ref.watch(currencySymbolProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Stats
        Text(
          l10n.goalsOverview,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ReportStatCard(
                icon: Icons.flag_rounded,
                label: l10n.totalGoals,
                value: '${report.totalGoals}',
                iconColor: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ReportStatCard(
                icon: Icons.trending_up_rounded,
                label: l10n.avgProgress,
                value: '${report.averageProgress.toStringAsFixed(1)}%',
                iconColor: Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ReportStatCard(
                icon: Icons.check_circle_rounded,
                label: l10n.onTrack,
                value: '${report.onTrackGoals.length}',
                iconColor: Colors.green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ReportStatCard(
                icon: Icons.warning_rounded,
                label: l10n.atRisk,
                value: '${report.atRiskGoals.length}',
                iconColor: Colors.orange,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Achieved Goals
        if (report.achievedGoals.isNotEmpty) ...[
          _buildAchievedGoals(context, report, symbol, locale),
          const SizedBox(height: 24),
        ],

        // On Track Goals
        if (report.onTrackGoals.isNotEmpty) ...[
          _buildOnTrackGoals(context, report, symbol, locale),
          const SizedBox(height: 24),
        ],

        // At Risk Goals
        if (report.atRiskGoals.isNotEmpty) ...[
          _buildAtRiskGoals(context, report, symbol, locale),
        ],
      ],
    );
  }

  Widget _buildAchievedGoals(
    BuildContext context,
    GoalProgressReport report,
    String symbol,
    String locale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🎉 Achieved Goals',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...report.achievedGoals.map((goalWithProgress) {
          final goal = goalWithProgress.goal;
          final progress = goalWithProgress.progress;
          return Card(
            child: ListTile(
              leading: Text(goal.icon, style: const TextStyle(fontSize: 32)),
              title: Text(goal.name),
              subtitle: Text('${l10n.targetLabel}: ${formatCompactCurrency(goal.targetAmount, symbol: symbol, locale: locale)}'),
              trailing: PrivacyMask(
                child: Text(
                  '${progress.progressPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildOnTrackGoals(
    BuildContext context,
    GoalProgressReport report,
    String symbol,
    String locale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '✅ On Track Goals',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...report.onTrackGoals.map((goalWithProgress) {
          final goal = goalWithProgress.goal;
          final progress = goalWithProgress.progress;
          return Card(
            child: ListTile(
              leading: Text(goal.icon, style: const TextStyle(fontSize: 32)),
              title: Text(goal.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l10n.targetLabel}: ${formatCompactCurrency(goal.targetAmount, symbol: symbol, locale: locale)}'),
                  LinearProgressIndicator(
                    value: progress.progressPercent / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ],
              ),
              trailing: PrivacyMask(
                child: Text(
                  '${progress.progressPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAtRiskGoals(
    BuildContext context,
    GoalProgressReport report,
    String symbol,
    String locale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '⚠️ At Risk Goals',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        ...report.atRiskGoals.map((goalWithProgress) {
          final goal = goalWithProgress.goal;
          final progress = goalWithProgress.progress;
          return Card(
            color: Colors.orange[50],
            child: ListTile(
              leading: Text(goal.icon, style: const TextStyle(fontSize: 32)),
              title: Text(goal.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${l10n.targetLabel}: ${formatCompactCurrency(goal.targetAmount, symbol: symbol, locale: locale)}'),
                  Text(
                    progress.statusMessage,
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontSize: 12,
                    ),
                  ),
                  LinearProgressIndicator(
                    value: progress.progressPercent / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ],
              ),
              trailing: PrivacyMask(
                child: Text(
                  '${progress.progressPercent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
