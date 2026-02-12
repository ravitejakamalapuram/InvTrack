/// Selection controls widget for the goals list screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/widgets/selection_list_controls.dart';
import 'package:inv_tracker/features/goals/domain/entities/goal_entity.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_list_state_provider.dart';

/// Selection controls shown when in multi-select mode
class GoalsListSelectionControls extends ConsumerWidget {
  /// List of currently filtered/visible goals
  final List<GoalEntity> filteredGoals;

  const GoalsListSelectionControls({super.key, required this.filteredGoals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PERFORMANCE: Use ref.select to rebuild only when selectedIds changes
    final selectedIds = ref.watch(
      goalsListStateProvider.select((s) => s.selectedIds),
    );

    final allSelected =
        filteredGoals.isNotEmpty &&
        filteredGoals.every((g) => selectedIds.contains(g.id));

    return SelectionListControls(
      totalCount: filteredGoals.length,
      selectedCount: selectedIds.length,
      allSelected: allSelected,
      onToggleSelectAll: () {
        final notifier = ref.read(goalsListStateProvider.notifier);
        if (allSelected) {
          notifier.clearSelection();
        } else {
          notifier.selectAll(filteredGoals.map((g) => g.id).toList());
        }
      },
    );
  }
}
