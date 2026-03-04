import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Empty state widget when no goals exist
class GoalsEmptyState extends StatelessWidget {
  final VoidCallback onCreateGoal;

  const GoalsEmptyState({super.key, required this.onCreateGoal});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryLight.withValues(alpha: 0.2),
                  AppColors.primaryLight.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(l10n.goalEmoji, style: const TextStyle(fontSize: 56)),
            ),
          ),
          SizedBox(height: AppSpacing.xl),

          // Title
          Text(
            'Set Your First Goal',
            style: AppTypography.h2.copyWith(
              color: isDark ? Colors.white : AppColors.neutral900Light,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sm),

          // Description
          Text(
            'Goals help you track progress toward your financial targets. '
            'Link them to your investments for automatic tracking.',
            style: AppTypography.bodyMedium.copyWith(
              color: isDark
                  ? AppColors.neutral400Dark
                  : AppColors.neutral500Light,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl),

          // Example goals
          _buildExampleGoals(isDark),
          SizedBox(height: AppSpacing.xl),

          // CTA Button
          FilledButton.icon(
            onPressed: onCreateGoal,
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.createYourFirstGoal),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryLight,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExampleGoals(bool isDark) {
    final examples = [
      ('🏠', 'Home Down Payment', '₹20L by 2027'),
      ('🎓', 'Child Education', '₹50L'),
      ('💰', 'Passive Income', '₹50K/month'),
    ];

    return Column(
      children: [
        Text(
          'Example Goals',
          style: AppTypography.small.copyWith(
            color: isDark
                ? AppColors.neutral400Dark
                : AppColors.neutral500Light,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          alignment: WrapAlignment.center,
          children: examples.map((e) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.05,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.$1, style: const TextStyle(fontSize: 20)),
                  SizedBox(width: AppSpacing.xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.$2,
                        style: AppTypography.small.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : AppColors.neutral900Light,
                        ),
                      ),
                      Text(
                        e.$3,
                        style: AppTypography.small.copyWith(
                          color: isDark
                              ? AppColors.neutral400Dark
                              : AppColors.neutral500Light,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
