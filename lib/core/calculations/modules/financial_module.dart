import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/core/calculations/financial_calculator.dart';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_stats.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

/// Module for handling basic and advanced financial calculations.
class FinancialCalculatorModule implements CalculationModule {
  @override
  String get name => 'Financial';

  /// Calculates XIRR (Extended Internal Rate of Return) from dates and amounts.
  double calculateXirr(List<DateTime> dates, List<double> amounts) {
    return XirrSolver.calculateXirr(dates, amounts) ?? 0.0;
  }

  /// Calculates XIRR (Extended Internal Rate of Return) from a list of cash flows.
  double calculateXirrFromCashFlows(List<CashFlowEntity> cashFlows) {
    return FinancialCalculator.calculateXirrFromCashFlows(cashFlows);
  }

  /// Calculates CAGR (Compound Annual Growth Rate).
  double calculateCAGR(double startValue, double endValue, double years) {
    return FinancialCalculator.calculateCAGR(startValue, endValue, years);
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
  double calculateTotalInvested(List<CashFlowEntity> cashFlows) {
    return FinancialCalculator.calculateTotalInvested(cashFlows);
  }

  /// Calculates Total Returned (inflows) from cash flows.
  double calculateTotalReturned(List<CashFlowEntity> cashFlows) {
    return FinancialCalculator.calculateTotalReturned(cashFlows);
  }

  /// Calculates stats from a list of cash flows.
  ///
  /// [includeXirr] - Set to false to skip expensive XIRR calculation if not needed.
  InvestmentStats calculateStats(
    List<CashFlowEntity> cashFlows, {
    bool includeXirr = true,
  }) {
    if (cashFlows.isEmpty) {
      return InvestmentStats.empty();
    }

    // Single pass calculation for O(N) complexity
    double totalInvested = 0.0;
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

      if (cf.type.isOutflow) {
        totalInvested += cf.amount;
      } else if (cf.type.isInflow) {
        totalReturned += cf.amount;
      }

      if (includeXirr) {
        xirrDates!.add(cf.date);
        xirrAmounts!.add(cf.signedAmount);
      }
    }

    final firstDate = firstDateMs != null
        ? DateTime.fromMillisecondsSinceEpoch(firstDateMs)
        : null;
    final lastDate = lastDateMs != null
        ? DateTime.fromMillisecondsSinceEpoch(lastDateMs)
        : null;

    final netCashFlow = calculateNetCashFlow(totalInvested, totalReturned);
    final absoluteReturn = calculateAbsoluteReturn(totalInvested, totalReturned);
    final moic = calculateMOIC(totalInvested, totalReturned);

    final xirr = includeXirr
        ? (XirrSolver.calculateXirr(xirrDates!, xirrAmounts!) ?? 0.0)
        : 0.0;

    return InvestmentStats(
      totalInvested: totalInvested,
      totalReturned: totalReturned,
      netCashFlow: netCashFlow,
      absoluteReturn: absoluteReturn,
      moic: moic,
      xirr: xirr,
      cashFlowCount: cashFlows.length,
      firstCashFlowDate: firstDate,
      lastCashFlowDate: lastDate,
    );
  }
}
