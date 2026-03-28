import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_progress.dart';
import 'package:inv_tracker/features/goals/presentation/ui_extensions/goal_type_ui.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_progress_ring.dart';

/// Card widget displaying a goal with its progress
class GoalCard extends ConsumerWidget {
  final GoalEntity goal;
  final VoidCallback onTap;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onLongPress;
  final ValueChanged<bool?>? onCheckboxChanged;

  const GoalCard({
    super.key,
    required this.goal,
    required this.onTap,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onLongPress,
    this.onCheckboxChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use multi-currency provider for accurate progress with mixed currencies (Rule 21.3)
    final progressAsync = ref.watch(multiCurrencyGoalProgressProvider(goal.id));
    final currencySymbol = ref.watch(currencySymbolProvider);
    final locale = ref.watch(currencyLocaleProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.sm),
      child: progressAsync.when(
        data: (progress) => GestureDetector(
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                }
              : null,
          child: GlassCard(
            onTap: isSelectionMode
                ? () => onCheckboxChanged?.call(!isSelected)
                : onTap,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      // Selection checkbox (shown in selection mode)
                      if (isSelectionMode) ...[
                        Checkbox(
                          value: isSelected,
                          onChanged: onCheckboxChanged,
                          activeColor: goal.color,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        SizedBox(width: AppSpacing.xs),
                      ],
                      // Goal icon
                      _buildGoalIcon(goal),
                      SizedBox(width: AppSpacing.md),
                      // Name and details
                      Expanded(
                        child: _buildGoalInfo(
                          context,
                          isDark,
                          progress,
                          currencySymbol,
                          locale,
                          isPrivacyMode,
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      // Progress ring - wrap in PrivacyMask
                      PrivacyMask(
                        useTextMask: true,
                        maskedText: '••%',
                        child: GoalProgressRing(
                          progress: progress?.progressPercent ?? 0,
                          size: 56,
                          color: goal.color,
                          strokeWidth: 5,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bottom strip with status
                _buildBottomStrip(context, isDark, progress),
              ],
            ),
          ),
        ),
        loading: () => GestureDetector(
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                }
              : null,
          child: GlassCard(
            onTap: isSelectionMode
                ? () => onCheckboxChanged?.call(!isSelected)
                : onTap,
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 120,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? Colors.white54 : AppColors.neutral400Light,
                ),
              ),
            ),
          ),
        ),
        error: (error, _) => GestureDetector(
          onLongPress: onLongPress != null
              ? () {
                  HapticFeedback.mediumImpact();
                  onLongPress!();
                }
              : null,
          child: GlassCard(
            onTap: isSelectionMode
                ? () => onCheckboxChanged?.call(!isSelected)
                : onTap,
            padding: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  if (isSelectionMode) ...[
                    Checkbox(
                      value: isSelected,
                      onChanged: onCheckboxChanged,
                      activeColor: goal.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: AppSpacing.xs),
                  ],
                  _buildGoalIcon(goal),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          style: AppTypography.h4.copyWith(
                            color: isDark
                                ? Colors.white
                                : AppColors.neutral900Light,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppSpacing.xxs),
                        Text(
                          'Error loading progress',
                          style: AppTypography.small.copyWith(
                            color: AppColors.errorLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoalIcon(GoalEntity goal) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [goal.color, goal.color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: goal.color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(goal.icon, style: const TextStyle(fontSize: 24)),
      ),
    );
  }

  Widget _buildGoalInfo(
    BuildContext context,
    bool isDark,
    GoalProgress? progress,
    String currencySymbol,
    String locale,
    bool isPrivacyMode,
  ) {
    final progressTextStyle = AppTypography.small.copyWith(
      color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
    );
    final progressText =
        progress?.getProgressMessage(currencySymbol, locale) ??
        'Calculating...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          goal.name,
          style: AppTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppColors.neutral900Light,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SizedBox(height: AppSpacing.xxs),
        isPrivacyMode
            ? MaskedAmountText(text: progressText, style: progressTextStyle)
            : Text(progressText, style: progressTextStyle),
      ],
    );
  }

  Widget _buildBottomStrip(
    BuildContext context,
    bool isDark,
    GoalProgress? progress,
  ) {
    final status = progress?.status ?? GoalStatus.notStarted;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // Status indicator
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 6),
          Text(
            status.displayName,
            style: AppTypography.small.copyWith(
              color: status.color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Status message
          Flexible(
            child: Text(
              progress?.statusMessage ?? '',
              style: AppTypography.small.copyWith(
                color: isDark
                    ? AppColors.neutral400Dark
                    : AppColors.neutral500Light,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
