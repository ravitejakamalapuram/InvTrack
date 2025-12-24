/// Selection controls widget for the investment list screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_sizes.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

/// Selection controls shown when in multi-select mode
class InvestmentListSelectionControls extends ConsumerWidget {
  const InvestmentListSelectionControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listState = ref.watch(investmentListStateProvider);
    final filteredAsync = ref.watch(filteredInvestmentsProvider);
    final filteredInvestments = filteredAsync.valueOrNull ?? [];

    final allSelected = filteredInvestments.isNotEmpty &&
        filteredInvestments.every((i) => listState.selectedIds.contains(i.id));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            final notifier = ref.read(investmentListStateProvider.notifier);
            if (allSelected) {
              notifier.clearSelection();
            } else {
              notifier.selectAll(filteredInvestments.map((i) => i.id).toList());
            }
          },
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: allSelected
                  ? AppColors.primaryLight
                  : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
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
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : AppColors.primaryLight).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSizes.radiusXl),
          ),
          child: Text(
            '${listState.selectedIds.length} of ${filteredInvestments.length}',
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

