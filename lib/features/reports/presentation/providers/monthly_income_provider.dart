/// Provider for monthly income report
///
/// Generates monthly income reports by aggregating cashflows and investments
/// for the current or specified month.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/reports/data/services/monthly_income_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/monthly_income_report.dart';

/// Provider for current month's income report
final currentMonthlyIncomeProvider =
    FutureProvider.autoDispose<MonthlyIncomeReport>((ref) async {
  final now = DateTime.now();
  return ref.watch(
    monthlyIncomeProvider(DateTime(now.year, now.month, 1)).future,
  );
});

/// Provider for monthly income report with custom period
final monthlyIncomeProvider =
    FutureProvider.autoDispose.family<MonthlyIncomeReport, DateTime>(
  (ref, period) async {
    // Get all data
    final investmentsAsync = ref.watch(activeInvestmentsProvider);
    final cashFlowsAsync = ref.watch(validCashFlowsProvider);

    // Wait for all data to load
    final investments = await investmentsAsync.when(
      data: (data) => Future.value(data),
      loading: () => Future.value(<InvestmentEntity>[]),
      error: (e, st) => throw e,
    );

    final cashFlows = await cashFlowsAsync.when(
      data: (data) => Future.value(data),
      loading: () => Future.value(<CashFlowEntity>[]),
      error: (e, st) => throw e,
    );

    // Generate report
    final service = ref.read(monthlyIncomeServiceProvider);
    return service.generateReport(
      period: period,
      allCashFlows: cashFlows,
      allInvestments: investments,
    );
  },
);
