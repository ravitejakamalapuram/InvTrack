/// Income Trend Report Provider
///
/// Provides income trend analysis report by aggregating data from investments,
/// cash flows, and expected cash flows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';
import 'package:inv_tracker/features/income_projection/domain/entities/income_trend_report.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/expected_cash_flow_providers.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_analysis_providers.dart';

/// Provider for income trend report
///
/// **Multi-Currency Compliance (Rule 21):**
/// Uses CalculationEngine to convert all cash flows to base currency before aggregation.
final incomeTrendReportProvider = FutureProvider.autoDispose<IncomeTrendReport>((ref) async {
  // Watch required data
  final investments = await ref.watch(allInvestmentsProvider.future);
  final cashFlows = await ref.watch(allCashFlowsStreamProvider.future);
  final expectedCashFlows = await ref.watch(allExpectedCashFlowsProvider.future);
  final baseCurrency = ref.watch(currencyCodeProvider);

  // Get calculation engine and analyzer service
  final engine = ref.watch(calculationEngineProvider);
  final analyzer = ref.watch(incomeTrendAnalyzerProvider);

  // Generate report with currency conversion
  return analyzer.generateReport(
    investments: investments,
    cashFlows: cashFlows,
    expectedCashFlows: expectedCashFlows,
    baseCurrency: baseCurrency,
    engine: engine,
  );
});
