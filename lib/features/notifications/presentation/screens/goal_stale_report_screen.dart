/// Goal Stale Report Screen
///
/// Notifies user about a goal with no recent progress.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_action_button.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class GoalStaleReportScreen extends ConsumerStatefulWidget {
  final String goalId;
  final int daysSinceActivity;

  const GoalStaleReportScreen({
    super.key,
    required this.goalId,
    required this.daysSinceActivity,
  });

  @override
  ConsumerState<GoalStaleReportScreen> createState() =>
      _GoalStaleReportScreenState();
}

class _GoalStaleReportScreenState
    extends ConsumerState<GoalStaleReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {
          'report_type': 'goal_stale',
          'days_since_activity': widget.daysSinceActivity,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final goalAsync = ref.watch(watchGoalByIdProvider(widget.goalId));

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.schedule_rounded,
        title: l10n.goalInactive,
        subtitle: '${widget.daysSinceActivity} days since activity',
      ),
      body: goalAsync.when(
        data: (goal) {
          if (goal == null) {
            return const Center(child: Text('Goal not found'));
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: AppSpacing.lg),

                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Text(
                        goal.icon,
                        style: const TextStyle(fontSize: 64),
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        goal.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        'No activity in ${widget.daysSinceActivity} days',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.warningLight,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Container(
                        padding: EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.infoLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppColors.infoLight),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Keep your goal active by adding funds or adjusting your target.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppSpacing.lg),

                ReportActionButtons(
                  buttons: [
                    ReportActionButton(
                      label: 'Add Funds',
                      icon: Icons.add_circle_outline,
                      onPressed: () {
                        context.pop();
                        context.push('/investments');
                      },
                    ),
                    ReportActionButton(
                      label: 'View Goal',
                      icon: Icons.visibility_outlined,
                      isPrimary: false,
                      onPressed: () {
                        context.pop();
                        context.push('/goals/${widget.goalId}');
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
