/// Bottom sheet for investment sort options.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';

/// Shows a bottom sheet for selecting sort options.
void showSortOptionsSheet({
  required BuildContext context,
  required bool isDark,
  required InvestmentSort currentSort,
  required ValueChanged<InvestmentSort> onSortChanged,
}) {
  HapticFeedback.selectionClick();
  showModalBottomSheet(
    context: context,
    backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SortOptionsSheet(
      isDark: isDark,
      currentSort: currentSort,
      onSortChanged: onSortChanged,
    ),
  );
}

class SortOptionsSheet extends StatelessWidget {
  final bool isDark;
  final InvestmentSort currentSort;
  final ValueChanged<InvestmentSort> onSortChanged;

  const SortOptionsSheet({
    super.key,
    required this.isDark,
    required this.currentSort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: AppSpacing.sm),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(
                alpha: 0.2,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(
                  Icons.sort_rounded,
                  color: isDark ? Colors.white : AppColors.neutral700Light,
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Sort By',
                  style: AppTypography.h3.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                const Spacer(),
                if (currentSort != InvestmentSort.lastActivity)
                  TextButton(
                    onPressed: () {
                      onSortChanged(InvestmentSort.lastActivity);
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Reset',
                      style: AppTypography.small.copyWith(
                        color: AppColors.primaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.1,
            ),
          ),
          // Sort options
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: InvestmentSort.values.map((sortOption) {
                  final isSelected = currentSort == sortOption;
                  final isDefault = sortOption == InvestmentSort.lastActivity;
                  return ListTile(
                    leading: Icon(
                      sortOption.icon,
                      color: isSelected
                          ? AppColors.primaryLight
                          : (isDark
                                ? Colors.white70
                                : AppColors.neutral600Light),
                    ),
                    title: Row(
                      children: [
                        Text(
                          sortOption.displayName,
                          style: AppTypography.body.copyWith(
                            color: isSelected
                                ? AppColors.primaryLight
                                : (isDark
                                      ? Colors.white
                                      : AppColors.neutral800Light),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        if (isDefault) ...[
                          SizedBox(width: AppSpacing.xs),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  (isDark
                                          ? Colors.white
                                          : AppColors.primaryLight)
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Default',
                              style: AppTypography.caption.copyWith(
                                color: isDark
                                    ? Colors.white70
                                    : AppColors.neutral600Light,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            color: AppColors.primaryLight,
                          )
                        : null,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSortChanged(sortOption);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
