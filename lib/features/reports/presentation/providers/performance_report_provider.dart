/// Provider for Performance Report
///
/// Generates performance analysis by aggregating all investments with their XIRR
/// and identifying top/bottom performers
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/reports/data/services/performance_report_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/performance_report.dart';

/// Provider for performance report (current snapshot)
final performanceReportProvider =
    FutureProvider.autoDispose<PerformanceReport>((ref) async {
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
  final service = ref.read(performanceReportServiceProvider);
  return service.generateReport(
    allInvestments: investments,
    allCashFlows: cashFlows,
  );
});
