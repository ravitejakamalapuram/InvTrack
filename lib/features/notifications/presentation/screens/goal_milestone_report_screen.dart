/// Goal Milestone Report Screen
///
/// Displays a congratulatory report when a goal milestone is achieved.
/// Shown when user taps the "Goal Milestone" notification.
///
/// ## Data Displayed
/// - Circular progress indicator (visual milestone)
/// - Milestone badge (25%, 50%, 75%, 100%)
/// - Current amount vs target amount
/// - Goal details (name, icon, target date)
/// - Congratulatory message
/// - Next milestone projection
///
/// ## Actions
/// - Add More Funds
/// - View Goal Details
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_header.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_metric_card.dart';
import 'package:inv_tracker/features/notifications/presentation/widgets/report_action_button.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

class GoalMilestoneReportScreen extends ConsumerStatefulWidget {
  final String goalId;
  final int milestonePercent;

  const GoalMilestoneReportScreen({
    super.key,
    required this.goalId,
    required this.milestonePercent,
  });

  @override
  ConsumerState<GoalMilestoneReportScreen> createState() =>
      _GoalMilestoneReportScreenState();
}

class _GoalMilestoneReportScreenState
    extends ConsumerState<GoalMilestoneReportScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(analyticsServiceProvider).logEvent(
        name: 'notification_report_viewed',
        parameters: {
          'report_type': 'goal_milestone',
          'milestone_percent': widget.milestonePercent,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final goalAsync = ref.watch(watchGoalByIdProvider(widget.goalId));
    final progressAsync = ref.watch(goalProgressProvider(widget.goalId));

    return Scaffold(
      appBar: ReportHeader(
        icon: Icons.flag_rounded,
        title: l10n.goalMilestone,
        subtitle: l10n.percentComplete(widget.milestonePercent),
      ),
      body: goalAsync.when(
        data: (goal) {
          if (goal == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: AppColors.errorLight,
                  ),
                  SizedBox(height: AppSpacing.md),
                  Text(
                    l10n.goalNotFound,
                    style: AppTypography.h3,
                  ),
                ],
              ),
            );
          }

          if (progressAsync == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildContent(context, goal, progressAsync, l10n);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text(l10n.errorLoadingGoal),
        ),
      ),
    );
  }

  /// Get next milestone percentage (or null if complete)
  int? _getNextMilestone(int currentMilestone) {
    const milestones = [25, 50, 75, 100];
    for (final milestone in milestones) {
      if (milestone > currentMilestone) {
        return milestone;
      }
    }
    return null; // Already at 100%
  }

  Widget _buildContent(
    BuildContext context,
    dynamic goal,
    dynamic progress,
    AppLocalizations l10n,
  ) {
    final currencySymbol = ref.watch(currencySymbolProvider);
    final currencyLocale = ref.watch(currencyLocaleProvider);

    // Format amounts with locale-aware formatting (Rule 16.5)
    final currentAmountFormatted = formatCompactCurrency(
      progress.currentAmount,
      symbol: currencySymbol,
      locale: currencyLocale,
    );
    final targetAmountFormatted = formatCompactCurrency(
      goal.targetAmount,
      symbol: currencySymbol,
      locale: currencyLocale,
    );

    // Calculate next milestone
    final nextMilestone = _getNextMilestone(widget.milestonePercent);
    final isGoalComplete = widget.milestonePercent >= 100;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: AppSpacing.lg),

          // Congratulatory Message
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              isGoalComplete
                  ? '🎉 Congratulations! Goal Achieved!'
                  : '🎉 Milestone Reached!',
              style: AppTypography.h1.copyWith(
                color: AppColors.successLight,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: AppSpacing.sm),

          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              isGoalComplete
                  ? 'You\'ve reached your ${goal.name} goal!'
                  : 'You\'ve reached ${widget.milestonePercent}% of your ${goal.name} goal!',
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),

          SizedBox(height: AppSpacing.xl),

          // Circular Progress Indicator
          _buildCircularProgress(progress.progressPercent, goal.icon),

          SizedBox(height: AppSpacing.xl),

          // Key Metrics
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: ReportMetricCard(
                    label: 'Current Amount',
                    value: currentAmountFormatted,
                    icon: Icons.account_balance_wallet_outlined,
                    accentColor: AppColors.successLight,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ReportMetricCard(
                    label: 'Target Amount',
                    value: targetAmountFormatted,
                    icon: Icons.flag_outlined,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: AppSpacing.md),

          // Next Milestone Info (if not complete)
          if (!isGoalComplete && nextMilestone != null)
            _buildNextMilestoneCard(
              nextMilestone,
              progress,
              goal,
              currencySymbol,
              currencyLocale,
            ),

          SizedBox(height: AppSpacing.lg),

          // Action Buttons
          ReportActionButtons(
            buttons: [
              if (!isGoalComplete)
                ReportActionButton(
                  label: l10n.addMoreFunds,
                  icon: Icons.add_circle_outline,
                  onPressed: () {
                    // Navigate to add cashflow (linked to goal's investments)
                    context.pop();
                    context.push('/investments');
                  },
                ),
              ReportActionButton(
                label: l10n.viewGoalDetails,
                icon: Icons.visibility_outlined,
                isPrimary: isGoalComplete,
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
  }

  /// Build circular progress indicator with milestone
  Widget _buildCircularProgress(double progressPercent, String icon) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: 12,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.neutral700Dark
                  : AppColors.neutral200Light,
              color: Colors.transparent,
            ),
          ),
          // Progress circle with gradient
          SizedBox(
            width: 200,
            height: 200,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progressPercent / 100),
              duration: const Duration(milliseconds: 1500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 12,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _getMilestoneColor(widget.milestonePercent),
                  ),
                );
              },
            ),
          ),
          // Center content
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Goal icon
              Text(
                icon,
                style: const TextStyle(fontSize: 48),
              ),
              SizedBox(height: AppSpacing.xs),
              // Percentage
              Text(
                '${widget.milestonePercent}%',
                style: AppTypography.h1.copyWith(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _getMilestoneColor(widget.milestonePercent),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build next milestone card
  Widget _buildNextMilestoneCard(
    int nextMilestone,
    dynamic progress,
    dynamic goal,
    String currencySymbol,
    String currencyLocale,
  ) {
    final amountNeeded = goal.targetAmount *
        (nextMilestone / 100) -
        progress.currentAmount;

    final amountNeededFormatted = formatCompactCurrency(
      amountNeeded,
      symbol: currencySymbol,
      locale: currencyLocale,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primaryLight.withValues(alpha: 0.1),
          borderRadius: AppSizes.borderRadiusMd,
          border: Border.all(
            color: AppColors.primaryLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.trending_up_rounded,
              size: 32,
              color: AppColors.primaryLight,
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Milestone: $nextMilestone%',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.neutral200Light
                          : AppColors.neutral900Light,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    '$amountNeededFormatted more needed',
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral600Light,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get color for milestone percentage
  Color _getMilestoneColor(int milestonePercent) {
    if (milestonePercent >= 100) return AppColors.successLight;
    if (milestonePercent >= 75) return AppColors.successLight;
    if (milestonePercent >= 50) return AppColors.primaryLight;
    return AppColors.primaryLight;
  }
}
