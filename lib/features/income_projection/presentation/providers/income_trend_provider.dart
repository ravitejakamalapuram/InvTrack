/// Income Trend Report Provider
///
/// Provides income trend analysis report by aggregating data from investments,
/// cash flows, and expected cash flows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/income_trend_report.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_provider.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_analysis_providers.dart';

/// Provider for income trend report
final incomeTrendReportProvider = FutureProvider.autoDispose<IncomeTrendReport>((ref) async {
  // Watch required data
  final investments = await ref.watch(allInvestmentsProvider.future);
  final cashFlows = await ref.watch(allCashFlowsStreamProvider.future);
  final expectedCashFlows = await ref.watch(expectedCashFlowsProvider.future);
  final currency = ref.watch(currencyCodeProvider);

  // Get analyzer service
  final analyzer = ref.watch(incomeTrendAnalyzerProvider);

  // Generate report
  return analyzer.generateReport(
    investments: investments,
    cashFlows: cashFlows,
    expectedCashFlows: expectedCashFlows,
    currency: currency,
  );
});
