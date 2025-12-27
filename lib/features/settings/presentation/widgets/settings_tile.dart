/// Reusable settings tile widgets with consistent styling.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// Standard navigation tile for settings.
class SettingsNavTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool showChevron;

  const SettingsNavTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primaryLight).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: iconColor ?? AppColors.primaryLight,
        ),
      ),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          color: isDark ? Colors.white : AppColors.neutral900Light,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTypography.small.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            )
          : null,
      trailing: trailing ?? (showChevron 
          ? Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral400Light,
            )
          : null),
      onTap: onTap,
    );
  }
}

/// Toggle tile for settings with switch.
class SettingsToggleTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SettingsToggleTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SwitchListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      secondary: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primaryLight).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: iconColor ?? AppColors.primaryLight,
        ),
      ),
      title: Text(
        title,
        style: AppTypography.bodyMedium.copyWith(
          color: isDark ? Colors.white : AppColors.neutral900Light,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: AppTypography.small.copyWith(
                color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
              ),
            )
          : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

/// Value tile showing current selection.
class SettingsValueTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const SettingsValueTile({
    super.key,
    required this.icon,
    this.iconColor,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.primaryLight).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: iconColor ?? AppColors.primaryLight),
      ),
      title: Text(title, style: AppTypography.bodyMedium.copyWith(
        color: isDark ? Colors.white : AppColors.neutral900Light,
      )),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: AppTypography.bodyMedium.copyWith(
            color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
          )),
          if (onTap != null) ...[
            SizedBox(width: AppSpacing.xs),
            Icon(Icons.chevron_right, 
              color: isDark ? AppColors.neutral400Dark : AppColors.neutral400Light),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

