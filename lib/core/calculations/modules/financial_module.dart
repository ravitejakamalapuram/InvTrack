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

  /// Paid-in capital: the most of the user's own money in each investment at
  /// one time, summed. See [FinancialCalculator.calculatePaidInCapital].
  double calculatePaidInCapital(List<ICashFlow> cashFlows) {
    return FinancialCalculator.calculatePaidInCapital(cashFlows);
  }

  /// Calculates stats from a list of cash flows.
  ///
  /// [includeXirr] - Set to false to skip expensive XIRR calculation if not needed.
  ///
  /// [terminalValues] are the current values of the open investments among
  /// [cashFlows], already in the same currency. They are the terminal inflow
  /// of XIRR, MOIC and absolute return; invested, returned and net cash flow
  /// stay cash-only. An investment may have a value and no cash flows (an
  /// opening baseline): its value is then all there is to report.
  ///
  /// Investments in [TerminalValues.limitedHistoryIds] count in the cash-only
  /// totals and in the current value, but their flows and values stay out of
  /// XIRR, paid-in capital, MOIC and absolute return: their cost and dates
  /// are unknown, so those would be fabricated. When nothing else is left,
  /// [InvestmentStats.returnsKnown] is false.
  InvestmentStats calculateStats(
    List<ICashFlow> cashFlows, {
    bool includeXirr = true,
    TerminalValues terminalValues = TerminalValues.none,
  }) {
    if (cashFlows.isEmpty && terminalValues.flows.isEmpty) {
      return InvestmentStats.empty();
    }

    final limited = terminalValues.limitedHistoryIds;
    // Limited investments that have a flow or a value in these stats.
    final limitedSeen = <String>{};
    // Cash flows that count towards performance (all of them, unless some
    // investments have limited history).
    final performanceFlows = limited.isEmpty ? cashFlows : <ICashFlow>[];

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

      if (limited.isNotEmpty) {
        if (limited.contains(cf.investmentId)) {
          limitedSeen.add(cf.investmentId);
          continue;
        }
        performanceFlows.add(cf);
      }
      if (includeXirr) {
        xirrDates!.add(cf.date);
        xirrAmounts!.add(cf.signedAmount);
      }
    }

    // Current values: the terminal inflow (money rule 4).
    double? currentValue;
    DateTime? currentValueDate;
    var performanceValue = 0.0;
    for (final terminal in terminalValues.flows) {
      currentValue = (currentValue ?? 0) + terminal.amount;
      if (currentValueDate == null || terminal.date.isAfter(currentValueDate)) {
        currentValueDate = terminal.date;
      }
      if (limited.contains(terminal.investmentId)) {
        limitedSeen.add(terminal.investmentId);
        continue;
      }
      performanceValue += terminal.amount;
      if (includeXirr && terminal.amount > 0) {
        xirrDates!.add(terminal.date);
        xirrAmounts!.add(terminal.amount);
      }
    }
    // Money is compared and shown to the paisa (CALC-13).
    totalInvested = FinancialCalculator.roundMoney(totalInvested);
    totalReturned = FinancialCalculator.roundMoney(totalReturned);

    final firstDate = firstDateMs != null
        ? DateTime.fromMillisecondsSinceEpoch(firstDateMs)
        : null;
    final lastDate = lastDateMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastDateMs)
        : null;

    final netCashFlow = FinancialCalculator.roundMoney(
      calculateNetCashFlow(totalInvested, totalReturned),
    );

    // MOIC and return % are on paid-in capital, so money reinvested from
    // earlier payouts is counted once on both sides: MOIC = (distributions
    // + current value - reinvested) / paid-in (CALC-07). Only investments
    // with known history take part.
    final paidInCapital = calculatePaidInCapital(performanceFlows);
    final double performanceInvested;
    final double performanceReturned;
    final double performanceCurrent;
    if (limited.isEmpty) {
      performanceInvested = totalInvested;
      performanceReturned = totalReturned;
      performanceCurrent = currentValue ?? 0;
    } else {
      performanceInvested = FinancialCalculator.roundMoney(
        calculateTotalInvested(performanceFlows),
      );
      performanceReturned = FinancialCalculator.roundMoney(
        calculateTotalReturned(performanceFlows),
      );
      performanceCurrent = performanceValue;
    }
    final reinvested = performanceInvested - paidInCapital;
    final valueOnPaidIn = performanceReturned + performanceCurrent - reinvested;
    final absoluteReturn = calculateAbsoluteReturn(
      paidInCapital,
      valueOnPaidIn,
    );
    final moic = calculateMOIC(paidInCapital, valueOnPaidIn);

    final xirrResult = includeXirr
        ? XirrSolver.solve(xirrDates!, xirrAmounts!)
        : const XirrResult.undefined(XirrUndefinedReason.noSolution);

    return InvestmentStats(
      totalInvested: totalInvested,
      paidInCapital: paidInCapital,
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
      limitedHistoryCount: limitedSeen.length,
      returnsKnown: limitedSeen.isEmpty || paidInCapital > 0,
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
    // An investment with a value and no cash flows (an opening baseline) has
    // stats of its own.
    for (final entry in terminalValues.entries) {
      if (entry.value.flows.isNotEmpty) {
        grouped.putIfAbsent(entry.key, () => []);
      }
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
