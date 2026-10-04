/// Stats calculation providers for investments.
/// All stats derive from stream providers for automatic updates.
///
/// Every amount here is in the user's base currency: the active cash flows
/// are converted once ([convertedCashFlowsSnapshotProvider]) and every map,
/// card, sort and chart reads that one snapshot.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/performance/performance_provider.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

// Re-export stats entities
export 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';

// ============ CONVERTED SNAPSHOT ============

/// The active cash flows, converted once to [baseCurrency].
@immutable
class ConvertedCashFlows {
  /// The currency every amount in [cashFlows] is in.
  final String baseCurrency;

  /// [source] converted to [baseCurrency].
  final List<CashFlowEntity> cashFlows;

  /// The unconverted list this snapshot was built from.
  final List<CashFlowEntity> source;

  const ConvertedCashFlows({
    required this.baseCurrency,
    required this.cashFlows,
    required this.source,
  });
}

/// Converts the active cash flows to the base currency once per change.
///
/// This is the single snapshot every stats screen reads; never sum
/// [validCashFlowsProvider] amounts directly. Flows in another currency fail
/// visibly when no converter is available instead of being summed natively.
final convertedCashFlowsSnapshotProvider = FutureProvider<ConvertedCashFlows>((
  ref,
) async {
  final baseCurrency = ref.watch(currencyCodeProvider);
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  if (cashFlowsAsync.hasError) {
    Error.throwWithStackTrace(
      cashFlowsAsync.error!,
      cashFlowsAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (cashFlowsAsync.isLoading) {
    return Completer<ConvertedCashFlows>().future;
  }

  final cashFlows = cashFlowsAsync.value ?? const <CashFlowEntity>[];
  var needsConversion = false;
  for (final cf in cashFlows) {
    if (cf.currency != baseCurrency) {
      needsConversion = true;
      break;
    }
  }
  if (!needsConversion) {
    return ConvertedCashFlows(
      baseCurrency: baseCurrency,
      cashFlows: cashFlows,
      source: cashFlows,
    );
  }

  final engine = ref.watch(calculationEngineProvider);
  if (!engine.currency.isAvailable) {
    throw StateError('Currency conversion is unavailable');
  }
  final converted = await engine.currency.batchConvert(
    cashFlows: cashFlows,
    baseCurrency: baseCurrency,
    fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
  );
  return ConvertedCashFlows(
    baseCurrency: baseCurrency,
    cashFlows: converted,
    source: cashFlows,
  );
});

/// The active cash flows in the base currency, for synchronous stats.
///
/// Loading until a snapshot in the current base currency exists, so amounts
/// are never shown under a symbol they were not converted to. While the
/// latest change is being converted, the previous snapshot is kept, limited
/// to investments that are still active, so lists do not flicker and nothing
/// from a removed investment (or a previous account) is shown.
final convertedCashFlowsProvider = Provider<AsyncValue<List<CashFlowEntity>>>((
  ref,
) {
  final baseCurrency = ref.watch(currencyCodeProvider);
  final sourceAsync = ref.watch(validCashFlowsProvider);
  final snapshotAsync = ref.watch(convertedCashFlowsSnapshotProvider);

  if (sourceAsync.hasError) {
    return AsyncValue.error(
      sourceAsync.error!,
      sourceAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (snapshotAsync.hasError) {
    return AsyncValue.error(
      snapshotAsync.error!,
      snapshotAsync.stackTrace ?? StackTrace.current,
    );
  }
  final source = sourceAsync.value;
  final snapshot = snapshotAsync.value;
  if (source == null ||
      snapshot == null ||
      snapshot.baseCurrency != baseCurrency) {
    return const AsyncValue.loading();
  }
  if (identical(snapshot.source, source)) {
    return AsyncValue.data(snapshot.cashFlows);
  }

  final activeIds = <String>{for (final cf in source) cf.investmentId};
  return AsyncValue.data([
    for (final cf in snapshot.cashFlows)
      if (activeIds.contains(cf.investmentId)) cf,
  ]);
});

// ============ INDIVIDUAL INVESTMENT STATS ============

/// Map of all active investment stats (basic only, no XIRR), in the base
/// currency. Computed from the converted snapshot to avoid the N+1 stream
/// problem.
final activeInvestmentBasicStatsMapProvider =
    Provider<AsyncValue<Map<String, InvestmentStats>>>((ref) {
      final investmentsAsync = ref.watch(activeInvestmentsProvider);
      final cashFlowsAsync = ref.watch(convertedCashFlowsProvider);

      if (investmentsAsync.hasError) {
        return AsyncValue.error(
          investmentsAsync.error ??
              Exception('Unknown error loading investments'),
          investmentsAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (cashFlowsAsync.hasError) {
        return AsyncValue.error(
          cashFlowsAsync.error ?? Exception('Unknown error loading cash flows'),
          cashFlowsAsync.stackTrace ?? StackTrace.current,
        );
      }
      // Wait for both to load
      if (!investmentsAsync.hasValue || !cashFlowsAsync.hasValue) {
        return const AsyncValue.loading();
      }

      final investments = investmentsAsync.value ?? [];
      final byInvestment = FinancialCalculatorModule()
          .calculateStatsByInvestment(
            cashFlowsAsync.requireValue,
            includeXirr: false,
          );

      return AsyncValue.data({
        for (final inv in investments)
          inv.id: byInvestment[inv.id] ?? InvestmentStats.empty(),
      });
    });

/// Top-level function for calculating XIRR for multiple investments in a single isolate.
Map<String, XirrResult> _calculateAllXirrs(List<CashFlowEntity> allFlows) {
  final grouped = <String, List<CashFlowEntity>>{};
  for (final cf in allFlows) {
    grouped.putIfAbsent(cf.investmentId, () => []).add(cf);
  }

  final results = <String, XirrResult>{};
  for (final entry in grouped.entries) {
    results[entry.key] = FinancialCalculator.solveXirrFromCashFlows(
      entry.value,
    );
  }
  return results;
}

/// Map of all active investment XIRRs with how each was obtained, computed
/// from the converted snapshot in a single isolate batch. This prevents N+1
/// isolate overhead when rendering lists. An undefined XIRR stays undefined:
/// never read it as 0%.
final activeInvestmentXirrResultMapProvider =
    FutureProvider<Map<String, XirrResult>>((ref) async {
      final snapshot = await ref.watch(
        convertedCashFlowsSnapshotProvider.future,
      );
      final cashFlows = snapshot.cashFlows;

      if (cashFlows.isEmpty) {
        return {};
      }

      // Track performance of bulk XIRR calculation
      return ref
          .read(performanceServiceProvider)
          .trackOperation(
            'bulk_xirr_calculation',
            () => compute<List<CashFlowEntity>, Map<String, XirrResult>>(
              _calculateAllXirrs,
              cashFlows,
            ),
            metrics: {'total_cash_flows': cashFlows.length},
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

/// XIRR ONLY provider for active investments (isolates expensive calculation).
/// Use this in conjunction with basic stats to avoid re-calculating totals.
/// Offloads calculation to a background isolate using [compute]. The result
/// says whether the rate is approximate, so the UI can label it.
final investmentXirrProvider = FutureProvider.family<XirrResult, String>((
  ref,
  investmentId,
) async {
  // Use the bulk calculation provider to avoid N+1 isolate overhead.
  // This waits for the single batch calculation to complete and then
  // returns the specific value for this investment.
  final xirrMap = await ref.watch(activeInvestmentXirrResultMapProvider.future);

  return xirrMap[investmentId] ??
      const XirrResult.undefined(XirrUndefinedReason.insufficientFlows);
});

// ============ STATS CALCULATION ============

/// Calculate stats from a list of cash flows already in one currency.
/// Delegates to the unified [FinancialCalculatorModule].
InvestmentStats calculateStats(
  List<CashFlowEntity> cashFlows, {
  bool includeXirr = true,
}) {
  return FinancialCalculatorModule().calculateStats(
    cashFlows,
    includeXirr: includeXirr,
  );
}
