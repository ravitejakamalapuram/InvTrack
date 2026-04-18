/// Report header widget for notification landing pages.
///
/// Displays a consistent header across all report screens with:
/// - Icon representing the notification type
/// - Title (e.g., "Weekly Summary")
/// - Subtitle (e.g., "Apr 12-18, 2026")
/// - Back button (auto-handled by AppBar)
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// Report header widget
class ReportHeader extends StatelessWidget implements PreferredSizeWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget>? actions;

  const ReportHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark
          ? AppColors.neutral900Dark
          : AppColors.neutral50Light,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: isDark ? AppColors.neutral50Light : AppColors.neutral900Light,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.1),
              borderRadius: AppSizes.borderRadiusMd,
            ),
            child: Icon(
              icon,
              color: AppColors.primaryLight,
              size: 24,
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.h3.copyWith(
                    color: isDark
                        ? AppColors.neutral50Light
                        : AppColors.neutral900Light,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.body2.copyWith(
                      color: isDark
                          ? AppColors.neutral400Dark
                          : AppColors.neutral600Light,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
