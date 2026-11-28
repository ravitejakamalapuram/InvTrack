import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/stats_off_ui_thread.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/async_value_utils.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
import 'package:inv_tracker/features/investment/presentation/providers/valuation_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'multi_currency_providers.g.dart';

/// Provider for batch currency converter
///
/// **BUG FIX (2026-05-04)**: Handle null conversion service when unauthenticated
/// Returns a no-op converter that doesn't crash the app
@riverpod
BatchCurrencyConverter? batchCurrencyConverter(Ref ref) {
  final conversionService = ref.watch(currencyConversionServiceProvider);

  // Return null if user is not authenticated
  // Call sites should check for null and handle gracefully
  if (conversionService == null) {
    return null;
  }

  return BatchCurrencyConverter(conversionService);
}

/// Stats for one active investment, in the user's base currency.
///
/// Read from the same converted snapshot as the list cards, the sort and the
/// Overview ([convertedCashFlowsSnapshotProvider]), so the detail screen
/// always shows the same net and XIRR as the card.
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency
/// - InvestmentStats.empty() when the investment has no active cash flows
///   and no dated valuation (an opening baseline needs no cash flows)
@riverpod
Future<InvestmentStats> multiCurrencyInvestmentStats(
  Ref ref,
  String investmentId,
) async {
  final converted = await ref.watch(convertedTerminalValuesProvider.future);
  final cashFlows = [
    for (final cf in converted.snapshot.cashFlows)
      if (cf.investmentId == investmentId) cf,
  ];
  final terminalValues =
      converted.byInvestment[investmentId] ?? TerminalValues.none;
  if (cashFlows.isEmpty && terminalValues.flows.isEmpty) {
    return InvestmentStats.empty();
  }
  return calculateStats(cashFlows, terminalValues: terminalValues);
}

/// The investment with [id] in [investments], or null.
InvestmentEntity? _byId(List<InvestmentEntity> investments, String id) {
  for (final investment in investments) {
    if (investment.id == id) return investment;
  }
  return null;
}

/// The investment [investment] resolves to, or null if it failed to load.
/// Without it no current value is added, and an open investment shows "—"
/// instead of a return.
Future<InvestmentEntity?> _investmentOrNull(
  Future<InvestmentEntity?> investment,
) async {
  try {
    return await investment;
  } catch (_) {
    return null;
  }
}

/// Converts [cashFlows] and the current values of the open [investments]
/// among them to the user's base currency and calculates their stats, or
/// returns empty stats when there is nothing to convert or no converter.
Future<InvestmentStats> _convertedStats(
  Ref ref,
  List<CashFlowEntity> cashFlows, {
  required List<InvestmentEntity> investments,
}) async {
  // Dated valuations of the active investments: empty while the feature is
  // off, and always for archived ones (money rule 9).
  final snapshots = await dataOf(
    ref.watch(valuationSnapshotsByInvestmentProvider),
  );
  final hasValuations = investments.any(
    (i) => i.isOpen && (snapshots[i.id]?.isNotEmpty ?? false),
  );
  if (cashFlows.isEmpty && !hasValuations) {
    return InvestmentStats.empty();
  }

  final engine = ref.watch(calculationEngineProvider);
  if (!engine.currency.isAvailable) return InvestmentStats.empty();

  final userBaseCurrency = ref.watch(currencyCodeProvider);

  // Batch convert with deduplication (OPTIMIZED)
  final convertedCashFlows = cashFlows.isEmpty
      ? const <CashFlowEntity>[]
      : await engine.currency.batchConvert(
          cashFlows: cashFlows,
          baseCurrency: userBaseCurrency,
          fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
        );
  requireBaseCurrency(convertedCashFlows, userBaseCurrency);

  // Current values are converted like cash flows before anything is summed
  // (money rule 2).
  final terminalValues = CurrentValueCalculator.terminalValues(
    investments: investments,
    cashFlows: cashFlows,
    asOf: ref.watch(valuationDateProvider),
    snapshots: snapshots,
  );
  // A value with no rate at all counts as missing rather than show a
  // native amount under the base symbol.
  final convertedTerminalValues = terminalValues.flows.isEmpty
      ? terminalValues
      : terminalValues.withConvertedFlows(
          await convertTerminalFlows(
            engine,
            terminalValues.flows,
            userBaseCurrency,
          ),
        );

  // Use engine's financial module to calculate stats
  return calculateStatsOffUiThread(
    convertedCashFlows,
    terminalValues: convertedTerminalValues,
  );
}

/// Stats for one archived investment, in the user's base currency.
///
/// Archived investments are left out of totals, but their detail screen still
/// shows amounts under the base-currency symbol, so their cash flows must be
/// converted like those of active investments.
@riverpod
Future<InvestmentStats> multiCurrencyArchivedInvestmentStats(
  Ref ref,
  String investmentId,
) async {
  final cashFlows = await ref.watch(
    archivedCashFlowsByInvestmentProvider(investmentId).future,
  );
  final investment = await _investmentOrNull(
    ref.watch(
      archivedInvestmentsProvider.selectAsync(
        (all) => _byId(all, investmentId),
      ),
    ),
  );
  return _convertedStats(ref, cashFlows, investments: [?investment]);
}

/// Provider for multi-currency global stats
///
/// Calculates global statistics across all investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// Uses optimized batch conversion with deduplication for performance.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency
/// - InvestmentStats.empty() if user is not authenticated (converter is null)
@riverpod
Future<InvestmentStats> multiCurrencyGlobalStats(Ref ref) async {
  // Stay loading, or fail, with the cash flows: an empty result here would
  // show the new-user empty state to users who have data.
  final cashFlows = await dataOf(ref.watch(validCashFlowsProvider));

  // Valid cash flows exist only once the active investments have loaded.
  // With none, only dated valuations can give stats (_convertedStats).
  return _convertedStats(
    ref,
    cashFlows,
    investments: ref.watch(activeInvestmentsProvider).value ?? const [],
  );
}

/// Provider for multi-currency open investments stats
///
/// Calculates statistics for open investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency
@riverpod
Future<InvestmentStats> multiCurrencyOpenStats(Ref ref) async {
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  // Stay loading, or fail, with the sources instead of reporting no data.
  final investments = await dataOf(investmentsAsync);

  // Optimization: Single pass loop replacing .where, .map, and .toSet
  final openIds = <String>{};
  for (final i in investments) {
    if (i.status == InvestmentStatus.open) {
      openIds.add(i.id);
    }
  }

  if (openIds.isEmpty) {
    return InvestmentStats.empty();
  }

  final cashFlows = await dataOf(cashFlowsAsync);

  // Optimization: Replace .where().toList() with standard loop
  final openCashFlows = <CashFlowEntity>[];
  for (final cf in cashFlows) {
    if (openIds.contains(cf.investmentId)) {
      openCashFlows.add(cf);
    }
  }

  // With no cash flows, only dated valuations can give stats.
  return _convertedStats(ref, openCashFlows, investments: investments);
}

/// Provider for multi-currency closed investments stats
///
/// Calculates statistics for closed investments with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency
@riverpod
Future<InvestmentStats> multiCurrencyClosedStats(Ref ref) async {
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  // Stay loading, or fail, with the sources instead of reporting no data.
  final investments = await dataOf(investmentsAsync);

  // Optimization: Single pass loop replacing .where, .map, and .toSet
  final closedIds = <String>{};
  for (final i in investments) {
    if (i.status == InvestmentStatus.closed) {
      closedIds.add(i.id);
    }
  }

  if (closedIds.isEmpty) {
    return InvestmentStats.empty();
  }

  final cashFlows = await dataOf(cashFlowsAsync);

  // Optimization: Replace .where().toList() with standard loop
  final closedCashFlows = <CashFlowEntity>[];
  for (final cf in cashFlows) {
    if (closedIds.contains(cf.investmentId)) {
      closedCashFlows.add(cf);
    }
  }

  if (closedCashFlows.isEmpty) {
    return InvestmentStats.empty();
  }

  return _convertedStats(ref, closedCashFlows, investments: investments);
}
