/// Provider for Financial Year report
///
/// Generates FY reports (Apr 1 - Mar 31) by aggregating cashflows and investments
/// for the current or specified financial year.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
final fyReportProvider =
    FutureProvider.autoDispose.family<FYReport, int>(
  (ref, fyYear) async {
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
    final service = ref.read(fyReportServiceProvider);
    return service.generateReport(
      fyYear: fyYear,
      allCashFlows: cashFlows,
      allInvestments: investments,
    );
  },
);
