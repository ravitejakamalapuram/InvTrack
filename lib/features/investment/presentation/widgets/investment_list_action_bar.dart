/// Action bar widget for bulk operations on selected investments.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/merge_investments_dialog.dart';

/// Bottom action bar shown during selection mode
class InvestmentListActionBar extends ConsumerWidget {
  const InvestmentListActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listState = ref.watch(investmentListStateProvider);

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
            // Selection count
            Expanded(
              child: Text(
                '${listState.selectedIds.length} selected',
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.neutral900Light,
                ),
              ),
            ),
            // Merge button
            if (listState.selectedIds.length >= 2)
              TextButton.icon(
                onPressed: () => _showMergeDialog(context, ref),
                icon: const Icon(Icons.merge_rounded),
                label: const Text('Merge'),
              ),
            SizedBox(width: AppSpacing.sm),
            // Delete button
            TextButton.icon(
              onPressed: listState.selectedIds.isNotEmpty
                  ? () => _showDeleteConfirmation(context, ref)
                  : null,
              icon: Icon(Icons.delete_rounded, color: AppColors.errorLight),
              label: Text(
                'Delete',
                style: TextStyle(color: AppColors.errorLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final listState = ref.read(investmentListStateProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Investments'),
        content: Text(
          'Are you sure you want to delete ${listState.selectedIds.length} investment(s)? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorLight),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final notifier = ref.read(investmentNotifierProvider.notifier);
      final idsToDelete = listState.selectedIds.toList();
      final deletedCount = await notifier.bulkDelete(idsToDelete);
      ref.read(investmentListStateProvider.notifier).clearSelection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$deletedCount investment${deletedCount != 1 ? 's' : ''} deleted',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showMergeDialog(BuildContext context, WidgetRef ref) async {
    final listState = ref.read(investmentListStateProvider);
    final allInvestments = ref.read(allInvestmentsProvider).value ?? [];
    final toMerge = allInvestments
        .where((i) => listState.selectedIds.contains(i.id))
        .toList();

    // Find the most common type as default
    final typeCount = <InvestmentType, int>{};
    for (final inv in toMerge) {
      typeCount[inv.type] = (typeCount[inv.type] ?? 0) + 1;
    }
    final defaultType = typeCount.isNotEmpty
        ? typeCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : InvestmentType.other;

    final result = await MergeInvestmentsDialog.show(
      context: context,
      selectedCount: listState.selectedIds.length,
      defaultType: defaultType,
      investmentTypes: toMerge.map((i) => i.type).toSet().toList(),
    );

    if (result != null && result.name.isNotEmpty && context.mounted) {
      final notifier = ref.read(investmentNotifierProvider.notifier);
      await notifier.mergeInvestments(
        listState.selectedIds.toList(),
        result.name,
        type: result.type,
      );
      ref.read(investmentListStateProvider.notifier).clearSelection();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Investments merged into "${result.name}"')),
        );
      }
    }
  }
}
