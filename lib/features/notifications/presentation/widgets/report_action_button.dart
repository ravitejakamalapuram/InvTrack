/// Action button widget for report screens.
///
/// Displays a prominent call-to-action button (e.g., "View All Investments")
/// styled consistently across all report screens.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// Report action button
class ReportActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isPrimary;

  const ReportActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isPrimary = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: SizedBox(
        width: double.infinity,
        child: isPrimary
            ? FilledButton.icon(
                onPressed: onPressed,
                icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
                label: Text(label),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSizes.borderRadiusMd,
                  ),
                ),
              )
            : OutlinedButton.icon(
                onPressed: onPressed,
                icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? AppColors.neutral50Light
                      : AppColors.neutral900Light,
                  side: BorderSide(
                    color: isDark
                        ? AppColors.neutral600Dark
                        : AppColors.neutral300Light,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppSizes.borderRadiusMd,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Multiple action buttons in a column
class ReportActionButtons extends StatelessWidget {
  final List<ReportActionButton> buttons;

  const ReportActionButtons({
    super.key,
    required this.buttons,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: AppSpacing.md),
        ...buttons,
        SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}
