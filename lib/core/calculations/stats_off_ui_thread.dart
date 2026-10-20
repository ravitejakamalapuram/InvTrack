import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/modules/financial_module.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Input of one stats calculation, small enough to copy into an isolate.
class StatsArgs {
  const StatsArgs(this.cashFlows, this.terminalValues);

  final List<CashFlowEntity> cashFlows;
  final TerminalValues terminalValues;
}

InvestmentStats _calculate(StatsArgs args) => FinancialCalculatorModule()
    .calculateStats(args.cashFlows, terminalValues: args.terminalValues);

Future<InvestmentStats> _runInIsolate(
  InvestmentStats Function(StatsArgs) task,
  StatsArgs args,
) => compute(task, args);

/// Below this many flows a solve takes a few milliseconds even on a slow
/// phone, which is less than starting an isolate costs.
const int kStatsIsolateMinFlows = 200;

/// Same result as `FinancialCalculatorModule.calculateStats`, but a large
/// portfolio is solved in a background isolate so the Overview does not
/// drop frames while XIRR runs.
///
/// [runner] is only replaced in tests.
Future<InvestmentStats> calculateStatsOffUiThread(
  List<CashFlowEntity> cashFlows, {
  TerminalValues terminalValues = TerminalValues.none,
  int minFlowsForIsolate = kStatsIsolateMinFlows,
  Future<InvestmentStats> Function(
        InvestmentStats Function(StatsArgs) task,
        StatsArgs args,
      )
      runner =
      _runInIsolate,
}) async {
  final args = StatsArgs(cashFlows, terminalValues);
  if (cashFlows.length + terminalValues.flows.length < minFlowsForIsolate) {
    return _calculate(args);
  }
  return runner(_calculate, args);
}
