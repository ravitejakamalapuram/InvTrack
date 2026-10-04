import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/async_value_utils.dart';
import 'package:inv_tracker/core/utils/batch_currency_converter.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_stats_provider.dart';
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

/// Provider for multi-currency invested amount calculation
///
/// Converts all outflow cash flows to user's base currency before summing
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - Total invested amount in user's base currency
/// - 0.0 if user is not authenticated (converter is null)
@riverpod
Future<double> multiCurrencyInvestedAmount(Ref ref, String investmentId) async {
  final cashFlows = await ref.watch(
    cashFlowsByInvestmentProvider(investmentId).selectAsync((data) => data),
  );

  if (cashFlows.isEmpty) return 0.0;

  final engine = ref.watch(calculationEngineProvider);
  if (!engine.currency.isAvailable) return 0.0;

  final userBaseCurrency = ref.watch(currencyCodeProvider);

  // Filter outflows only
  final outflows = <CashFlowEntity>[];
  for (final cf in cashFlows) {
    if (cf.type.isOutflow) {
      outflows.add(cf);
    }
  }
  if (outflows.isEmpty) return 0.0;

  // Batch convert all outflows to base currency (OPTIMIZED)
  final convertedCashFlows = await engine.currency.batchConvert(
    cashFlows: outflows,
    baseCurrency: userBaseCurrency,
    fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
  );

  double total = 0.0;
  for (final cf in convertedCashFlows) {
    total += cf.amount;
  }
  return total;
}

/// Provider for multi-currency returned amount calculation
///
/// Converts all inflow cash flows to user's base currency before summing
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - Total returned amount in user's base currency
/// - 0.0 if user is not authenticated (converter is null)
@riverpod
Future<double> multiCurrencyReturnedAmount(Ref ref, String investmentId) async {
  final cashFlows = await ref.watch(
    cashFlowsByInvestmentProvider(investmentId).selectAsync((data) => data),
  );

  if (cashFlows.isEmpty) return 0.0;

  final engine = ref.watch(calculationEngineProvider);
  if (!engine.currency.isAvailable) return 0.0;

  final userBaseCurrency = ref.watch(currencyCodeProvider);

  // Filter inflows only
  final inflows = <CashFlowEntity>[];
  for (final cf in cashFlows) {
    if (cf.type.isInflow) {
      inflows.add(cf);
    }
  }
  if (inflows.isEmpty) return 0.0;

  // Batch convert all inflows to base currency (OPTIMIZED)
  final convertedCashFlows = await engine.currency.batchConvert(
    cashFlows: inflows,
    baseCurrency: userBaseCurrency,
    fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
  );

  double total = 0.0;
  for (final cf in convertedCashFlows) {
    total += cf.amount;
  }
  return total;
}

/// Provider for multi-currency XIRR calculation
///
/// Converts all cash flows to user's base currency using historical rates
/// before calculating XIRR
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - XIRR as decimal (e.g., 0.15 = 15% annual return)
/// - 0.0 if user is not authenticated (converter is null)
@riverpod
Future<double> multiCurrencyXirr(Ref ref, String investmentId) async {
  final cashFlows = await ref.watch(
    cashFlowsByInvestmentProvider(investmentId).selectAsync((data) => data),
  );

  if (cashFlows.isEmpty) return 0.0;

  final engine = ref.watch(calculationEngineProvider);
  if (!engine.currency.isAvailable) return 0.0;

  final userBaseCurrency = ref.watch(currencyCodeProvider);

  // Batch convert all cash flows to base currency (OPTIMIZED)
  final convertedCashFlows = await engine.currency.batchConvert(
    cashFlows: cashFlows,
    baseCurrency: userBaseCurrency,
    fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
  );

  // Calculate XIRR using converted cash flows
  return engine.financial.calculateXirrFromCashFlows(convertedCashFlows);
}

/// Provider for multi-currency portfolio value
///
/// Calculates total portfolio value by summing net cash flow
/// (total returned - total invested) for all investments,
/// converted to user's base currency
///
/// Uses optimized batch conversion with deduplication for performance.
///
/// **Returns:**
/// - Total portfolio value in user's base currency
/// - 0.0 if user is not authenticated (converter is null)
@riverpod
Future<double> multiCurrencyPortfolioValue(Ref ref) async {
  final investments = await ref.watch(
    allInvestmentsProvider.selectAsync((data) => data),
  );

  if (investments.isEmpty) return 0.0;

  final engine = ref.watch(calculationEngineProvider);
  if (!engine.currency.isAvailable) return 0.0;

  final userBaseCurrency = ref.watch(currencyCodeProvider);

  // Collect all cash flows from all investments
  final allCashFlows = <CashFlowEntity>[];
  for (final investment in investments) {
    final cashFlows = await ref.watch(
      cashFlowsByInvestmentProvider(investment.id).selectAsync((data) => data),
    );
    allCashFlows.addAll(cashFlows);
  }

  if (allCashFlows.isEmpty) return 0.0;

  // Batch convert with deduplication (OPTIMIZED)
  final convertedCashFlows = await engine.currency.batchConvert(
    cashFlows: allCashFlows,
    baseCurrency: userBaseCurrency,
    fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
  );

  // Sum net cash flow (inflows - outflows)
  double total = 0.0;
  for (final cf in convertedCashFlows) {
    total += cf.type.isInflow ? cf.amount : -cf.amount;
  }
  return total;
}

/// Provider for multi-currency investment stats
///
/// Calculates investment statistics with proper currency conversion.
/// All cash flows are converted to user's base currency before aggregation.
///
/// Uses optimized batch conversion with deduplication for performance.
///
/// **Parameters:**
/// - [investmentId]: Investment ID
///
/// **Returns:**
/// - InvestmentStats with amounts in user's base currency
/// - InvestmentStats.empty() if user is not authenticated (converter is null)
@riverpod
Future<InvestmentStats> multiCurrencyInvestmentStats(
  Ref ref,
  String investmentId,
) async {
  final cashFlows = await ref.watch(
    cashFlowsByInvestmentProvider(investmentId).future,
  );
  final investment = await _investmentOrNull(
    ref.watch(
      allInvestmentsProvider.selectAsync((all) => _byId(all, investmentId)),
    ),
  );
  return _convertedStats(ref, cashFlows, investments: [?investment]);
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
  if (cashFlows.isEmpty) {
    return InvestmentStats.empty();
  }

  final engine = ref.watch(calculationEngineProvider);
  if (!engine.currency.isAvailable) return InvestmentStats.empty();

  final userBaseCurrency = ref.watch(currencyCodeProvider);

  // Batch convert with deduplication (OPTIMIZED)
  final convertedCashFlows = await engine.currency.batchConvert(
    cashFlows: cashFlows,
    baseCurrency: userBaseCurrency,
    fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
  );

  // Current values are converted like cash flows before anything is summed
  // (money rule 2).
  final terminalValues = CurrentValueCalculator.terminalValues(
    investments: investments,
    cashFlows: cashFlows,
    asOf: ref.watch(valuationDateProvider),
  );
  // A value with no rate at all stays unconverted; it then counts as
  // missing rather than show a native amount under the base symbol.
  final convertedTerminalValues = terminalValues.flows.isEmpty
      ? terminalValues
      : terminalValues.withConvertedFlows([
          for (final cf in await engine.currency.batchConvert(
            cashFlows: terminalValues.flows,
            baseCurrency: userBaseCurrency,
            fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
          ))
            if (cf.currency == userBaseCurrency) cf,
        ]);

  // Use engine's financial module to calculate stats
  return engine.financial.calculateStats(
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

  if (cashFlows.isEmpty) {
    return InvestmentStats.empty();
  }

  // Valid cash flows exist only once the active investments have loaded.
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

  if (openCashFlows.isEmpty) {
    return InvestmentStats.empty();
  }

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
