/// Portfolio Health Provider
///
/// Provides portfolio health report data
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/investment/presentation/providers/providers.dart';
import 'package:inv_tracker/features/reports/data/services/portfolio_health_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/portfolio_health_report.dart';

/// Provider for portfolio health report
final portfolioHealthReportProvider =
    FutureProvider.autoDispose<PortfolioHealthReport>((ref) async {
  // Get investments, stats, and cash flows
  final investmentsAsync = ref.watch(activeInvestmentsProvider);
  final statsMapAsync = ref.watch(activeInvestmentBasicStatsMapProvider);
  final cashFlowsAsync = ref.watch(validCashFlowsProvider);

  // Wait for all data
  final investments = await investmentsAsync.when(
    data: (data) async => data,
    loading: () async => <InvestmentEntity>[],
    error: (e, st) async => <InvestmentEntity>[],
  );

  final statsMap = await statsMapAsync.when(
    data: (data) async => data,
    loading: () async => <String, InvestmentStats>{},
    error: (e, st) async => <String, InvestmentStats>{},
  );

  final cashFlows = await cashFlowsAsync.when(
    data: (data) async => data,
    loading: () async => <CashFlowEntity>[],
    error: (e, st) async => <CashFlowEntity>[],
  );

  // Generate report
  final service = ref.read(portfolioHealthServiceProvider);
  return service.generateReport(
    investments: investments,
    statsMap: statsMap,
    cashFlows: cashFlows,
  );
});
