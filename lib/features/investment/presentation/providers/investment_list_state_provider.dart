/// State management for the investment list screen.
/// Handles search, filter, sort, and selection state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/investment/presentation/widgets/investment_list_enums.dart';

/// State for the investment list screen
class InvestmentListState {
  final bool isSearching;
  final String searchQuery;
  final InvestmentFilter filter;
  final InvestmentSort sort;
  final bool isSelectionMode;
  final Set<String> selectedIds;

  const InvestmentListState({
    this.isSearching = false,
    this.searchQuery = '',
    this.filter = InvestmentFilter.all,
    this.sort = InvestmentSort.lastActivity,
    this.isSelectionMode = false,
    this.selectedIds = const {},
  });

  InvestmentListState copyWith({
    bool? isSearching,
    String? searchQuery,
    InvestmentFilter? filter,
    InvestmentSort? sort,
    bool? isSelectionMode,
    Set<String>? selectedIds,
  }) {
    return InvestmentListState(
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
    );
  }
}

/// Notifier for investment list state (Riverpod 3.x)
class InvestmentListNotifier extends Notifier<InvestmentListState> {
  @override
  InvestmentListState build() => const InvestmentListState();

  void toggleSearch() {
    if (state.isSearching) {
      state = state.copyWith(isSearching: false, searchQuery: '');
    } else {
      state = state.copyWith(isSearching: true);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilter(InvestmentFilter filter) {
    state = state.copyWith(filter: filter);
  }

  void setSort(InvestmentSort sort) {
    state = state.copyWith(sort: sort);
  }

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

/// Provider for investment list state
final investmentListStateProvider =
    NotifierProvider<InvestmentListNotifier, InvestmentListState>(
      InvestmentListNotifier.new,
    );

/// Provider for filtered and sorted investments
/// Uses separate streams for active and archived investments for complete isolation.
final filteredInvestmentsProvider = Provider<AsyncValue<List<InvestmentEntity>>>((
  ref,
) {
  final listState = ref.watch(investmentListStateProvider);

  // Use the appropriate stream based on filter
  final AsyncValue<List<InvestmentEntity>> sourceAsync;
  if (listState.filter == InvestmentFilter.archived) {
    // For archived filter, use the archived investments stream
    sourceAsync = ref.watch(archivedInvestmentsProvider);
  } else {
    // For all other filters, use the active investments stream
    sourceAsync = ref.watch(allInvestmentsProvider);
  }

  return sourceAsync.when(
    data: (investments) {
      var filtered = investments.toList();

      // Apply status filter (only for active investments)
      switch (listState.filter) {
        case InvestmentFilter.all:
          // All active investments (already filtered by stream)
          break;
        case InvestmentFilter.open:
          filtered = filtered
              .where((inv) => inv.status == InvestmentStatus.open)
              .toList();
        case InvestmentFilter.closed:
          filtered = filtered
              .where((inv) => inv.status == InvestmentStatus.closed)
              .toList();
        case InvestmentFilter.archived:
          // All archived investments (already filtered by stream)
          break;
      }

      // Apply search filter
      if (listState.searchQuery.isNotEmpty) {
        final query = listState.searchQuery.toLowerCase();
        filtered = filtered.where((inv) {
          return inv.name.toLowerCase().contains(query) ||
              inv.type.displayName.toLowerCase().contains(query);
        }).toList();
      }

      // Pre-compute stats for sorting using ref.watch to react to stats loading
      // This ensures the list re-sorts when stats become available
      final statsCache = <String, InvestmentStats?>{};

      // Check if current sort criteria actually needs XIRR
      final requiresXirr =
          listState.sort == InvestmentSort.xirrAsc ||
          listState.sort == InvestmentSort.xirrDesc;

      for (final inv in filtered) {
        // PERFORMANCE OPTIMIZATION:
        // Use basic stats provider (no XIRR) unless explicitly sorting by XIRR.
        // Also correctly handle archived vs active investments.
        final AsyncValue<InvestmentStats> statsAsync;

        if (inv.isArchived) {
          statsAsync =
              requiresXirr
                  ? ref.watch(archivedInvestmentStatsProvider(inv.id))
                  : ref.watch(archivedInvestmentBasicStatsProvider(inv.id));
        } else {
          statsAsync =
              requiresXirr
                  ? ref.watch(investmentStatsProvider(inv.id))
                  : ref.watch(investmentBasicStatsProvider(inv.id));
        }

        statsCache[inv.id] = statsAsync.value;
      }

      // Apply sorting
      filtered.sort(
        (a, b) => _compareInvestments(a, b, listState.sort, statsCache),
      );

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Compare two investments for sorting
int _compareInvestments(
  InvestmentEntity a,
  InvestmentEntity b,
  InvestmentSort sort,
  Map<String, InvestmentStats?> statsCache,
) {
  final statsA = statsCache[a.id];
  final statsB = statsCache[b.id];

  int comparison;
  switch (sort) {
    case InvestmentSort.lastActivity:
      // Use lastCashFlowDate if available, otherwise fallback to createdAt
      // (consistent with how the card displays the date)
      final dateA = statsA?.lastCashFlowDate ?? a.createdAt;
      final dateB = statsB?.lastCashFlowDate ?? b.createdAt;
      comparison = dateB.compareTo(dateA);
    case InvestmentSort.nameAsc:
      comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    case InvestmentSort.nameDesc:
      comparison = b.name.toLowerCase().compareTo(a.name.toLowerCase());
    case InvestmentSort.totalInvestedDesc:
      comparison = (statsB?.totalInvested ?? 0).compareTo(
        statsA?.totalInvested ?? 0,
      );
    case InvestmentSort.totalInvestedAsc:
      comparison = (statsA?.totalInvested ?? 0).compareTo(
        statsB?.totalInvested ?? 0,
      );
    case InvestmentSort.totalReturnsDesc:
      comparison = (statsB?.totalReturned ?? 0).compareTo(
        statsA?.totalReturned ?? 0,
      );
    case InvestmentSort.totalReturnsAsc:
      comparison = (statsA?.totalReturned ?? 0).compareTo(
        statsB?.totalReturned ?? 0,
      );
    case InvestmentSort.returnPercentDesc:
      comparison = (statsB?.absoluteReturn ?? 0).compareTo(
        statsA?.absoluteReturn ?? 0,
      );
    case InvestmentSort.returnPercentAsc:
      comparison = (statsA?.absoluteReturn ?? 0).compareTo(
        statsB?.absoluteReturn ?? 0,
      );
    case InvestmentSort.xirrDesc:
      comparison = (statsB?.xirr ?? 0).compareTo(statsA?.xirr ?? 0);
    case InvestmentSort.xirrAsc:
      comparison = (statsA?.xirr ?? 0).compareTo(statsB?.xirr ?? 0);
    case InvestmentSort.netPositionDesc:
      comparison = (statsB?.netCashFlow ?? 0).compareTo(
        statsA?.netCashFlow ?? 0,
      );
    case InvestmentSort.netPositionAsc:
      comparison = (statsA?.netCashFlow ?? 0).compareTo(
        statsB?.netCashFlow ?? 0,
      );
    case InvestmentSort.createdDesc:
      comparison = b.createdAt.compareTo(a.createdAt);
    case InvestmentSort.createdAsc:
      comparison = a.createdAt.compareTo(b.createdAt);
  }

  // Secondary sort by name if primary comparison is equal
  if (comparison == 0) {
    comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }
  return comparison;
}

/// Provider for investment count by status (for filter tabs)
/// Uses separate streams for active and archived investments.
final investmentCountsProvider =
    Provider<({int all, int open, int closed, int archived})>((ref) {
      final activeInvestments = ref.watch(allInvestmentsProvider).value ?? [];
      final archivedInvestments =
          ref.watch(archivedInvestmentsProvider).value ?? [];
      return (
        all: activeInvestments.length,
        open: activeInvestments
            .where((i) => i.status == InvestmentStatus.open)
            .length,
        closed: activeInvestments
            .where((i) => i.status == InvestmentStatus.closed)
            .length,
        archived: archivedInvestments.length,
      );
    });
