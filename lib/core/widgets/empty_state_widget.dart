import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// A reusable empty state widget with dark mode support.
///
/// Features:
/// - Automatic dark mode theming
/// - Optional gradient icon background
/// - Optional action button with icon
/// - Compact mode for smaller spaces
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final Color? iconColor;
  final List<Color>? iconBackgroundGradient;
  final bool compact;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.iconColor,
    this.iconBackgroundGradient,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = isDark
        ? AppColors.neutral400Dark
        : AppColors.neutral500Light;
    final effectiveIconColor = iconColor ?? defaultIconColor;
    final iconSize = compact ? 40.0 : 64.0;
    final spacing = compact ? 12.0 : 24.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16.0 : 32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with optional gradient background
            if (iconBackgroundGradient != null)
              Container(
                padding: EdgeInsets.all(compact ? 16 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: iconBackgroundGradient!),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: iconSize, color: effectiveIconColor),
              )
            else
              Icon(icon, size: iconSize, color: effectiveIconColor),
            SizedBox(height: spacing),
            Text(
              title,
              style: (compact ? AppTypography.body : AppTypography.h3).copyWith(
                color: isDark ? Colors.white : AppColors.neutral900Light,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: compact ? 4 : 8),
            Text(
              message,
              style: (compact ? AppTypography.caption : AppTypography.body)
                  .copyWith(
                    color: isDark
                        ? AppColors.neutral400Dark
                        : AppColors.neutral500Light,
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: spacing),
              TextButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.add_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
