/// Generic selection controls widget for list screens with multi-select.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';

/// A reusable selection controls widget with Select All/Deselect All
/// functionality and selection count display.
class SelectionListControls extends StatelessWidget {
  /// Total number of items in the filtered list
  final int totalCount;

  /// Number of currently selected items
  final int selectedCount;

  /// Whether all items are selected
  final bool allSelected;

  /// Callback when Select All/Deselect All is tapped
  final VoidCallback onToggleSelectAll;

  const SelectionListControls({
    super.key,
    required this.totalCount,
    required this.selectedCount,
    required this.allSelected,
    required this.onToggleSelectAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onToggleSelectAll();
          },
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: allSelected
                  ? AppColors.primaryLight
                  : (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.05,
                    ),
              borderRadius: BorderRadius.circular(AppSizes.radiusXl),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  allSelected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: allSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : AppColors.neutral700Light),
                ),
                SizedBox(width: AppSpacing.xs),
                Text(
                  allSelected ? 'Deselect All' : 'Select All',
                  style: AppTypography.small.copyWith(
                    color: allSelected
                        ? Colors.white
                        : (isDark ? Colors.white70 : AppColors.neutral700Light),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Spacer(),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.primaryLight).withValues(
              alpha: 0.1,
            ),
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          ),
          child: Text(
            '$selectedCount of $totalCount',
            style: AppTypography.small.copyWith(
              color: isDark ? Colors.white70 : AppColors.neutral600Light,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

