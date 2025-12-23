import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:uuid/uuid.dart';

export 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';

// ============ INVESTMENT PROVIDERS ============

/// Watch all investments (reactive)
final allInvestmentsProvider = StreamProvider<List<InvestmentEntity>>((ref) {
  return ref.watch(investmentRepositoryProvider).watchAllInvestments();
});

/// Watch investments by status
final investmentsByStatusProvider =
    StreamProvider.family<List<InvestmentEntity>, InvestmentStatus>((ref, status) {
  return ref.watch(investmentRepositoryProvider).watchInvestmentsByStatus(status);
});

/// Get a single investment by ID
final investmentByIdProvider = FutureProvider.family<InvestmentEntity?, String>((ref, id) async {
  return ref.watch(investmentRepositoryProvider).getInvestmentById(id);
});

// ============ CASH FLOW PROVIDERS ============

/// Watch cash flows for an investment (reactive)
final cashFlowsByInvestmentProvider =
    StreamProvider.family<List<CashFlowEntity>, String>((ref, investmentId) {
  return ref.watch(investmentRepositoryProvider).watchCashFlowsByInvestment(investmentId);
});

/// Watch all cash flows (reactive stream - single source of truth)
final allCashFlowsStreamProvider = StreamProvider<List<CashFlowEntity>>((ref) {
  return ref.watch(investmentRepositoryProvider).watchAllCashFlows();
});

/// Filtered cash flows for valid investments only (derived from streams)
/// This is the SINGLE SOURCE OF TRUTH for all stats calculations
final validCashFlowsProvider = Provider<AsyncValue<List<CashFlowEntity>>>((ref) {
  final investmentsAsync = ref.watch(allInvestmentsProvider);
  final cashFlowsAsync = ref.watch(allCashFlowsStreamProvider);

  return investmentsAsync.when(
    data: (investments) {
      final validIds = investments.map((i) => i.id).toSet();
      return cashFlowsAsync.when(
        data: (cashFlows) => AsyncValue.data(
          cashFlows.where((cf) => validIds.contains(cf.investmentId)).toList(),
        ),
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

// ============ INVESTMENT STATS ============
// All stats providers derive from streams - ensuring single source of truth
// and automatic updates across all screens

/// Calculate stats for a single investment (reactive - watches the stream)
final investmentStatsProvider =
    Provider.family<AsyncValue<InvestmentStats>, String>((ref, investmentId) {
  final cashFlowsAsync = ref.watch(cashFlowsByInvestmentProvider(investmentId));

  return cashFlowsAsync.when(
    data: (cashFlows) {
      if (cashFlows.isEmpty) {
        return AsyncValue.data(InvestmentStats.empty());
      }
      return AsyncValue.data(_calculateStats(cashFlows));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Global stats across all investments (derived from streams - auto-updates)
final globalStatsProvider = Provider<AsyncValue<InvestmentStats>>((ref) {
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  return cashFlowsAsync.when(
    data: (cashFlows) {
      if (cashFlows.isEmpty) {
        return AsyncValue.data(InvestmentStats.empty());
      }
      return AsyncValue.data(_calculateStats(cashFlows));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Stats for closed investments only (derived from streams - auto-updates)
final closedInvestmentsStatsProvider = Provider<AsyncValue<InvestmentStats>>((ref) {
  final investmentsAsync = ref.watch(allInvestmentsProvider);
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  return investmentsAsync.when(
    data: (investments) {
      final closedIds = investments
          .where((i) => i.status == InvestmentStatus.closed)
          .map((i) => i.id)
          .toSet();

      if (closedIds.isEmpty) {
        return AsyncValue.data(InvestmentStats.empty());
      }

      return cashFlowsAsync.when(
        data: (cashFlows) {
          final closedCashFlows = cashFlows
              .where((cf) => closedIds.contains(cf.investmentId))
              .toList();
          if (closedCashFlows.isEmpty) {
            return AsyncValue.data(InvestmentStats.empty());
          }
          return AsyncValue.data(_calculateStats(closedCashFlows));
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Stats for open investments only (derived from streams - auto-updates)
final openInvestmentsStatsProvider = Provider<AsyncValue<InvestmentStats>>((ref) {
  final investmentsAsync = ref.watch(allInvestmentsProvider);
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  return investmentsAsync.when(
    data: (investments) {
      final openIds = investments
          .where((i) => i.status == InvestmentStatus.open)
          .map((i) => i.id)
          .toSet();

      if (openIds.isEmpty) {
        return AsyncValue.data(InvestmentStats.empty());
      }

      return cashFlowsAsync.when(
        data: (cashFlows) {
          final openCashFlows = cashFlows
              .where((cf) => openIds.contains(cf.investmentId))
              .toList();
          if (openCashFlows.isEmpty) {
            return AsyncValue.data(InvestmentStats.empty());
          }
          return AsyncValue.data(_calculateStats(openCashFlows));
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Investment with its stats for display
class InvestmentWithStats {
  final InvestmentEntity investment;
  final InvestmentStats stats;

  InvestmentWithStats({required this.investment, required this.stats});
}

/// Recently closed investments (derived from streams - auto-updates)
final recentlyClosedInvestmentsProvider = Provider<AsyncValue<List<InvestmentWithStats>>>((ref) {
  final investmentsAsync = ref.watch(allInvestmentsProvider);
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  return investmentsAsync.when(
    data: (investments) {
      final closed = investments
          .where((i) => i.status == InvestmentStatus.closed)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final recentClosed = closed.take(3).toList();

      return cashFlowsAsync.when(
        data: (allCashFlows) {
          final result = <InvestmentWithStats>[];
          for (final inv in recentClosed) {
            final invCashFlows = allCashFlows
                .where((cf) => cf.investmentId == inv.id)
                .toList();
            final stats = invCashFlows.isEmpty
                ? InvestmentStats.empty()
                : _calculateStats(invCashFlows);
            result.add(InvestmentWithStats(investment: inv, stats: stats));
          }
          return AsyncValue.data(result);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Monthly cash flow trend (derived from streams - auto-updates)
final monthlyCashFlowTrendProvider = Provider<AsyncValue<List<MonthlyCashFlowData>>>((ref) {
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  return cashFlowsAsync.when(
    data: (cashFlows) {
      // Get last 6 months
      final now = DateTime.now();
      final months = List.generate(6, (i) {
        final date = DateTime(now.year, now.month - i, 1);
        return DateTime(date.year, date.month, 1);
      }).reversed.toList();

      final result = <MonthlyCashFlowData>[];

      for (final month in months) {
        final nextMonth = DateTime(month.year, month.month + 1, 1);
        double inflows = 0;
        double outflows = 0;

        for (final cf in cashFlows) {
          if (cf.date.isAfter(month.subtract(const Duration(days: 1))) &&
              cf.date.isBefore(nextMonth)) {
            if (cf.type.isOutflow) {
              outflows += cf.amount;
            } else {
              inflows += cf.amount;
            }
          }
        }

        result.add(MonthlyCashFlowData(month: month, inflows: inflows, outflows: outflows));
      }

      return AsyncValue.data(result);
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Distribution by investment type (derived from streams - auto-updates)
final investmentTypeDistributionProvider = Provider<AsyncValue<List<TypeDistribution>>>((ref) {
  final investmentsAsync = ref.watch(allInvestmentsProvider);
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  return investmentsAsync.when(
    data: (investments) {
      return cashFlowsAsync.when(
        data: (allCashFlows) {
          final distribution = <InvestmentType, TypeDistribution>{};

          for (final inv in investments) {
            final invCashFlows = allCashFlows.where((cf) => cf.investmentId == inv.id);
            final invested = invCashFlows
                .where((cf) => cf.type.isOutflow)
                .fold<double>(0, (sum, cf) => sum + cf.amount);

            if (distribution.containsKey(inv.type)) {
              final existing = distribution[inv.type]!;
              distribution[inv.type] = TypeDistribution(
                type: inv.type,
                totalInvested: existing.totalInvested + invested,
                count: existing.count + 1,
              );
            } else {
              distribution[inv.type] = TypeDistribution(
                type: inv.type,
                totalInvested: invested,
                count: 1,
              );
            }
          }

          final result = distribution.values.toList()
            ..sort((a, b) => b.totalInvested.compareTo(a.totalInvested));

          return AsyncValue.data(result);
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Year over Year comparison (derived from streams - auto-updates)
final yoyComparisonProvider = Provider<AsyncValue<YoYComparison>>((ref) {
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  return cashFlowsAsync.when(
    data: (cashFlows) {
      final now = DateTime.now();
      final thisYearStart = DateTime(now.year, 1, 1);
      final lastYearStart = DateTime(now.year - 1, 1, 1);
      final lastYearEnd = DateTime(now.year, 1, 1);

      double thisYearInvested = 0, thisYearReturned = 0;
      double lastYearInvested = 0, lastYearReturned = 0;

      for (final cf in cashFlows) {
        // This year
        if (!cf.date.isBefore(thisYearStart)) {
          if (cf.type.isOutflow) {
            thisYearInvested += cf.amount;
          } else {
            thisYearReturned += cf.amount;
          }
        }
        // Last year
        else if (!cf.date.isBefore(lastYearStart) && cf.date.isBefore(lastYearEnd)) {
          if (cf.type.isOutflow) {
            lastYearInvested += cf.amount;
          } else {
            lastYearReturned += cf.amount;
          }
        }
      }

      return AsyncValue.data(YoYComparison(
        thisYearNet: thisYearReturned - thisYearInvested,
        lastYearNet: lastYearReturned - lastYearInvested,
        thisYearInvested: thisYearInvested,
        lastYearInvested: lastYearInvested,
        thisYearReturned: thisYearReturned,
        lastYearReturned: lastYearReturned,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Helper to calculate stats from cash flows
InvestmentStats _calculateStats(List<CashFlowEntity> cashFlows) {
  double totalInvested = 0;
  double totalReturned = 0;

  // Sort by date
  final sorted = List<CashFlowEntity>.from(cashFlows)
    ..sort((a, b) => a.date.compareTo(b.date));

  for (final cf in sorted) {
    if (cf.type.isOutflow) {
      totalInvested += cf.amount;
    } else {
      totalReturned += cf.amount;
    }
  }

  final netCashFlow = totalReturned - totalInvested;
  final absoluteReturn = totalInvested > 0 ? (netCashFlow / totalInvested) * 100 : 0.0;
  final moic = totalInvested > 0 ? totalReturned / totalInvested : 0.0;

  // Calculate XIRR
  final xirr = FinancialCalculator.calculateXirrFromCashFlows(cashFlows);

  return InvestmentStats(
    totalInvested: totalInvested,
    totalReturned: totalReturned,
    netCashFlow: netCashFlow,
    absoluteReturn: absoluteReturn,
    moic: moic,
    xirr: xirr,
    cashFlowCount: cashFlows.length,
    firstCashFlowDate: sorted.isNotEmpty ? sorted.first.date : null,
    lastCashFlowDate: sorted.isNotEmpty ? sorted.last.date : null,
  );
}

// ============ INVESTMENT NOTIFIER (ACTIONS) ============

final investmentNotifierProvider =
    StateNotifierProvider<InvestmentNotifier, AsyncValue<void>>((ref) {
  return InvestmentNotifier(ref);
});

class InvestmentNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  InvestmentNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Create a new investment
  Future<InvestmentEntity> addInvestment({
    required String name,
    required InvestmentType type,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final investment = InvestmentEntity(
        id: const Uuid().v4(),
        name: name,
        type: type,
        status: InvestmentStatus.open,
        notes: notes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _ref.read(investmentRepositoryProvider).createInvestment(investment);

      _invalidateAll();
      state = const AsyncValue.data(null);
      return investment;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update an existing investment
  Future<void> updateInvestment({
    required String id,
    required String name,
    required InvestmentType type,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final existing = await _ref.read(investmentRepositoryProvider).getInvestmentById(id);
      if (existing == null) throw Exception('Investment not found');

      final updated = existing.copyWith(
        name: name,
        type: type,
        notes: notes,
        updatedAt: DateTime.now(),
      );
      await _ref.read(investmentRepositoryProvider).updateInvestment(updated);

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Close an investment
  Future<void> closeInvestment(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(investmentRepositoryProvider).closeInvestment(id);
      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Reopen a closed investment
  Future<void> reopenInvestment(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(investmentRepositoryProvider).reopenInvestment(id);
      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Delete an investment
  Future<void> deleteInvestment(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(investmentRepositoryProvider).deleteInvestment(id);
      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Add a cash flow to an investment
  Future<void> addCashFlow({
    required String investmentId,
    required CashFlowType type,
    required double amount,
    required DateTime date,
    String? notes,
  }) async {
    state = const AsyncValue.loading();
    try {
      final cashFlow = CashFlowEntity(
        id: const Uuid().v4(),
        investmentId: investmentId,
        type: type,
        amount: amount,
        date: date,
        notes: notes,
        createdAt: DateTime.now(),
      );
      await _ref.read(investmentRepositoryProvider).addCashFlow(cashFlow);

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update a cash flow
  Future<void> updateCashFlow({
    required String id,
    required String investmentId,
    required CashFlowType type,
    required double amount,
    required DateTime date,
    String? notes,
    required DateTime createdAt,
  }) async {
    state = const AsyncValue.loading();
    try {
      final cashFlow = CashFlowEntity(
        id: id,
        investmentId: investmentId,
        type: type,
        amount: amount,
        date: date,
        notes: notes,
        createdAt: createdAt,
      );
      await _ref.read(investmentRepositoryProvider).updateCashFlow(cashFlow);

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Delete a cash flow
  Future<void> deleteCashFlow(String id) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(investmentRepositoryProvider).deleteCashFlow(id);
      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Merge multiple investments into one
  /// If [type] is provided, use it; otherwise fall back to most common type among merged investments
  Future<void> mergeInvestments(List<String> investmentIds, String newName, {InvestmentType? type}) async {
    if (investmentIds.length < 2) return;

    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(investmentRepositoryProvider);

      // Get all investments to merge
      final allInvestments = await _ref.read(allInvestmentsProvider.future);
      final toMerge = allInvestments.where((i) => investmentIds.contains(i.id)).toList();

      if (toMerge.isEmpty) {
        state = const AsyncValue.data(null);
        return;
      }

      // Use provided type, or fall back to first investment's type, or most common type
      InvestmentType finalType;
      if (type != null) {
        finalType = type;
      } else {
        final typeCount = <InvestmentType, int>{};
        for (final inv in toMerge) {
          typeCount[inv.type] = (typeCount[inv.type] ?? 0) + 1;
        }
        finalType = typeCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
      }

      // Create new merged investment
      final now = DateTime.now();
      final newInvestmentId = const Uuid().v4();
      final newInvestment = InvestmentEntity(
        id: newInvestmentId,
        name: newName,
        type: finalType,
        status: toMerge.any((i) => i.status == InvestmentStatus.open)
            ? InvestmentStatus.open
            : InvestmentStatus.closed,
        notes: 'Merged from: ${toMerge.map((i) => i.name).join(', ')}',
        createdAt: now,
        updatedAt: now,
      );

      // Collect all cash flows from merged investments (prepare in memory first)
      final newCashFlows = <CashFlowEntity>[];
      for (final inv in toMerge) {
        final cashFlows = await repo.getCashFlowsByInvestment(inv.id);
        for (final cf in cashFlows) {
          newCashFlows.add(CashFlowEntity(
            id: const Uuid().v4(),
            investmentId: newInvestmentId,
            type: cf.type,
            amount: cf.amount,
            date: cf.date,
            notes: cf.notes != null ? '${cf.notes} (from ${inv.name})' : 'From ${inv.name}',
            createdAt: now,
          ));
        }
      }

      // Use bulk import for efficient batch writes
      await repo.bulkImport(
        investments: [newInvestment],
        cashFlows: newCashFlows,
      );

      // Delete old investments
      for (final id in investmentIds) {
        await repo.deleteInvestment(id);
      }

      _invalidateAll();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Bulk import investments with their cash flows.
  /// This is optimized for importing large amounts of data quickly.
  /// Data is written in batches and providers are only invalidated once at the end.
  Future<({int investments, int cashFlows})> bulkImport({
    required List<InvestmentEntity> investments,
    required List<CashFlowEntity> cashFlows,
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = await _ref.read(investmentRepositoryProvider).bulkImport(
        investments: investments,
        cashFlows: cashFlows,
      );

      // Only invalidate once after all data is imported
      _invalidateAll();
      state = const AsyncValue.data(null);
      return result;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  // Note: With stream-based architecture, manual invalidation is largely unnecessary.
  // Firestore streams auto-update, and derived providers reactively recompute.
  // This method is kept for edge cases (e.g., forcing refresh after error recovery).
  void _invalidateAll() {
    // Only invalidate the base stream providers - derived providers auto-update
    _ref.invalidate(allInvestmentsProvider);
    _ref.invalidate(allCashFlowsStreamProvider);
  }
}
