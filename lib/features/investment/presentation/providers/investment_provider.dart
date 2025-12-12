import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/sync/presentation/providers/sync_provider.dart';
import 'package:uuid/uuid.dart';

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

/// Get all cash flows (for global calculations)
final allCashFlowsProvider = FutureProvider<List<CashFlowEntity>>((ref) async {
  return ref.watch(investmentRepositoryProvider).getAllCashFlows();
});

/// Get recent cash flows (last 5)
final recentCashFlowsProvider = FutureProvider<List<CashFlowWithInvestment>>((ref) async {
  final cashFlows = await ref.watch(investmentRepositoryProvider).getAllCashFlows();
  final investments = await ref.watch(investmentRepositoryProvider).getAllInvestments();

  // Create a map of investment ID to investment
  final investmentMap = {for (var inv in investments) inv.id: inv};

  // Sort by date descending and take last 5
  final sorted = List<CashFlowEntity>.from(cashFlows)
    ..sort((a, b) => b.date.compareTo(a.date));

  return sorted.take(5).map((cf) => CashFlowWithInvestment(
    cashFlow: cf,
    investment: investmentMap[cf.investmentId],
  )).toList();
});

/// Cash flow with associated investment info
class CashFlowWithInvestment {
  final CashFlowEntity cashFlow;
  final InvestmentEntity? investment;

  CashFlowWithInvestment({required this.cashFlow, this.investment});
}

// ============ INVESTMENT STATS ============

/// Investment statistics for display
class InvestmentStats {
  final double totalInvested;   // Sum of INVEST + FEE
  final double totalReturned;   // Sum of RETURN + INCOME
  final double netCashFlow;     // Returned - Invested
  final double absoluteReturn;  // Percentage return
  final double moic;            // Multiple on Invested Capital
  final double xirr;            // Annualized return
  final int cashFlowCount;
  final DateTime? firstCashFlowDate;
  final DateTime? lastCashFlowDate;

  InvestmentStats({
    required this.totalInvested,
    required this.totalReturned,
    required this.netCashFlow,
    required this.absoluteReturn,
    required this.moic,
    required this.xirr,
    required this.cashFlowCount,
    this.firstCashFlowDate,
    this.lastCashFlowDate,
  });

  factory InvestmentStats.empty() => InvestmentStats(
        totalInvested: 0,
        totalReturned: 0,
        netCashFlow: 0,
        absoluteReturn: 0,
        moic: 0,
        xirr: 0,
        cashFlowCount: 0,
      );

  bool get hasData => cashFlowCount > 0;
  bool get isProfit => netCashFlow > 0;
  bool get isLoss => netCashFlow < 0;
}

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

/// Calculate global stats across all investments
final globalStatsProvider = FutureProvider<InvestmentStats>((ref) async {
  final cashFlows = await ref.watch(investmentRepositoryProvider).getAllCashFlows();

  if (cashFlows.isEmpty) {
    return InvestmentStats.empty();
  }

  return _calculateStats(cashFlows);
});

/// Stats for closed investments only (realized gains)
final closedInvestmentsStatsProvider = FutureProvider<InvestmentStats>((ref) async {
  final investments = await ref.watch(investmentRepositoryProvider).getAllInvestments();
  final closedIds = investments
      .where((i) => i.status == InvestmentStatus.closed)
      .map((i) => i.id)
      .toSet();

  if (closedIds.isEmpty) {
    return InvestmentStats.empty();
  }

  final allCashFlows = await ref.watch(investmentRepositoryProvider).getAllCashFlows();
  final closedCashFlows = allCashFlows.where((cf) => closedIds.contains(cf.investmentId)).toList();

  if (closedCashFlows.isEmpty) {
    return InvestmentStats.empty();
  }

  return _calculateStats(closedCashFlows);
});

/// Stats for open investments only (unrealized)
final openInvestmentsStatsProvider = FutureProvider<InvestmentStats>((ref) async {
  final investments = await ref.watch(investmentRepositoryProvider).getAllInvestments();
  final openIds = investments
      .where((i) => i.status == InvestmentStatus.open)
      .map((i) => i.id)
      .toSet();

  if (openIds.isEmpty) {
    return InvestmentStats.empty();
  }

  final allCashFlows = await ref.watch(investmentRepositoryProvider).getAllCashFlows();
  final openCashFlows = allCashFlows.where((cf) => openIds.contains(cf.investmentId)).toList();

  if (openCashFlows.isEmpty) {
    return InvestmentStats.empty();
  }

  return _calculateStats(openCashFlows);
});

/// Investment with its stats for display
class InvestmentWithStats {
  final InvestmentEntity investment;
  final InvestmentStats stats;

  InvestmentWithStats({required this.investment, required this.stats});
}

/// Recently closed investments (last 5)
final recentlyClosedInvestmentsProvider = FutureProvider<List<InvestmentWithStats>>((ref) async {
  final investments = await ref.watch(investmentRepositoryProvider).getAllInvestments();
  final closed = investments
      .where((i) => i.status == InvestmentStatus.closed)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  final recentClosed = closed.take(3).toList();
  final result = <InvestmentWithStats>[];

  for (final inv in recentClosed) {
    final cashFlows = await ref.watch(investmentRepositoryProvider).getCashFlowsByInvestment(inv.id);
    final stats = cashFlows.isEmpty ? InvestmentStats.empty() : _calculateStats(cashFlows);
    result.add(InvestmentWithStats(investment: inv, stats: stats));
  }

  return result;
});

/// Top performers by XIRR (top 3 with positive XIRR)
final topPerformersProvider = FutureProvider<List<InvestmentWithStats>>((ref) async {
  final investments = await ref.watch(investmentRepositoryProvider).getAllInvestments();
  final result = <InvestmentWithStats>[];

  for (final inv in investments) {
    final cashFlows = await ref.watch(investmentRepositoryProvider).getCashFlowsByInvestment(inv.id);
    if (cashFlows.isEmpty) continue;
    final stats = _calculateStats(cashFlows);
    if (stats.xirr > 0 && !stats.xirr.isNaN && !stats.xirr.isInfinite) {
      result.add(InvestmentWithStats(investment: inv, stats: stats));
    }
  }

  // Sort by XIRR descending and take top 3
  result.sort((a, b) => b.stats.xirr.compareTo(a.stats.xirr));
  return result.take(3).toList();
});

/// Monthly cash flow data for trends
class MonthlyCashFlowData {
  final DateTime month;
  final double inflows;
  final double outflows;

  MonthlyCashFlowData({required this.month, required this.inflows, required this.outflows});

  double get net => inflows - outflows;
}

/// Monthly cash flow trend (last 6 months)
final monthlyCashFlowTrendProvider = FutureProvider<List<MonthlyCashFlowData>>((ref) async {
  final cashFlows = await ref.watch(investmentRepositoryProvider).getAllCashFlows();

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

  return result;
});

/// Investment type distribution
class TypeDistribution {
  final InvestmentType type;
  final double totalInvested;
  final int count;

  TypeDistribution({required this.type, required this.totalInvested, required this.count});
}

/// Distribution by investment type
final investmentTypeDistributionProvider = FutureProvider<List<TypeDistribution>>((ref) async {
  final investments = await ref.watch(investmentRepositoryProvider).getAllInvestments();
  final distribution = <InvestmentType, TypeDistribution>{};

  for (final inv in investments) {
    final cashFlows = await ref.watch(investmentRepositoryProvider).getCashFlowsByInvestment(inv.id);
    final invested = cashFlows.where((cf) => cf.type.isOutflow).fold<double>(0, (sum, cf) => sum + cf.amount);

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

  return result;
});

/// YoY comparison stats
class YoYComparison {
  final double thisYearNet;
  final double lastYearNet;
  final double thisYearInvested;
  final double lastYearInvested;
  final double thisYearReturned;
  final double lastYearReturned;

  YoYComparison({
    required this.thisYearNet,
    required this.lastYearNet,
    required this.thisYearInvested,
    required this.lastYearInvested,
    required this.thisYearReturned,
    required this.lastYearReturned,
  });

  double get netChange => lastYearNet != 0 ? ((thisYearNet - lastYearNet) / lastYearNet.abs()) * 100 : 0;
  bool get isImproved => thisYearNet > lastYearNet;
}

/// Year over Year comparison
final yoyComparisonProvider = FutureProvider<YoYComparison>((ref) async {
  final cashFlows = await ref.watch(investmentRepositoryProvider).getAllCashFlows();

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

  return YoYComparison(
    thisYearNet: thisYearReturned - thisYearInvested,
    lastYearNet: lastYearReturned - lastYearInvested,
    thisYearInvested: thisYearInvested,
    lastYearInvested: lastYearInvested,
    thisYearReturned: thisYearReturned,
    lastYearReturned: lastYearReturned,
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
      _triggerSync();
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
      _triggerSync();
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
      _triggerSync();
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
      _triggerSync();
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
      _triggerSync();
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
      _triggerSync();
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
      _triggerSync();
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
      _triggerSync();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void _invalidateAll() {
    _ref.invalidate(allInvestmentsProvider);
    _ref.invalidate(globalStatsProvider);
    _ref.invalidate(allCashFlowsProvider);
    _ref.invalidate(recentCashFlowsProvider);
    _ref.invalidate(closedInvestmentsStatsProvider);
    _ref.invalidate(openInvestmentsStatsProvider);
    _ref.invalidate(topPerformersProvider);
    _ref.invalidate(recentlyClosedInvestmentsProvider);
  }

  /// Trigger sync to Google Sheets.
  /// Marks data as modified which schedules a debounced sync.
  void _triggerSync() {
    _ref.read(syncStatusProvider.notifier).markDataModified();
  }
}
