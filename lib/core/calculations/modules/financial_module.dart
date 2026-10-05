import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/current_value_calculator.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/models/cash_flow_interface.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';

/// Module for handling basic and advanced financial calculations.
class FinancialCalculatorModule implements CalculationModule {
  @override
  String get name => 'Financial';

  /// Calculates XIRR (Extended Internal Rate of Return) from dates and
  /// amounts, or null when it is undefined.
  double? calculateXirr(List<DateTime> dates, List<double> amounts) {
    return XirrSolver.calculateXirr(dates, amounts);
  }

  /// Calculates XIRR (Extended Internal Rate of Return) from a list of cash
  /// flows, or null when it is undefined.
  double? calculateXirrFromCashFlows(List<ICashFlow> cashFlows) {
    return FinancialCalculator.calculateXirrFromCashFlows(cashFlows);
  }

  /// Calculates MOIC (Multiple on Invested Capital).
  double calculateMOIC(double invested, double returned) {
    return FinancialCalculator.calculateMOIC(invested, returned);
  }

  /// Calculates Net Cash Flow (Total Returned - Total Invested).
  double calculateNetCashFlow(double invested, double returned) {
    return FinancialCalculator.calculateNetCashFlow(invested, returned);
  }

  /// Calculates Absolute Return percentage.
  double calculateAbsoluteReturn(double invested, double returned) {
    return FinancialCalculator.calculateAbsoluteReturn(invested, returned);
  }

  /// Calculates Total Invested (outflows) from cash flows.
  double calculateTotalInvested(List<ICashFlow> cashFlows) {
    return FinancialCalculator.calculateTotalInvested(cashFlows);
  }

  /// Calculates Total Returned (inflows) from cash flows.
  double calculateTotalReturned(List<ICashFlow> cashFlows) {
    return FinancialCalculator.calculateTotalReturned(cashFlows);
  }

  /// Calculates stats from a list of cash flows.
  ///
  /// [includeXirr] - Set to false to skip expensive XIRR calculation if not needed.
  ///
  /// [terminalValues] are the current values of the open investments among
  /// [cashFlows], already in the same currency. They are the terminal inflow
  /// of XIRR, MOIC and absolute return; invested, returned and net cash flow
  /// stay cash-only.
  InvestmentStats calculateStats(
    List<ICashFlow> cashFlows, {
    bool includeXirr = true,
    TerminalValues terminalValues = TerminalValues.none,
  }) {
    if (cashFlows.isEmpty) {
      return InvestmentStats.empty();
    }

    // Single pass calculation for O(N) complexity
    double totalInvested = 0.0;
    double principal = 0.0;
    double totalReturned = 0.0;

    int? firstDateMs;
    int? lastDateMs;

    final xirrDates = includeXirr ? <DateTime>[] : null;
    final xirrAmounts = includeXirr ? <double>[] : null;

    for (final cf in cashFlows) {
      final ms = cf.date.millisecondsSinceEpoch;
      if (firstDateMs == null || ms < firstDateMs) {
        firstDateMs = ms;
      }
      if (lastDateMs == null || ms > lastDateMs) {
        lastDateMs = ms;
      }

      if (cf.signedAmount < 0) {
        totalInvested += cf.amount;
        if (cf.calculationType == CalculationCashFlowType.invest) {
          principal += cf.amount;
        }
      } else if (cf.signedAmount > 0) {
        totalReturned += cf.amount;
      }

      if (includeXirr) {
        xirrDates!.add(cf.date);
        xirrAmounts!.add(cf.signedAmount);
      }
    }

    // Current values: the terminal inflow (money rule 4).
    double? currentValue;
    DateTime? currentValueDate;
    for (final terminal in terminalValues.flows) {
      currentValue = (currentValue ?? 0) + terminal.amount;
      if (currentValueDate == null || terminal.date.isAfter(currentValueDate)) {
        currentValueDate = terminal.date;
      }
      if (includeXirr && terminal.amount > 0) {
        xirrDates!.add(terminal.date);
        xirrAmounts!.add(terminal.amount);
      }
    }
    final returnedWithValue = totalReturned + (currentValue ?? 0);

    final firstDate = firstDateMs != null
        ? DateTime.fromMillisecondsSinceEpoch(firstDateMs)
        : null;
    final lastDate = lastDateMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastDateMs)
        : null;

    final netCashFlow = calculateNetCashFlow(totalInvested, totalReturned);
    final absoluteReturn = calculateAbsoluteReturn(
      totalInvested,
      returnedWithValue,
    );
    final moic = calculateMOIC(totalInvested, returnedWithValue);

    final xirrResult = includeXirr
        ? XirrSolver.solve(xirrDates!, xirrAmounts!)
        : const XirrResult.undefined(XirrUndefinedReason.noSolution);

    return InvestmentStats(
      totalInvested: totalInvested,
      principal: principal,
      totalReturned: totalReturned,
      netCashFlow: netCashFlow,
      absoluteReturn: absoluteReturn,
      moic: moic,
      // Null when undefined: callers must not count it as 0%.
      xirr: xirrResult.value,
      xirrMethod: xirrResult.method,
      cashFlowCount: cashFlows.length,
      firstCashFlowDate: firstDate,
      lastCashFlowDate: lastDate,
      currentValue: currentValue,
      currentValueDate: currentValueDate,
      currentValueIsEstimate: currentValue != null && terminalValues.isEstimate,
      currentValueRate: currentValue != null ? terminalValues.rate : null,
      missingValueCount: terminalValues.missingValueCount,
    );
  }

  /// Stats for each investment in [cashFlows], keyed by investment id.
  ///
  /// [cashFlows] and the flows of [terminalValues] (keyed by investment id)
  /// must already be in one currency (the user's base currency); this is the
  /// one place that groups a converted snapshot into per-investment stats,
  /// so every screen shows the same numbers.
  Map<String, InvestmentStats> calculateStatsByInvestment(
    List<ICashFlow> cashFlows, {
    bool includeXirr = true,
    Map<String, TerminalValues> terminalValues = const {},
  }) {
    final grouped = <String, List<ICashFlow>>{};
    for (final cf in cashFlows) {
      (grouped[cf.investmentId] ??= []).add(cf);
    }
    return {
      for (final entry in grouped.entries)
        entry.key: calculateStats(
          entry.value,
          includeXirr: includeXirr,
          terminalValues: terminalValues[entry.key] ?? TerminalValues.none,
        ),
    };
  }
}
