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
        subtitle: l10n.daysSinceActivity(widget.daysSinceActivity),
      ),
      body: goalAsync.when(
        data: (goal) {
          if (goal == null) {
            return Center(child: Text(l10n.goalNotFound));
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
                        l10n.noActivityInDays(widget.daysSinceActivity),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.warningLight,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Container(
                        padding: EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppColors.primaryLight),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                l10n.keepGoalActiveAdvice,
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
                      label: l10n.addFunds,
                      icon: Icons.add_circle_outline,
                      onPressed: () {
                        context.go('/investments');
                      },
                    ),
                    ReportActionButton(
                      label: l10n.viewGoal,
                      icon: Icons.visibility_outlined,
                      isPrimary: false,
                      onPressed: () {
                        context.go('/goals/${widget.goalId}');
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text(l10n.errorGeneric(error.toString()))),
      ),
    );
  }
}
