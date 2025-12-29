import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_list_state_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  group('GoalsListState', () {
    test('should have default values', () {
      const state = GoalsListState();
      
      expect(state.isSelectionMode, isFalse);
      expect(state.selectedIds, isEmpty);
    });

    test('copyWith should update only specified fields', () {
      const state = GoalsListState();
      final updated = state.copyWith(isSelectionMode: true);

      expect(updated.isSelectionMode, isTrue);
      expect(updated.selectedIds, isEmpty);
    });

    test('copyWith should preserve other fields when updating selectedIds', () {
      final state = const GoalsListState().copyWith(
        isSelectionMode: true,
        selectedIds: {'id1', 'id2'},
      );
      final updated = state.copyWith(selectedIds: {'id3'});

      expect(updated.isSelectionMode, isTrue);
      expect(updated.selectedIds, {'id3'});
    });
  });

  group('GoalsListNotifier', () {
    test('should start with default state', () {
      final state = container.read(goalsListStateProvider);

      expect(state.isSelectionMode, isFalse);
      expect(state.selectedIds, isEmpty);
    });

    test('toggleSelectionMode should enter selection mode', () {
      container.read(goalsListStateProvider.notifier).toggleSelectionMode();
      final state = container.read(goalsListStateProvider);

      expect(state.isSelectionMode, isTrue);
      expect(state.selectedIds, isEmpty);
    });

    test('toggleSelectionMode should exit and clear selection', () {
      final notifier = container.read(goalsListStateProvider.notifier);
      notifier.enterSelectionMode('goal-1');
      notifier.toggleSelectionMode();
      final state = container.read(goalsListStateProvider);

      expect(state.isSelectionMode, isFalse);
      expect(state.selectedIds, isEmpty);
    });

    test('enterSelectionMode should set initial selection', () {
      container
          .read(goalsListStateProvider.notifier)
          .enterSelectionMode('goal-1');
      final state = container.read(goalsListStateProvider);

      expect(state.isSelectionMode, isTrue);
      expect(state.selectedIds, {'goal-1'});
    });

    test('toggleSelection should add unselected item', () {
      final notifier = container.read(goalsListStateProvider.notifier);
      notifier.enterSelectionMode('goal-1');
      notifier.toggleSelection('goal-2');
      final state = container.read(goalsListStateProvider);

      expect(state.selectedIds, {'goal-1', 'goal-2'});
    });

    test('toggleSelection should remove selected item', () {
      final notifier = container.read(goalsListStateProvider.notifier);
      notifier.enterSelectionMode('goal-1');
      notifier.toggleSelection('goal-2');
      notifier.toggleSelection('goal-1');
      final state = container.read(goalsListStateProvider);

      expect(state.selectedIds, {'goal-2'});
    });

    test('toggleSelection should exit selection mode when last item removed', () {
      final notifier = container.read(goalsListStateProvider.notifier);
      notifier.enterSelectionMode('goal-1');
      notifier.toggleSelection('goal-1');
      final state = container.read(goalsListStateProvider);

      expect(state.isSelectionMode, isFalse);
      expect(state.selectedIds, isEmpty);
    });

    test('selectAll should select all provided ids', () {
      final notifier = container.read(goalsListStateProvider.notifier);
      notifier.enterSelectionMode('goal-1');
      notifier.selectAll(['goal-1', 'goal-2', 'goal-3']);
      final state = container.read(goalsListStateProvider);

      expect(state.selectedIds, {'goal-1', 'goal-2', 'goal-3'});
    });

    test('clearSelection should exit selection mode and clear ids', () {
      final notifier = container.read(goalsListStateProvider.notifier);
      notifier.enterSelectionMode('goal-1');
      notifier.toggleSelection('goal-2');
      notifier.clearSelection();
      final state = container.read(goalsListStateProvider);

      expect(state.isSelectionMode, isFalse);
      expect(state.selectedIds, isEmpty);
    });
  });
}

