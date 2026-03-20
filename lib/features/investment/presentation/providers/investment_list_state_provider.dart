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
  final InvestmentType? typeFilter;

  const InvestmentListState({
    this.isSearching = false,
    this.searchQuery = '',
    this.filter = InvestmentFilter.all,
    this.sort = InvestmentSort.lastActivity,
    this.isSelectionMode = false,
    this.selectedIds = const {},
    this.typeFilter,
  });

  /// Whether a type filter is active
  bool get hasTypeFilter => typeFilter != null;

  InvestmentListState copyWith({
    bool? isSearching,
    String? searchQuery,
    InvestmentFilter? filter,
    InvestmentSort? sort,
    bool? isSelectionMode,
    Set<String>? selectedIds,
    InvestmentType? typeFilter,
    bool clearTypeFilter = false,
  }) {
    return InvestmentListState(
      isSearching: isSearching ?? this.isSearching,
      searchQuery: searchQuery ?? this.searchQuery,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      selectedIds: selectedIds ?? this.selectedIds,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
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

  void setTypeFilter(InvestmentType? type) {
    if (type == null) {
      state = state.copyWith(clearTypeFilter: true);
    } else {
      state = state.copyWith(typeFilter: type);
    }
  }

  void clearTypeFilter() {
    state = state.copyWith(clearTypeFilter: true);
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
/// Uses .autoDispose to prevent memory leaks when screen is disposed
final investmentListStateProvider =
    NotifierProvider.autoDispose<InvestmentListNotifier, InvestmentListState>(
      InvestmentListNotifier.new,
    );

/// Provider for filtered and sorted investments
/// Uses separate streams for active and archived investments for complete isolation.
/// Uses .autoDispose since it's only used in investment_list_screen and its widgets
final filteredInvestmentsProvider =
    Provider.autoDispose<AsyncValue<List<InvestmentEntity>>>((ref) {
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

          // Apply type filter
          if (listState.hasTypeFilter) {
            filtered = filtered
                .where((inv) => inv.type == listState.typeFilter)
                .toList();
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

          // OPTIMIZATION: Get basic stats map directly for active investments
          // This avoids N ref.watches inside the loop
          final basicStatsMapAsync =
              !requiresXirr && listState.filter != InvestmentFilter.archived
              ? ref.watch(activeInvestmentBasicStatsMapProvider)
              : null;
          final basicStatsMap = basicStatsMapAsync?.value;

          for (final inv in filtered) {
            // PERFORMANCE OPTIMIZATION:
            // Use basic stats provider (no XIRR) unless explicitly sorting by XIRR.
            // Also correctly handle archived vs active investments.
            final AsyncValue<InvestmentStats> statsAsync;

            if (inv.isArchived) {
              statsAsync = requiresXirr
                  ? ref.watch(archivedInvestmentStatsProvider(inv.id))
                  : ref.watch(archivedInvestmentBasicStatsProvider(inv.id));
              statsCache[inv.id] = statsAsync.value;
            } else {
              if (requiresXirr) {
                statsAsync = ref.watch(investmentStatsProvider(inv.id));
                statsCache[inv.id] = statsAsync.value;
              } else {
                // Use map lookup if available for O(1) access without creating listeners
                if (basicStatsMap != null) {
                  final stats =
                      basicStatsMap[inv.id] ?? InvestmentStats.empty();
                  statsCache[inv.id] = stats;
                } else {
                  // Fallback (should rarely be reached for active investments)
                  statsAsync = ref.watch(investmentBasicStatsProvider(inv.id));
                  statsCache[inv.id] = statsAsync.value;
                }
              }
            }
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
    case InvestmentSort.maturityDateAsc:
      // Sort by maturity date (soonest first)
      // Investments without maturity date go to the end
      final maturityA = a.maturityDate;
      final maturityB = b.maturityDate;
      if (maturityA == null && maturityB == null) {
        comparison = 0;
      } else if (maturityA == null) {
        comparison = 1; // A goes after B
      } else if (maturityB == null) {
        comparison = -1; // A goes before B
      } else {
        comparison = maturityA.compareTo(maturityB);
      }
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

      int openCount = 0;
      int closedCount = 0;
      for (final i in activeInvestments) {
        if (i.status == InvestmentStatus.open) {
          openCount++;
        } else if (i.status == InvestmentStatus.closed) {
          closedCount++;
        }
      }

      return (
        all: activeInvestments.length,
        open: openCount,
        closed: closedCount,
        archived: archivedInvestments.length,
      );
    });
