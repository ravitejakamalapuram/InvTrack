import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
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

  // Use engine's financial module to calculate stats
  return engine.financial.calculateStats(convertedCashFlows);
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
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  // Wait for cash flows to load
  final cashFlows = await cashFlowsAsync.when(
    data: (data) async => data,
    loading: () async => <CashFlowEntity>[],
    error: (e, st) async => <CashFlowEntity>[],
  );

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

  // Use engine's financial module to calculate stats
  return engine.financial.calculateStats(convertedCashFlows);
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

  // Wait for investments to load
  final investments = await investmentsAsync.when(
    data: (data) async => data,
    loading: () async => <InvestmentEntity>[],
    error: (e, st) async => <InvestmentEntity>[],
  );

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

  // Wait for cash flows to load
  final cashFlows = await cashFlowsAsync.when(
    data: (data) async => data,
    loading: () async => <CashFlowEntity>[],
    error: (e, st) async => <CashFlowEntity>[],
  );

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

  final engine = ref.watch(calculationEngineProvider);
  if (!engine.currency.isAvailable) return InvestmentStats.empty();

  final userBaseCurrency = ref.watch(currencyCodeProvider);

  // Batch convert with deduplication (OPTIMIZED)
  final convertedCashFlows = await engine.currency.batchConvert(
    cashFlows: openCashFlows,
    baseCurrency: userBaseCurrency,
    fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
  );

  return engine.financial.calculateStats(convertedCashFlows);
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

  // Wait for investments to load
  final investments = await investmentsAsync.when(
    data: (data) async => data,
    loading: () async => <InvestmentEntity>[],
    error: (e, st) async => <InvestmentEntity>[],
  );

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

  // Wait for cash flows to load
  final cashFlows = await cashFlowsAsync.when(
    data: (data) async => data,
    loading: () async => <CashFlowEntity>[],
    error: (e, st) async => <CashFlowEntity>[],
  );

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

  final engine = ref.watch(calculationEngineProvider);
  if (!engine.currency.isAvailable) return InvestmentStats.empty();

  final userBaseCurrency = ref.watch(currencyCodeProvider);

  // Batch convert with deduplication (OPTIMIZED)
  final convertedCashFlows = await engine.currency.batchConvert(
    cashFlows: closedCashFlows,
    baseCurrency: userBaseCurrency,
    fallbackStrategy: ConversionFallbackStrategy.useLastKnown,
  );

  return engine.financial.calculateStats(convertedCashFlows);
}
