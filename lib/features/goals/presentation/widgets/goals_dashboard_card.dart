/// Goals dashboard card for the overview screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/providers/privacy_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goal_progress_provider.dart';
import 'package:inv_tracker/features/goals/presentation/widgets/goal_progress_ring.dart';

/// A card showing goals summary for the overview/dashboard screen.
class GoalsDashboardCard extends ConsumerWidget {
  const GoalsDashboardCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(goalsSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = ref.watch(currencySymbolProvider);
    final locale = ref.watch(currencyLocaleProvider);
    final isPrivacyMode = ref.watch(privacyModeProvider);

    return summaryAsync.when(
      data: (summary) {
        if (!summary.hasGoals) {
          return _buildEmptyState(context, isDark);
        }
        return _buildSummaryCard(
          context,
          summary,
          isDark,
          currencySymbol,
          locale,
          isPrivacyMode,
        );
      },
      loading: () => _buildLoadingState(isDark),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return GlassCard(
      onTap: () => context.push('/goals/create'),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.flag_outlined,
              color: AppColors.primaryLight,
              size: 28,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Your First Goal',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                SizedBox(height: AppSpacing.xxs),
                Text(
                  'Track progress towards your financial targets',
                  style: AppTypography.small.copyWith(
                    color: isDark ? Colors.white70 : AppColors.neutral600Light,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: isDark ? Colors.white54 : AppColors.neutral400Light,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    GoalsSummary summary,
    bool isDark,
    String currencySymbol,
    String locale,
    bool isPrivacyMode,
  ) {
    final closest = summary.closestToCompletion;
    final progressTextStyle = AppTypography.caption.copyWith(
      color: isDark ? Colors.white70 : AppColors.neutral600Light,
    );

    return GlassCard(
      onTap: () => context.push('/goals'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Goals',
                style: AppTypography.h4.copyWith(
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.successLight.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${summary.achievedGoals}/${summary.totalGoals} achieved',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.successLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),

          // Closest to completion
          if (closest != null) ...[
            Row(
              children: [
                // Mask the progress ring percentage when privacy mode is on
                PrivacyMask(
                  useTextMask: true,
                  maskedText: '••%',
                  child: GoalProgressRing(
                    progress: closest.progressPercent,
                    size: 48,
                    color: closest.goal.color,
                    strokeWidth: 4,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        closest.goal.name,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : AppColors.neutral900Light,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.xxs),
                      // Mask the progress message (contains amounts)
                      isPrivacyMode
                          ? MaskedAmountText(
                              text: closest.getProgressMessage(
                                currencySymbol,
                                locale,
                              ),
                              style: progressTextStyle,
                            )
                          : Text(
                              closest.getProgressMessage(
                                currencySymbol,
                                locale,
                              ),
                              style: progressTextStyle,
                            ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white54 : AppColors.neutral400Light,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return GlassCard(
      child: SizedBox(
        height: 80,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: isDark ? Colors.white54 : AppColors.neutral400Light,
          ),
        ),
      ),
    );
  }
}
