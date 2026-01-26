/// Generic action bar widget for bulk operations on selected items.
library;

import 'package:flutter/material.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// Configuration for an action button in the action bar
class SelectionActionConfig {
  final String label;
  final IconData icon;
  final Color? color;
  final VoidCallback? onPressed;
  final int? minSelection;

  const SelectionActionConfig({
    required this.label,
    required this.icon,
    this.color,
    this.onPressed,
    this.minSelection,
  });
}

/// A reusable bottom action bar for bulk operations during selection mode.
class SelectionListActionBar extends StatelessWidget {
  /// Number of selected items
  final int selectedCount;

  /// List of action configurations to display
  final List<SelectionActionConfig> actions;

  /// Optional custom leading widget
  final Widget? leading;

  const SelectionListActionBar({
    super.key,
    required this.selectedCount,
    required this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Selection count or custom leading
            leading ??
                Expanded(
                  child: Text(
                    '$selectedCount selected',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.neutral900Light,
                    ),
                  ),
                ),
            // Action buttons
            ...actions.map((action) {
              final isEnabled = action.onPressed != null &&
                  (action.minSelection == null ||
                      selectedCount >= action.minSelection!);
              return Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: TextButton.icon(
                  onPressed: isEnabled ? action.onPressed : null,
                  icon: Icon(action.icon, color: action.color),
                  label: Text(
                    action.label,
                    style: TextStyle(color: action.color),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
