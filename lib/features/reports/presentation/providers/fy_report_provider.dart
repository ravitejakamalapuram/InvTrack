/// Provider for Financial Year report
///
/// Generates FY reports (Apr 1 - Mar 31) by aggregating cashflows and investments
/// for the current or specified financial year.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';

/// Provider for current FY report
final currentFYReportProvider =
    FutureProvider.autoDispose<FYReport>((ref) async {
  final now = DateTime.now();
  final fyYear = now.month >= 4 ? now.year : now.year - 1;
  return ref.watch(fyReportProvider(fyYear).future);
});

/// Provider for FY report with custom year
/// Optimized: Uses date-range filtered cashflows (server-side) instead of fetching all
final fyReportProvider =
    FutureProvider.autoDispose.family<FYReport, int>(
  (ref, fyYear) async {
    // Get all investments (needed for capital gains, portfolio values)
    final investmentsAsync = ref.watch(activeInvestmentsProvider);

    // Get all cashflows (needed to compute historical portfolio valuation correctly)
    final cashFlowsAsync = ref.watch(validCashFlowsProvider);

    // Get base currency
    final baseCurrency = ref.watch(currencyCodeProvider);

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
    final service = ref.read(fyReportServiceProvider);
    return await service.generateReport(
      fyYear: fyYear,
      allCashFlows: cashFlows,
      allInvestments: investments,
      baseCurrency: baseCurrency,
    );
  },
);
