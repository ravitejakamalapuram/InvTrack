/// Action bar widget for bulk operations on selected goals.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/core/utils/app_feedback.dart';
import 'package:inv_tracker/core/widgets/selection_list_action_bar.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_list_state_provider.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';

/// Bottom action bar shown during selection mode
class GoalsListActionBar extends ConsumerWidget {
  /// Whether the goals being displayed are archived
  final bool isArchived;

  const GoalsListActionBar({
    super.key,
    this.isArchived = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(goalsListStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Bulk operations are not supported for archived goals
    // (same pattern as InvestmentListActionBar)
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
            'Bulk operations are not available for archived goals.\n'
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
    final listState = ref.read(goalsListStateProvider);
    final selectedCount = listState.selectedIds.length;

    final confirmed = await AppFeedback.showConfirmDialog(
      context: context,
      title: 'Delete $selectedCount Goal${selectedCount > 1 ? 's' : ''}?',
      message:
          'This action cannot be undone. The selected goal${selectedCount > 1 ? 's' : ''} will be permanently deleted.',
      confirmText: 'Delete',
    );

    if (confirmed && context.mounted) {
      final idsToDelete = listState.selectedIds.toList();
      final notifier = ref.read(goalNotifierProvider.notifier);
      final deletedCount = await notifier.bulkDelete(idsToDelete);
      ref.read(goalsListStateProvider.notifier).clearSelection();
      if (context.mounted) {
        AppFeedback.showSuccess(
          context,
          '$deletedCount goal${deletedCount != 1 ? 's' : ''} deleted',
        );
      }
    }
  }
}
