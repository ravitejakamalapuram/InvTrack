/// Stats calculation providers for investments.
/// All stats derive from stream providers for automatic updates.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

// Re-export stats entities
export 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';

// ============ INDIVIDUAL INVESTMENT STATS ============

/// Calculate stats for a single active investment (reactive - watches the stream)
final investmentStatsProvider =
    Provider.family<AsyncValue<InvestmentStats>, String>((ref, investmentId) {
      final cashFlowsAsync = ref.watch(
        cashFlowsByInvestmentProvider(investmentId),
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
      final cashFlowsAsync = ref.watch(
        cashFlowsByInvestmentProvider(investmentId),
      );

      return cashFlowsAsync.when(
        data: (cashFlows) {
          if (cashFlows.isEmpty) {
            return AsyncValue.data(InvestmentStats.empty());
          }
          // Optimization: Skip XIRR calculation
          return AsyncValue.data(
            calculateStats(cashFlows, includeXirr: false),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
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
          return AsyncValue.data(
            calculateStats(cashFlows, includeXirr: false),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
      );
    });

/// XIRR ONLY provider for active investments (isolates expensive calculation).
/// Use this in conjunction with basic stats to avoid re-calculating totals.
final investmentXirrProvider = Provider.family<AsyncValue<double>, String>((
  ref,
  investmentId,
) {
  final cashFlowsAsync = ref.watch(cashFlowsByInvestmentProvider(investmentId));

  return cashFlowsAsync.when(
    data: (cashFlows) {
      if (cashFlows.isEmpty) {
        return const AsyncValue.data(0.0);
      }
      return AsyncValue.data(
        FinancialCalculator.calculateXirrFromCashFlows(cashFlows),
      );
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});

/// XIRR ONLY provider for archived investments.
final archivedInvestmentXirrProvider =
    Provider.family<AsyncValue<double>, String>((ref, investmentId) {
      final cashFlowsAsync = ref.watch(
        archivedCashFlowsByInvestmentProvider(investmentId),
      );

      return cashFlowsAsync.when(
        data: (cashFlows) {
          if (cashFlows.isEmpty) {
            return const AsyncValue.data(0.0);
          }
          return AsyncValue.data(
            FinancialCalculator.calculateXirrFromCashFlows(cashFlows),
          );
        },
        loading: () => const AsyncValue.loading(),
        error: (e, st) => AsyncValue.error(e, st),
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

  // Sort by date for date range extraction
  final sorted = List<CashFlowEntity>.from(cashFlows)
    ..sort((a, b) => a.date.compareTo(b.date));

  // Use FinancialCalculator for all calculations
  final totalInvested = FinancialCalculator.calculateTotalInvested(cashFlows);
  final totalReturned = FinancialCalculator.calculateTotalReturned(cashFlows);
  final netCashFlow = FinancialCalculator.calculateNetCashFlow(
    totalInvested,
    totalReturned,
  );
  final absoluteReturn = FinancialCalculator.calculateAbsoluteReturn(
    totalInvested,
    totalReturned,
  );
  final moic = FinancialCalculator.calculateMOIC(totalInvested, totalReturned);

  // Skip XIRR calculation if not requested (performance optimization)
  final xirr =
      includeXirr
          ? FinancialCalculator.calculateXirrFromCashFlows(cashFlows)
          : 0.0;

  return InvestmentStats(
    totalInvested: totalInvested,
    totalReturned: totalReturned,
    netCashFlow: netCashFlow,
    absoluteReturn: absoluteReturn,
    moic: moic,
    xirr: xirr,
    cashFlowCount: cashFlows.length,
    firstCashFlowDate: sorted.first.date,
    lastCashFlowDate: sorted.last.date,
  );
}
