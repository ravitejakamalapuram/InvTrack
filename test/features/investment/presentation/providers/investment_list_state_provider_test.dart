import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_list_state_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';
import '../../data/repositories/mock_investment_repository.dart';

void main() {
  late FakeInvestmentRepository fakeRepository;
  late ProviderContainer container;

  final openInvestment = InvestmentEntity(
    id: 'open-1',
    name: 'Open Investment',
    type: InvestmentType.stocks,
    status: InvestmentStatus.open,
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    isArchived: false,
  );

  final closedInvestment = InvestmentEntity(
    id: 'closed-1',
    name: 'Closed Investment',
    type: InvestmentType.bonds,
    status: InvestmentStatus.closed,
    createdAt: DateTime(2024, 1, 2),
    updatedAt: DateTime(2024, 1, 2),
    isArchived: false,
  );

  final archivedOpenInvestment = InvestmentEntity(
    id: 'archived-open-1',
    name: 'Archived Open Investment',
    type: InvestmentType.p2pLending,
    status: InvestmentStatus.open,
    createdAt: DateTime(2024, 1, 3),
    updatedAt: DateTime(2024, 1, 3),
    isArchived: true,
  );

  final archivedClosedInvestment = InvestmentEntity(
    id: 'archived-closed-1',
    name: 'Archived Closed Investment',
    type: InvestmentType.mutualFunds,
    status: InvestmentStatus.closed,
    createdAt: DateTime(2024, 1, 4),
    updatedAt: DateTime(2024, 1, 4),
    isArchived: true,
  );

  setUp(() {
    fakeRepository = FakeInvestmentRepository();
    fakeRepository.seed(
      investments: [
        openInvestment,
        closedInvestment,
        archivedOpenInvestment,
        archivedClosedInvestment,
      ],
    );
    container = ProviderContainer(
      overrides: [
        investmentRepositoryProvider.overrideWithValue(fakeRepository),
        isAuthenticatedProvider.overrideWithValue(true),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    fakeRepository.reset();
  });

  group('InvestmentFilter enum', () {
    test('should have all, open, closed, and archived values', () {
      expect(InvestmentFilter.values, hasLength(4));
      expect(InvestmentFilter.values, contains(InvestmentFilter.all));
      expect(InvestmentFilter.values, contains(InvestmentFilter.open));
      expect(InvestmentFilter.values, contains(InvestmentFilter.closed));
      expect(InvestmentFilter.values, contains(InvestmentFilter.archived));
    });
  });

  group('investmentCountsProvider', () {
    test('should return zero counts when investments are loading', () {
      // Initially, when stream hasn't emitted, counts should be zero
      final counts = container.read(investmentCountsProvider);

      // All counts are 0 while loading
      expect(counts.all, 0);
      expect(counts.open, 0);
      expect(counts.closed, 0);
      expect(counts.archived, 0);
    });
  });

  group('investmentListStateProvider', () {
    test('should have default filter as all', () {
      final state = container.read(investmentListStateProvider);
      expect(state.filter, InvestmentFilter.all);
    });

    test('should update filter when setFilter is called', () {
      container
          .read(investmentListStateProvider.notifier)
          .setFilter(InvestmentFilter.archived);
      final state = container.read(investmentListStateProvider);
      expect(state.filter, InvestmentFilter.archived);
    });

    test('should cycle through all filters', () {
      final notifier = container.read(investmentListStateProvider.notifier);

      notifier.setFilter(InvestmentFilter.open);
      expect(
        container.read(investmentListStateProvider).filter,
        InvestmentFilter.open,
      );

      notifier.setFilter(InvestmentFilter.closed);
      expect(
        container.read(investmentListStateProvider).filter,
        InvestmentFilter.closed,
      );

      notifier.setFilter(InvestmentFilter.archived);
      expect(
        container.read(investmentListStateProvider).filter,
        InvestmentFilter.archived,
      );

      notifier.setFilter(InvestmentFilter.all);
      expect(
        container.read(investmentListStateProvider).filter,
        InvestmentFilter.all,
      );
    });
  });

  group('investmentListStateProvider - Selection Mode', () {
    test('should start with selection mode disabled', () {
      final state = container.read(investmentListStateProvider);
      expect(state.isSelectionMode, false);
      expect(state.selectedIds, isEmpty);
    });

    test('should toggle selection mode on', () {
      container.read(investmentListStateProvider.notifier).toggleSelectionMode();
      final state = container.read(investmentListStateProvider);
      expect(state.isSelectionMode, true);
    });

    test('should toggle selection mode off and clear selection', () {
      final notifier = container.read(investmentListStateProvider.notifier);
      notifier.enterSelectionMode('test-id');
      notifier.toggleSelectionMode();
      final state = container.read(investmentListStateProvider);

      expect(state.isSelectionMode, false);
      expect(state.selectedIds, isEmpty);
    });

    test('should enter selection mode with initial selection', () {
      container
          .read(investmentListStateProvider.notifier)
          .enterSelectionMode('investment-1');
      final state = container.read(investmentListStateProvider);

      expect(state.isSelectionMode, true);
      expect(state.selectedIds, {'investment-1'});
    });

    test('should toggle selection to add item', () {
      final notifier = container.read(investmentListStateProvider.notifier);
      notifier.enterSelectionMode('inv-1');
      notifier.toggleSelection('inv-2');
      final state = container.read(investmentListStateProvider);

      expect(state.selectedIds, {'inv-1', 'inv-2'});
    });

    test('should toggle selection to remove item', () {
      final notifier = container.read(investmentListStateProvider.notifier);
      notifier.enterSelectionMode('inv-1');
      notifier.toggleSelection('inv-2');
      notifier.toggleSelection('inv-1');
      final state = container.read(investmentListStateProvider);

      expect(state.selectedIds, {'inv-2'});
    });

    test('should exit selection mode when last item is deselected', () {
      final notifier = container.read(investmentListStateProvider.notifier);
      notifier.enterSelectionMode('inv-1');
      notifier.toggleSelection('inv-1');
      final state = container.read(investmentListStateProvider);

      expect(state.isSelectionMode, false);
      expect(state.selectedIds, isEmpty);
    });

    test('should select all provided ids', () {
      final notifier = container.read(investmentListStateProvider.notifier);
      notifier.enterSelectionMode('inv-1');
      notifier.selectAll(['inv-1', 'inv-2', 'inv-3']);
      final state = container.read(investmentListStateProvider);

      expect(state.selectedIds, {'inv-1', 'inv-2', 'inv-3'});
    });

    test('should clear selection', () {
      final notifier = container.read(investmentListStateProvider.notifier);
      notifier.enterSelectionMode('inv-1');
      notifier.toggleSelection('inv-2');
      notifier.clearSelection();
      final state = container.read(investmentListStateProvider);

      expect(state.isSelectionMode, false);
      expect(state.selectedIds, isEmpty);
    });
  });

  group('investmentListStateProvider - Search', () {
    test('should start with no search query', () {
      final state = container.read(investmentListStateProvider);
      expect(state.isSearching, false);
      expect(state.searchQuery, '');
    });

    test('should update search query', () {
      container
          .read(investmentListStateProvider.notifier)
          .setSearchQuery('test query');
      final state = container.read(investmentListStateProvider);

      // setSearchQuery only updates searchQuery, not isSearching
      expect(state.searchQuery, 'test query');
    });

    test('should toggle search mode on', () {
      container.read(investmentListStateProvider.notifier).toggleSearch();
      final state = container.read(investmentListStateProvider);

      expect(state.isSearching, true);
    });

    test('should toggle search mode off and clear query', () {
      final notifier = container.read(investmentListStateProvider.notifier);
      notifier.toggleSearch(); // On
      notifier.setSearchQuery('test query');
      notifier.toggleSearch(); // Off

      final state = container.read(investmentListStateProvider);

      expect(state.isSearching, false);
      expect(state.searchQuery, '');
    });
  });

  group('InvestmentListState - copyWith', () {
    test('should copy with updated filter', () {
      const state = InvestmentListState();
      final updated = state.copyWith(filter: InvestmentFilter.archived);

      expect(updated.filter, InvestmentFilter.archived);
      expect(updated.isSelectionMode, false);
      expect(updated.selectedIds, isEmpty);
    });

    test('should copy with updated selection mode', () {
      const state = InvestmentListState();
      final updated = state.copyWith(
        isSelectionMode: true,
        selectedIds: {'id1', 'id2'},
      );

      expect(updated.isSelectionMode, true);
      expect(updated.selectedIds, {'id1', 'id2'});
    });

    test('should preserve other fields when updating one', () {
      final state = const InvestmentListState().copyWith(
        filter: InvestmentFilter.closed,
        isSelectionMode: true,
        selectedIds: {'id1'},
      );
      final updated = state.copyWith(selectedIds: {'id2'});

      expect(updated.filter, InvestmentFilter.closed);
      expect(updated.isSelectionMode, true);
      expect(updated.selectedIds, {'id2'});
    });
  });

  group('Archived filter behavior', () {
    test('should identify archived filter correctly', () {
      container
          .read(investmentListStateProvider.notifier)
          .setFilter(InvestmentFilter.archived);
      final state = container.read(investmentListStateProvider);

      expect(state.filter == InvestmentFilter.archived, true);
    });

    test('should use correct isArchived check for bulk operations', () {
      final notifier = container.read(investmentListStateProvider.notifier);

      // Set to archived filter
      notifier.setFilter(InvestmentFilter.archived);
      final archivedState = container.read(investmentListStateProvider);

      // This is the check used in InvestmentListActionBar
      final isArchivedFilter =
          archivedState.filter == InvestmentFilter.archived;
      expect(isArchivedFilter, true);

      // Set to all filter
      notifier.setFilter(InvestmentFilter.all);
      final allState = container.read(investmentListStateProvider);
      final isNotArchivedFilter = allState.filter != InvestmentFilter.archived;
      expect(isNotArchivedFilter, true);
    });
  });
}
