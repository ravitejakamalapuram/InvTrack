/// Runs the reporting engine for a period kind and anchor day.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/calculations/calculation_engine_provider.dart';
import 'package:inv_tracker/core/reporting/report_definitions.dart';
import 'package:inv_tracker/core/reporting/report_engine.dart';
import 'package:inv_tracker/core/reporting/report_period.dart';
import 'package:inv_tracker/core/reporting/report_result.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/investment/presentation/providers/investment_providers.dart';

typedef PeriodReportKey = ({ReportPeriodKind kind, DateTime anchor});

final periodReportProvider = FutureProvider.autoDispose
    .family<ReportResult, PeriodReportKey>((ref, key) async {
      final investments = await ref.watch(allInvestmentsProvider.future);
      final archived = await ref.watch(archivedInvestmentsProvider.future);
      final flows = await ref.watch(allCashFlowsStreamProvider.future);
      final baseCurrency = ref.watch(currencyCodeProvider);
      final currency = ref.watch(calculationEngineProvider).currency;

      final engine = ReportEngine(
        toBase: (f, base) =>
            currency.batchConvertToBase(cashFlows: f, baseCurrency: base),
      );
      return engine.run(
        definitionFor(key.kind),
        ReportPeriod.containing(key.kind, key.anchor),
        ReportInputs(
          investments: [...investments, ...archived],
          cashFlows: flows,
          baseCurrency: baseCurrency,
        ),
      );
    });
