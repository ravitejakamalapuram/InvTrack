/// Stats calculation providers for investments.
/// All stats derive from stream providers for automatic updates.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/performance/performance_provider.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

// Re-export stats entities
export 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';

// ============ INDIVIDUAL INVESTMENT STATS ============

/// Map of all active investment stats (basic only, no XIRR)
/// Computed from a single stream to avoid N+1 stream problem.
final activeInvestmentBasicStatsMapProvider =
    Provider<AsyncValue<Map<String, InvestmentStats>>>((ref) {
      final investmentsAsync = ref.watch(activeInvestmentsProvider);
      final cashFlowsAsync = ref.watch(validCashFlowsProvider);

      // Wait for both to load
      if (investmentsAsync.isLoading || cashFlowsAsync.isLoading) {
        return const AsyncValue.loading();
      }

      if (investmentsAsync.hasError) {
        return AsyncValue.error(
          investmentsAsync.error!,
          investmentsAsync.stackTrace!,
        );
      }
      if (cashFlowsAsync.hasError) {
        return AsyncValue.error(
          cashFlowsAsync.error!,
          cashFlowsAsync.stackTrace!,
        );
      }

      final investments = investmentsAsync.value ?? [];
      final cashFlows = cashFlowsAsync.value ?? [];

      // Group cash flows by investment ID
      final cashFlowsMap = <String, List<CashFlowEntity>>{};
      for (final cf in cashFlows) {
        cashFlowsMap.putIfAbsent(cf.investmentId, () => []).add(cf);
      }

      // Calculate stats for each investment
      final statsMap = <String, InvestmentStats>{};
      for (final inv in investments) {
        final flows = cashFlowsMap[inv.id] ?? [];
        if (flows.isEmpty) {
          statsMap[inv.id] = InvestmentStats.empty();
        } else {
          // Optimization: Skip XIRR calculation
          statsMap[inv.id] = calculateStats(flows, includeXirr: false);
        }
      }

      return AsyncValue.data(statsMap);
    });

/// Top-level function for calculating XIRR for multiple investments in a single isolate.
Map<String, double> _calculateAllXirrs(List<CashFlowEntity> allFlows) {
  final grouped = <String, List<CashFlowEntity>>{};
  for (final cf in allFlows) {
    grouped.putIfAbsent(cf.investmentId, () => []).add(cf);
  }

  final results = <String, double>{};
  for (final entry in grouped.entries) {
    results[entry.key] = FinancialCalculator.calculateXirrFromCashFlows(
      entry.value,
    );
  }
  return results;
}

/// Map of all active investment XIRRs, computed in a single isolate batch.
/// This prevents N+1 isolate overhead when rendering lists.
final activeInvestmentXirrMapProvider = FutureProvider<Map<String, double>>((
  ref,
) async {
  // Wait for valid cash flows to be available
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  if (cashFlowsAsync.isLoading) {
    return Completer<Map<String, double>>().future;
  }

  if (cashFlowsAsync.hasError) {
    throw cashFlowsAsync.error!;
  }

  final cashFlows = cashFlowsAsync.value ?? [];

  if (cashFlows.isEmpty) {
    return {};
  }

  // Track performance of bulk XIRR calculation
  return ref.read(performanceServiceProvider).trackOperation(
    'bulk_xirr_calculation',
    () => compute<List<CashFlowEntity>, Map<String, double>>(
      _calculateAllXirrs,
      cashFlows,
    ),
    metrics: {'total_cash_flows': cashFlows.length},
  );
});

/// Calculate stats for a single active investment (reactive - watches the stream)
final investmentStatsProvider =
    Provider.family<AsyncValue<InvestmentStats>, String>((ref, investmentId) {
      // Use filtered stream to avoid opening per-investment stream
      final cashFlowsAsync = ref.watch(
        validCashFlowsProvider.select((async) {
          return async.whenData((allFlows) {
            return allFlows
                .where((cf) => cf.investmentId == investmentId)
                .toList();
          });
        }),
      );

      return cashFlowsAsync.when(
        data: (cashFlows) {
          if (cashFlows.isEmpty) {
            return AsyncValue.data(InvestmentStats.empty());
          }
          return AsyncValue.data(calculateStats(cashFlows));
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// Calculate stats for a single archived investment (reactive - watches the stream)
final archivedInvestmentStatsProvider =
    Provider.family<AsyncValue<InvestmentStats>, String>((ref, investmentId) {
      final cashFlowsAsync = ref.watch(
        archivedCashFlowsByInvestmentProvider(investmentId),
      );

      return cashFlowsAsync.when(
        data: (cashFlows) {
          if (cashFlows.isEmpty) {
            return AsyncValue.data(InvestmentStats.empty());
          }
          return AsyncValue.data(calculateStats(cashFlows));
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// LIGHTWEIGHT stats for sorting active investments (skips expensive XIRR calculation).
/// Use this provider when sorting by date, name, or simple sums.
final investmentBasicStatsProvider =
    Provider.family<AsyncValue<InvestmentStats>, String>((ref, investmentId) {
      // O(1) lookup from the pre-computed map using select to avoid rebuilds
      return ref.watch(
        activeInvestmentBasicStatsMapProvider.select((mapAsync) {
          return mapAsync.whenData((map) {
            return map[investmentId] ?? InvestmentStats.empty();
          });
        }),
      );
    });

/// LIGHTWEIGHT stats for sorting archived investments (skips expensive XIRR calculation).
final archivedInvestmentBasicStatsProvider =
    Provider.family<AsyncValue<InvestmentStats>, String>((ref, investmentId) {
      final cashFlowsAsync = ref.watch(
        archivedCashFlowsByInvestmentProvider(investmentId),
      );

      return cashFlowsAsync.when(
        data: (cashFlows) {
          if (cashFlows.isEmpty) {
            return AsyncValue.data(InvestmentStats.empty());
          }
          // Optimization: Skip XIRR calculation
          return AsyncValue.data(calculateStats(cashFlows, includeXirr: false));
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// XIRR ONLY provider for active investments (isolates expensive calculation).
/// Use this in conjunction with basic stats to avoid re-calculating totals.
/// Offloads calculation to a background isolate using [compute].
final investmentXirrProvider = FutureProvider.family<double, String>((
  ref,
  investmentId,
) async {
  // Use the bulk calculation provider to avoid N+1 isolate overhead.
  // This waits for the single batch calculation to complete and then
  // returns the specific value for this investment.
  final xirrMap = await ref.watch(activeInvestmentXirrMapProvider.future);

  return xirrMap[investmentId] ?? 0.0;
});

/// XIRR ONLY provider for archived investments.
/// Offloads calculation to a background isolate using [compute].
final archivedInvestmentXirrProvider = FutureProvider.family<double, String>((
  ref,
  investmentId,
) async {
  final cashFlows = await ref.watch(
    archivedCashFlowsByInvestmentProvider(
      investmentId,
    ).selectAsync((data) => data),
  );

  if (cashFlows.isEmpty) {
    return 0.0;
  }

  // OPTIMIZATION: For small number of cash flows (< 50), run synchronously.
  // The overhead of spawning an isolate (latency + memory) exceeds the calculation time.
  // XIRR for < 50 items takes < 1ms on modern devices.
  if (cashFlows.length < 50) {
    return ref.read(performanceServiceProvider).trackSync(
      'xirr_calculation_archived_sync',
      () => FinancialCalculator.calculateXirrFromCashFlows(cashFlows),
      metrics: {'cash_flow_count': cashFlows.length},
    );
  }

  // Track performance of XIRR calculation for archived investments
  return ref.read(performanceServiceProvider).trackOperation(
    'xirr_calculation_archived',
    () => compute(FinancialCalculator.calculateXirrFromCashFlows, cashFlows),
    metrics: {'cash_flow_count': cashFlows.length},
  );
});

// ============ AGGREGATE STATS PROVIDERS ============

/// Global stats across all investments (derived from streams - auto-updates)
final globalStatsProvider = Provider<AsyncValue<InvestmentStats>>((ref) {
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  return cashFlowsAsync.when(
    data: (cashFlows) {
      if (cashFlows.isEmpty) {
        return AsyncValue.data(InvestmentStats.empty());
      }
      return AsyncValue.data(calculateStats(cashFlows));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// Stats for closed investments only (derived from streams - auto-updates)
/// Only includes non-archived investments.
final closedInvestmentsStatsProvider = Provider<AsyncValue<InvestmentStats>>((
  ref,
) {
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
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
          return AsyncValue.data(calculateStats(closedCashFlows));
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
/// Only includes non-archived investments.
final openInvestmentsStatsProvider = Provider<AsyncValue<InvestmentStats>>((
  ref,
) {
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
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
          return AsyncValue.data(calculateStats(openCashFlows));
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

// ============ STATS CALCULATION ============

/// Calculate stats from a list of cash flows.
/// Uses [FinancialCalculator] for all financial calculations to avoid duplication.
///
/// [includeXirr] - Set to false to skip expensive XIRR calculation if not needed
/// (e.g. for simple sorting or lists where XIRR is not displayed).
InvestmentStats calculateStats(
  List<CashFlowEntity> cashFlows, {
  bool includeXirr = true,
}) {
  if (cashFlows.isEmpty) {
    return InvestmentStats.empty();
  }

  // Single pass calculation for O(N) complexity
  double totalInvested = 0.0;
  double totalReturned = 0.0;
  DateTime? firstDate;
  DateTime? lastDate;

  // Pre-allocate lists for XIRR if needed
  final xirrDates = includeXirr ? <DateTime>[] : null;
  final xirrAmounts = includeXirr ? <double>[] : null;

  for (final cf in cashFlows) {
    // 1. Date range
    if (firstDate == null || cf.date.isBefore(firstDate)) {
      firstDate = cf.date;
    }
    if (lastDate == null || cf.date.isAfter(lastDate)) {
      lastDate = cf.date;
    }

    // 2. Totals
    if (cf.type.isOutflow) {
      totalInvested += cf.amount;
    } else if (cf.type.isInflow) {
      totalReturned += cf.amount;
    }

    // 3. XIRR data prep
    if (includeXirr) {
      xirrDates!.add(cf.date);
      xirrAmounts!.add(cf.signedAmount);
    }
  }

  // Calculate derived stats (O(1))
  final netCashFlow = FinancialCalculator.calculateNetCashFlow(
    totalInvested,
    totalReturned,
  );
  final absoluteReturn = FinancialCalculator.calculateAbsoluteReturn(
    totalInvested,
    totalReturned,
  );
  final moic = FinancialCalculator.calculateMOIC(totalInvested, totalReturned);

  // XIRR calculation using pre-populated lists
  final xirr =
      includeXirr
          ? (XirrSolver.calculateXirr(xirrDates!, xirrAmounts!) ?? 0.0)
          : 0.0;

  return InvestmentStats(
    totalInvested: totalInvested,
    totalReturned: totalReturned,
    netCashFlow: netCashFlow,
    absoluteReturn: absoluteReturn,
    moic: moic,
    xirr: xirr,
    cashFlowCount: cashFlows.length,
    firstCashFlowDate: firstDate,
    lastCashFlowDate: lastDate,
  );
}
