import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/core/widgets/glass_card.dart';
import 'package:inv_tracker/core/widgets/privacy_mask.dart';
import 'package:inv_tracker/features/fire_number/domain/entities/fire_calculation_result.dart';

/// Card displaying FIRE milestones progress
class FireMilestoneCard extends ConsumerWidget {
  final List<FireMilestone> milestones;
  final String currencySymbol;

  const FireMilestoneCard({
    super.key,
    required this.milestones,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = ref.watch(currencyLocaleProvider);

    return GlassCard(
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: milestones.asMap().entries.map((entry) {
          final index = entry.key;
          final milestone = entry.value;
          final isLast = index == milestones.length - 1;

          return _buildMilestoneRow(
            context,
            isDark,
            milestone,
            isLast,
            locale,
            key: ValueKey('milestone_${milestone.type.name}'),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMilestoneRow(
    BuildContext context,
    bool isDark,
    FireMilestone milestone,
    bool isLast,
    String locale, {
    Key? key,
  }) {
    final isAchieved = milestone.isAchieved;
    final progressColor = isAchieved
        ? (isDark ? AppColors.successDark : AppColors.successLight)
        : (isDark ? AppColors.neutral500Dark : AppColors.neutral400Light);

    return Padding(
      key: key,
      padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
      child: Row(
        children: [
          // Milestone indicator
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAchieved
                  ? progressColor.withValues(alpha: 0.2)
                  : Colors.transparent,
              border: Border.all(color: progressColor, width: 2),
            ),
            child: isAchieved
                ? Icon(Icons.check, size: 18, color: progressColor)
                : Center(
                    child: Text(
                      '${milestone.percentage}%',
                      style: AppTypography.caption.copyWith(
                        color: progressColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
          ),
          SizedBox(width: AppSpacing.md),
          // Milestone info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  milestone.label,
                  style: AppTypography.bodyMedium.copyWith(
                    color: isAchieved
                        ? (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight)
                        : (isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral500Light),
                    fontWeight: isAchieved ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                MaskedAmountText(
                  text: formatCompactCurrency(
                    milestone.targetAmount,
                    symbol: currencySymbol,
                    locale: locale,
                  ),
                  style: AppTypography.small.copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
                ),
              ],
            ),
          ),
          // Progress indicator
          if (!isAchieved)
            SizedBox(
              width: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${milestone.currentProgress.toInt()}%',
                    style: AppTypography.small.copyWith(
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral500Light,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: AppSpacing.xxs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: milestone.currentProgress / 100,
                      backgroundColor: isDark
                          ? AppColors.neutral700Dark
                          : AppColors.neutral200Light,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isDark ? AppColors.primaryDark : AppColors.primaryLight,
                      ),
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          if (isAchieved)
            Icon(Icons.celebration_outlined, size: 20, color: progressColor),
        ],
      ),
    );
  }
}
