/// State management for the goals list screen.
/// Handles selection state for bulk operations.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for the goals list screen
class GoalsListState {
  final bool isSelectionMode;
  final Set<String> selectedIds;

  const GoalsListState({
    this.isSelectionMode = false,
    this.selectedIds = const {},
  });

  GoalsListState copyWith({
    bool? isSelectionMode,
    Set<String>? selectedIds,
  }) {
    return GoalsListState(
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

/// Notifier for goals list state
class GoalsListNotifier extends Notifier<GoalsListState> {
  @override
  GoalsListState build() => const GoalsListState();

  void toggleSelectionMode() {
    if (state.isSelectionMode) {
      state = state.copyWith(isSelectionMode: false, selectedIds: {});
    } else {
      state = state.copyWith(isSelectionMode: true);
    }
  }

  void toggleSelection(String id) {
    final newSelectedIds = Set<String>.from(state.selectedIds);
    if (newSelectedIds.contains(id)) {
      newSelectedIds.remove(id);
    } else {
      newSelectedIds.add(id);
    }
    // Exit selection mode if nothing selected
    if (newSelectedIds.isEmpty) {
      state = state.copyWith(isSelectionMode: false, selectedIds: {});
    } else {
      state = state.copyWith(selectedIds: newSelectedIds);
    }
  }

  void selectAll(List<String> ids) {
    state = state.copyWith(selectedIds: ids.toSet());
  }

  void clearSelection() {
    state = state.copyWith(isSelectionMode: false, selectedIds: {});
  }

  void enterSelectionMode(String initialId) {
    state = state.copyWith(isSelectionMode: true, selectedIds: {initialId});
  }
}

/// Provider for goals list state
/// Uses .autoDispose to prevent memory leaks when screen is disposed
final goalsListStateProvider =
    NotifierProvider.autoDispose<GoalsListNotifier, GoalsListState>(
      GoalsListNotifier.new,
    );
