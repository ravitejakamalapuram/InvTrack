/// Action bar widget for bulk operations on selected investments.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/widgets/selection_list_action_bar.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/merge_investments_dialog.dart';

/// Bottom action bar shown during selection mode
class InvestmentListActionBar extends ConsumerWidget {
  const InvestmentListActionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(investmentListStateProvider);
    final isArchived = listState.filter == InvestmentFilter.archived;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Bulk operations are not supported for archived investments
    if (isArchived) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.grey[100],
          border: Border(
            top: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            ),
          ),
        ),
        child: SafeArea(
          child: Text(
            'Bulk operations are not available for archived investments.\n'
            'Use swipe actions to delete or unarchive individual items.',
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return SelectionListActionBar(
      selectedCount: listState.selectedIds.length,
      actions: [
        SelectionActionConfig(
          label: 'Merge',
          icon: Icons.merge_rounded,
          minSelection: 2,
          onPressed: () => _showMergeDialog(context, ref),
        ),
        SelectionActionConfig(
          label: 'Delete',
          icon: Icons.delete_rounded,
          color: AppColors.errorLight,
          minSelection: 1,
          onPressed: () => _showDeleteConfirmation(context, ref),
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final listState = ref.read(investmentListStateProvider);
    final selectedCount = listState.selectedIds.length;

    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: 'Delete $selectedCount Investment${selectedCount > 1 ? 's' : ''}?',
      message: 'This action cannot be undone.',
      confirmText: 'Delete',
    );

    if (confirmed && context.mounted) {
      final notifier = ref.read(investmentNotifierProvider.notifier);
      final idsToDelete = listState.selectedIds.toList();
      final deletedCount = await notifier.bulkDelete(idsToDelete);
      ref.read(investmentListStateProvider.notifier).clearSelection();
      if (context.mounted) {
        AppFeedback.showSuccess(
          context,
          '$deletedCount investment${deletedCount != 1 ? 's' : ''} deleted',
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
