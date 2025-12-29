/// Selection controls widget for the investment list screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/widgets/selection_list_controls.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';

/// Selection controls shown when in multi-select mode
class InvestmentListSelectionControls extends ConsumerWidget {
  const InvestmentListSelectionControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listState = ref.watch(investmentListStateProvider);
    final filteredAsync = ref.watch(filteredInvestmentsProvider);
    final filteredInvestments = filteredAsync.value ?? [];

    final allSelected =
        filteredInvestments.isNotEmpty &&
        filteredInvestments.every((i) => listState.selectedIds.contains(i.id));

    return SelectionListControls(
      totalCount: filteredInvestments.length,
      selectedCount: listState.selectedIds.length,
      allSelected: allSelected,
      onToggleSelectAll: () {
        final notifier = ref.read(investmentListStateProvider.notifier);
        if (allSelected) {
          notifier.clearSelection();
        } else {
          notifier.selectAll(filteredInvestments.map((i) => i.id).toList());
        }
      },
    );
  }
}
