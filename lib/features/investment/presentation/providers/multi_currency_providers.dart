import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/services/currency_conversion_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'multi_currency_providers.g.dart';

/// Provider for multi-currency invested amount calculation
/// 
/// Converts all outflow cash flows to user's base currency before summing
/// 
/// **Parameters:**
/// - [investmentId]: Investment ID
/// 
/// **Returns:**
/// - Total invested amount in user's base currency
@riverpod
Future<double> multiCurrencyInvestedAmount(
  MultiCurrencyInvestedAmountRef ref,
  String investmentId,
) async {
  final cashFlows = await ref.watch(
    cashFlowsByInvestmentProvider(investmentId).selectAsync((data) => data),
  );

  if (cashFlows.isEmpty) return 0.0;

  final conversionService = ref.watch(currencyConversionServiceProvider);
  final userBaseCurrency = ref.watch(currencyCodeProvider);

  double total = 0.0;

  // Convert each outflow to base currency
  for (final cf in cashFlows) {
    if (cf.type.isOutflow) {
      final convertedAmount = await conversionService.convert(
        amount: cf.amount,
        from: cf.currency,
        to: userBaseCurrency,
        date: cf.date,
      );
      total += convertedAmount;
    }
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
@riverpod
Future<double> multiCurrencyReturnedAmount(
  MultiCurrencyReturnedAmountRef ref,
  String investmentId,
) async {
  final cashFlows = await ref.watch(
    cashFlowsByInvestmentProvider(investmentId).selectAsync((data) => data),
  );

  if (cashFlows.isEmpty) return 0.0;

  final conversionService = ref.watch(currencyConversionServiceProvider);
  final userBaseCurrency = ref.watch(currencyCodeProvider);

  double total = 0.0;

  // Convert each inflow to base currency
  for (final cf in cashFlows) {
    if (cf.type.isInflow) {
      final convertedAmount = await conversionService.convert(
        amount: cf.amount,
        from: cf.currency,
        to: userBaseCurrency,
        date: cf.date,
      );
      total += convertedAmount;
    }
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
@riverpod
Future<double> multiCurrencyXirr(
  MultiCurrencyXirrRef ref,
  String investmentId,
) async {
  final cashFlows = await ref.watch(
    cashFlowsByInvestmentProvider(investmentId).selectAsync((data) => data),
  );

  if (cashFlows.isEmpty) return 0.0;

  final conversionService = ref.watch(currencyConversionServiceProvider);
  final userBaseCurrency = ref.watch(currencyCodeProvider);

  // Convert all cash flows to base currency
  final convertedCashFlows = <CashFlowEntity>[];

  for (final cf in cashFlows) {
    final convertedAmount = await conversionService.convert(
      amount: cf.amount,
      from: cf.currency,
      to: userBaseCurrency,
      date: cf.date,
    );

    // Create new cash flow with converted amount
    convertedCashFlows.add(
      cf.copyWith(
        amount: convertedAmount,
        currency: userBaseCurrency,
      ),
    );
  }

  // Calculate XIRR using converted cash flows
  return FinancialCalculator.calculateXirrFromCashFlows(convertedCashFlows);
}

/// Provider for multi-currency portfolio value
///
/// Calculates total portfolio value by summing net cash flow
/// (total returned - total invested) for all investments,
/// converted to user's base currency
///
/// **Returns:**
/// - Total portfolio value in user's base currency
@riverpod
Future<double> multiCurrencyPortfolioValue(
  MultiCurrencyPortfolioValueRef ref,
) async {
  final investments = await ref.watch(
    investmentsStreamProvider.selectAsync((data) => data),
  );

  if (investments.isEmpty) return 0.0;

  final conversionService = ref.watch(currencyConversionServiceProvider);
  final userBaseCurrency = ref.watch(currencyCodeProvider);

  double totalValue = 0.0;

  // Calculate net cash flow for each investment and convert to base currency
  for (final investment in investments) {
    final cashFlows = await ref.watch(
      cashFlowsByInvestmentProvider(investment.id).selectAsync((data) => data),
    );

    if (cashFlows.isEmpty) continue;

    // Calculate net cash flow (returned - invested) in base currency
    double netInBaseCurrency = 0.0;

    for (final cf in cashFlows) {
      final convertedAmount = await conversionService.convert(
        amount: cf.amount,
        from: cf.currency,
        to: userBaseCurrency,
        date: cf.date,
      );

      // Add to net (inflows positive, outflows negative)
      netInBaseCurrency += cf.type.isInflow ? convertedAmount : -convertedAmount;
    }

    totalValue += netInBaseCurrency;
  }

  return totalValue;
}

