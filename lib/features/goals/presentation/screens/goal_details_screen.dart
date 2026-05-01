import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/router/navigation_extensions.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/utils/date_utils.dart';
import 'package:inv_tracker/core/widgets/compact_amount_text.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/goals/presentation/screens/create_goal_screen.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_progress_ring.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Screen displaying detailed goal information
class GoalDetailsScreen extends ConsumerWidget {
  final String goalId;

  const GoalDetailsScreen({super.key, required this.goalId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final goalAsync = ref.watch(watchGoalByIdProvider(goalId));

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: goalAsync.when(
        data: (goal) {
          if (goal == null) {
            return _buildNotFound(context, isDark);
          }
          return _buildContent(context, ref, goal, isDark);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildError(context, isDark, error),
      ),
    );
  }

  Widget _buildNotFound(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: AppColors.neutral400Dark,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Goal not found',
            style: AppTypography.h3.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => context.safePop(),
            child: Text(l10n.goBack),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, bool isDark, Object error) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.errorLight,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Failed to load goal',
            style: AppTypography.h3.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => context.safePop(),
            child: Text(l10n.goBack),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    GoalEntity goal,
    bool isDark,
  ) {
    // Use multi-currency provider for accurate progress with mixed currencies (Rule 21.3)
    final progressAsync = ref.watch(multiCurrencyGoalProgressProvider(goal.id));
    final currencySymbol = ref.watch(currencySymbolProvider);
    final locale = ref.watch(currencyLocaleProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return progressAsync.when(
      data: (progress) => CustomScrollView(
        slivers: [
          _buildAppBar(context, ref, goal, isDark),
          SliverPadding(
            padding: EdgeInsets.all(AppSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProgressSection(
                  context,
                  goal,
                  progress,
                  isDark,
                  currencySymbol,
                  isPrivacyMode,
                  locale,
                ),
                SizedBox(height: AppSpacing.lg),
                _buildDetailsSection(
                  context,
                  goal,
                  isDark,
                  currencySymbol,
                  isPrivacyMode,
                  locale,
                ),
                SizedBox(height: AppSpacing.lg),
                _buildMilestonesSection(context, progress, isDark),
                SizedBox(height: AppSpacing.lg),
                _buildActionsSection(context, ref, goal, isDark),
                SizedBox(height: AppSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _buildError(context, isDark, error),
    );
  }

  SliverAppBar _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    GoalEntity goal,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context);
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      leading: IconButton(
        tooltip: l10n.tooltipBack,
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.safePop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          tooltip: l10n.tooltipEditGoal,
          onPressed: () => _navigateToEdit(context, goal),
        ),
        PopupMenuButton<String>(
          onSelected: (value) => _handleMenuAction(context, ref, goal, value),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: goal.isArchived ? 'unarchive' : 'archive',
              child: Row(
                children: [
                  Icon(
                    goal.isArchived
                        ? Icons.unarchive_rounded
                        : Icons.archive_rounded,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Text(goal.isArchived ? l10n.unarchive : l10n.archive),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: EdgeInsets.only(left: 56, bottom: 16, right: 56),
        title: Row(
          children: [
            Text(goal.icon, style: const TextStyle(fontSize: 24)),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                goal.name,
                style: AppTypography.h3.copyWith(
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                  fontSize: 18,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection(
    BuildContext context,
    GoalEntity goal,
    GoalProgress? progress,
    bool isDark,
    String currencySymbol,
    bool isPrivacyMode,
    String locale,
  ) {
    final percent = progress?.progressPercent ?? 0;
    final progressText =
        progress?.getProgressMessage(currencySymbol, locale) ??
        'Calculating...';
    final progressTextStyle = AppTypography.bodyLarge.copyWith(
      color: isDark ? Colors.white : AppColors.neutral900Light,
      fontWeight: FontWeight.w600,
    );

    return GlassCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          // Wrap progress ring in PrivacyMask
          PrivacyMask(
            useTextMask: true,
            maskedText: '••%',
            child: GoalProgressRing(
              progress: percent,
              size: 140,
              color: goal.color,
              strokeWidth: 12,
              showPercentage: true,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          isPrivacyMode
              ? MaskedAmountText(
                  text: progressText,
                  style: progressTextStyle,
                  textAlign: TextAlign.center,
                )
              : Text(
                  progressText,
                  style: progressTextStyle,
                  textAlign: TextAlign.center,
                ),
          SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                progress?.status.icon ?? Icons.hourglass_empty,
                size: 16,
                color: progress?.status.color ?? Colors.grey,
              ),
              SizedBox(width: 4),
              Text(
                progress?.status.displayName ?? 'Not Started',
                style: AppTypography.bodyMedium.copyWith(
                  color: progress?.status.color ?? Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (progress?.statusMessage != null) ...[
            SizedBox(height: AppSpacing.xs),
            Text(
              progress!.statusMessage,
              style: AppTypography.small.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailsSection(
    BuildContext context,
    GoalEntity goal,
    bool isDark,
    String currencySymbol,
    bool isPrivacyMode,
    String locale,
  ) {
    return GlassCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Details',
            style: AppTypography.h4.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          _buildDetailRow('Type', goal.type.displayName, isDark),
          _buildAmountDetailRow(
            'Target',
            goal.targetAmount,
            currencySymbol,
            isDark,
            isPrivacyMode: isPrivacyMode,
            locale: locale,
          ),
          if (goal.targetMonthlyIncome != null)
            _buildAmountDetailRow(
              'Monthly Income Target',
              goal.targetMonthlyIncome!,
              currencySymbol,
              isDark,
              suffix: '/mo',
              isPrivacyMode: isPrivacyMode,
              locale: locale,
            ),
          if (goal.targetDate != null)
            _buildDetailRow(
              'Target Date',
              AppDateUtils.formatShort(goal.targetDate!),
              isDark,
            ),
          _buildDetailRow('Tracking', goal.trackingMode.displayName, isDark),
          _buildDetailRow(
            'Created',
            AppDateUtils.formatShort(goal.createdAt),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDetailRow(
    String label,
    double amount,
    String currencySymbol,
    bool isDark, {
    String? suffix,
    bool isPrivacyMode = false,
    String locale = 'en_US',
  }) {
    final compactText = formatCompactCurrency(
      amount,
      symbol: currencySymbol,
      locale: locale,
    );
    final valueStyle = AppTypography.bodyMedium.copyWith(
      color: isDark ? Colors.white : AppColors.neutral900Light,
      fontWeight: FontWeight.w500,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isPrivacyMode
                  ? MaskedAmountText(text: compactText, style: valueStyle)
                  : CompactAmountText(
                      amount: amount,
                      compactText: compactText,
                      currencySymbol: currencySymbol,
                      style: valueStyle,
                    ),
              if (suffix != null) Text(suffix, style: valueStyle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMilestonesSection(
    BuildContext context,
    GoalProgress? progress,
    bool isDark,
  ) {
    final milestones = progress?.achievedMilestones ?? [];
    return GlassCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Milestones',
            style: AppTypography.h4.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
          ),
          SizedBox(height: AppSpacing.md),
          if (milestones.isEmpty)
            Text(
              'No milestones reached yet',
              style: AppTypography.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
            )
          else
            ...GoalMilestone.values.where((m) => m != GoalMilestone.start).map((
              milestone,
            ) {
              final achieved = milestones.contains(milestone);
              return Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(
                      achieved
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: achieved
                          ? AppColors.successLight
                          : AppColors.neutral400Dark,
                      size: 20,
                    ),
                    SizedBox(width: AppSpacing.sm),
                    Text(milestone.emoji, style: const TextStyle(fontSize: 16)),
                    SizedBox(width: AppSpacing.xs),
                    Text(
                      milestone.displayName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: achieved
                            ? (isDark
                                  ? Colors.white
                                  : AppColors.neutral900Light)
                            : AppColors.neutral400Dark,
                        fontWeight: achieved
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildActionsSection(
    BuildContext context,
    WidgetRef ref,
    GoalEntity goal,
    bool isDark,
  ) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => _navigateToEdit(context, goal),
          icon: const Icon(Icons.edit_rounded),
          label: Text(l10n.editGoal),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          onPressed: () => _handleArchiveToggle(context, ref, goal),
          icon: Icon(
            goal.isArchived ? Icons.unarchive_rounded : Icons.archive_rounded,
          ),
          label: Text(goal.isArchived ? l10n.unarchiveGoal : l10n.archiveGoal),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
          ),
        ),
      ],
    );
  }

  void _navigateToEdit(BuildContext context, GoalEntity goal) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateGoalScreen(goalToEdit: goal),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    GoalEntity goal,
    String action,
  ) {
    switch (action) {
      case 'archive':
      case 'unarchive':
        _handleArchiveToggle(context, ref, goal);
        break;
      case 'delete':
        _confirmDelete(context, ref, goal);
        break;
    }
  }

  Future<void> _handleArchiveToggle(
    BuildContext context,
    WidgetRef ref,
    GoalEntity goal,
  ) async {
    HapticFeedback.lightImpact();
    try {
      if (goal.isArchived) {
        await ref.read(goalNotifierProvider.notifier).unarchiveGoal(goal.id);
        if (context.mounted) {
          AppFeedback.showSuccess(context, 'Goal restored');
        }
      } else {
        await ref.read(goalNotifierProvider.notifier).archiveGoal(goal.id);
        if (context.mounted) {
          AppFeedback.showSuccess(context, 'Goal archived');
          context.safePop();
        }
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, 'Failed to update goal');
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    GoalEntity goal,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteGoal),
        content: Text(
          'Are you sure you want to permanently delete "${goal.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      HapticFeedback.mediumImpact();
      try {
        final notifier = ref.read(goalNotifierProvider.notifier);
        if (goal.isArchived) {
          await notifier.deleteArchivedGoal(goal.id);
        } else {
          await notifier.deleteGoal(goal.id);
        }
        if (context.mounted) {
          AppFeedback.showSuccess(context, 'Goal deleted');
          context.safePop();
        }
      } catch (e) {
        if (context.mounted) {
          AppFeedback.showError(context, 'Failed to delete goal');
        }
      }
    }
  }
}
