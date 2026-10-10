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
import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/core/performance/performance_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/async_value_utils.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';

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
  requireBaseCurrency(converted, baseCurrency);
  return ConvertedCashFlows(
    baseCurrency: baseCurrency,
    cashFlows: converted,
    source: cashFlows,
  );
});

/// Throws a [CurrencyConversionException] if any of [cashFlows] is still in
/// a currency other than [baseCurrency].
///
/// [BatchCurrencyConverter] keeps a flow in its own currency when there is
/// neither a rate nor a last-known rate (offline, first run, a new
/// currency). Summing it would show a native amount under the base-currency
/// symbol, so stats fail visibly instead.
void requireBaseCurrency(List<CashFlowEntity> cashFlows, String baseCurrency) {
  for (final cf in cashFlows) {
    if (cf.currency != baseCurrency) {
      throw CurrencyConversionException(
        'No exchange rate for ${cf.currency} → $baseCurrency',
      );
    }
  }
}

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

/// The clock [valuationDateProvider] reads. Tests override it.
final valuationClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Today, date-only: the date estimated current values are valued at, and
/// the "today" of Year over Year and the health score.
///
/// It moves to the new day soon after local midnight, so an app left open
/// overnight does not keep yesterday's date. The clock is checked once a
/// minute rather than by one timer set for midnight, because timers do not
/// run while the device sleeps; this catches up within a minute of waking.
/// Dependents rebuild only when the date changes.
final valuationDateProvider = Provider<DateTime>((ref) {
  final clock = ref.watch(valuationClockProvider);
  DateTime today() {
    final now = clock();
    return DateTime(now.year, now.month, now.day);
  }

  final date = today();
  final timer = Timer.periodic(const Duration(minutes: 1), (_) {
    if (today() != date) ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return date;
});

/// A converted snapshot with the current values of its active investments.
@immutable
class ConvertedTerminalValues {
  /// The snapshot [byInvestment] was worked out from. Read its cash flows
  /// together with [byInvestment], never another snapshot's: a value must
  /// not meet flows it was not built from.
  final ConvertedCashFlows snapshot;

  /// Terminal inflows by investment id, in the snapshot's base currency.
  final Map<String, TerminalValues> byInvestment;

  const ConvertedTerminalValues({
    required this.snapshot,
    required this.byInvestment,
  });
}

/// The current values of the active investments as terminal inflows,
/// converted to the base currency of the snapshot they come with (money
/// rule 2).
///
/// They are worked out from the unconverted flows, since an estimate accrues
/// on the principal in its own currency and a manual value is in the
/// investment's currency, and then converted in one batch, like the flows.
/// A value with no rate at all counts as missing.
final convertedTerminalValuesProvider = FutureProvider<ConvertedTerminalValues>(
  (ref) async {
    final snapshot = await ref.watch(convertedCashFlowsSnapshotProvider.future);
    // Valid cash flows exist only once the active investments have loaded.
    final investments = ref.watch(activeInvestmentsProvider).value ?? const [];
    final asOf = ref.watch(valuationDateProvider);

    // Dated valuations by investment id: empty while the feature is off.
    final snapshots = await dataOf(
      ref.watch(valuationSnapshotsByInvestmentProvider),
    );

    final flowsByInvestment = <String, List<CashFlowEntity>>{};
    for (final cf in snapshot.source) {
      flowsByInvestment.putIfAbsent(cf.investmentId, () => []).add(cf);
    }
    // Every active investment that has cash flows or a dated valuation: an
    // opening baseline needs no cash flows to be valued.
    final values = <String, TerminalValues>{
      for (final inv in investments)
        if (flowsByInvestment[inv.id] != null ||
            (snapshots[inv.id]?.isNotEmpty ?? false))
          inv.id: CurrentValueCalculator.terminalValues(
            investments: [inv],
            cashFlows: flowsByInvestment[inv.id] ?? const [],
            asOf: asOf,
            snapshots: snapshots,
          ),
    };

    final flows = [for (final value in values.values) ...value.flows];
    // Like the snapshot, the converter is needed only when a value is in
    // another currency.
    final converted = flows.every((cf) => cf.currency == snapshot.baseCurrency)
        ? flows
        : await convertTerminalFlows(
            ref.watch(calculationEngineProvider),
            flows,
            snapshot.baseCurrency,
          );
    final convertedByInvestment = <String, List<CashFlowEntity>>{};
    for (final cf in converted) {
      convertedByInvestment.putIfAbsent(cf.investmentId, () => []).add(cf);
    }
    return ConvertedTerminalValues(
      snapshot: snapshot,
      byInvestment: {
        for (final MapEntry(:key, :value) in values.entries)
          key: value.flows.isEmpty
              ? value
              : value.withConvertedFlows(
                  convertedByInvestment[key] ?? const [],
                ),
      },
    );
  },
);

/// [flows] converted to [baseCurrency], leaving out any that have no rate
/// at all: such a flow stays in its own currency, and adding it would show
/// a native amount under the base-currency symbol.
Future<List<CashFlowEntity>> convertTerminalFlows(
  CalculationEngine engine,
  List<CashFlowEntity> flows,
  String baseCurrency,
) async {
  if (flows.every((cf) => cf.currency == baseCurrency)) return flows;
  final converted = engine.currency.isAvailable
      ? await engine.currency.batchConvert(
          cashFlows: flows,
          baseCurrency: baseCurrency,
          fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
        )
      : flows;
  return [
    for (final cf in converted)
      if (cf.currency == baseCurrency) cf,
  ];
}

// ============ INDIVIDUAL INVESTMENT STATS ============

/// Map of all active investment stats (basic only, no XIRR), in the base
/// currency. Computed from the converted snapshot to avoid the N+1 stream
/// problem.
final activeInvestmentBasicStatsMapProvider =
    Provider<AsyncValue<Map<String, InvestmentStats>>>((ref) {
      final investmentsAsync = ref.watch(activeInvestmentsProvider);
      // The flows and the current values come from one snapshot: while a
      // newer one converts, the previous pair is kept rather than new flows
      // shown with an old value.
      final convertedAsync = ref.watch(convertedTerminalValuesProvider);

      if (investmentsAsync.hasError) {
        return AsyncValue.error(
          investmentsAsync.error ??
              Exception('Unknown error loading investments'),
          investmentsAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (convertedAsync.hasError) {
        return AsyncValue.error(
          convertedAsync.error!,
          convertedAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (!investmentsAsync.hasValue || !convertedAsync.hasValue) {
        return const AsyncValue.loading();
      }
      final converted = convertedAsync.requireValue;
      // Amounts are never shown under a symbol they were not converted to.
      if (converted.snapshot.baseCurrency != ref.watch(currencyCodeProvider)) {
        return const AsyncValue.loading();
      }

      final investments = investmentsAsync.value ?? [];
      final byInvestment = FinancialCalculatorModule()
          .calculateStatsByInvestment(
            converted.snapshot.cashFlows,
            includeXirr: false,
            terminalValues: converted.byInvestment,
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
/// isolate overhead when rendering lists. Open investments include their
/// converted current value as the terminal inflow. An undefined XIRR stays
/// undefined: never read it as 0%.
final activeInvestmentXirrResultMapProvider =
    FutureProvider<Map<String, XirrResult>>((ref) async {
      final converted = await ref.watch(convertedTerminalValuesProvider.future);
      final cashFlows = converted.snapshot.cashFlows;

      if (cashFlows.isEmpty) {
        return {};
      }

      // Investments with limited history have no lifetime XIRR: it would be
      // fabricated from a baseline with no cost or date. Their id is left out,
      // which reads as undefined.
      final limited = <String>{
        for (final value in converted.byInvestment.values)
          ...value.limitedHistoryIds,
      };

      // Each terminal value carries its investment's id, so it joins that
      // investment's group in _calculateAllXirrs.
      final flows = [
        for (final cf in [
          ...cashFlows,
          for (final value in converted.byInvestment.values) ...value.flows,
        ])
          if (!limited.contains(cf.investmentId)) cf,
      ];

      // Track performance of bulk XIRR calculation
      return ref
          .read(performanceServiceProvider)
          .trackOperation(
            'bulk_xirr_calculation',
            () => compute<List<CashFlowEntity>, Map<String, XirrResult>>(
              _calculateAllXirrs,
              flows,
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
  TerminalValues terminalValues = TerminalValues.none,
}) {
  return FinancialCalculatorModule().calculateStats(
    cashFlows,
    includeXirr: includeXirr,
    terminalValues: terminalValues,
  );
}
