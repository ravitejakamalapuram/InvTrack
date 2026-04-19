/// Goal At-Risk Report Screen
///
/// Warns user about a goal that may not be achieved on time.
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

class GoalAtRiskReportScreen extends ConsumerStatefulWidget {
  final String goalId;

  const GoalAtRiskReportScreen({super.key, required this.goalId});

  @override
  ConsumerState<GoalAtRiskReportScreen> createState() =>
      _GoalAtRiskReportScreenState();
}

class _GoalAtRiskReportScreenState
    extends ConsumerState<GoalAtRiskReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {'report_type': 'goal_at_risk'},
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final goalAsync = ref.watch(watchGoalByIdProvider(widget.goalId));

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.warning_rounded,
        title: l10n.goalAtRisk,
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
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 64,
                        color: AppColors.warningLight,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        l10n.goalAtRiskMessage(goal.name),
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.adjustGoalAdvice,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                SizedBox(height: AppSpacing.lg),

                ReportActionButtons(
                  buttons: [
                    ReportActionButton(
                      label: l10n.adjustGoal,
                      icon: Icons.edit_outlined,
                      onPressed: () {
                        context.go('/goals/${widget.goalId}/edit');
                      },
                    ),
                    ReportActionButton(
                      label: l10n.viewGoalDetails,
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
