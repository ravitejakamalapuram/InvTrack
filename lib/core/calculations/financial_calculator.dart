import 'dart:math';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

class FinancialCalculator {
  /// Calculates XIRR from a list of cash flows.
  /// Uses the signedAmount property: negative for outflows, positive for inflows.
  static double calculateXirrFromCashFlows(List<CashFlowEntity> cashFlows) {
    if (cashFlows.isEmpty) return 0.0;

    final dates = <DateTime>[];
    final amounts = <double>[];

    for (final cf in cashFlows) {
      dates.add(cf.date);
      amounts.add(cf.signedAmount);
    }

    return XirrSolver.calculateXirr(dates, amounts);
  }

  /// Calculates CAGR (Compound Annual Growth Rate).
  static double calculateCAGR(double startValue, double endValue, double years) {
    if (startValue <= 0 || years <= 0) return 0.0;
    return pow(endValue / startValue, 1 / years) - 1;
  }

  /// Calculates MOIC (Multiple on Invested Capital).
  /// MOIC = Total Value / Total Invested
  static double calculateMOIC(double invested, double returned) {
    if (invested == 0) return 0.0;
    return returned / invested;
  }

  /// Calculates Net Cash Flow (Total Returned - Total Invested).
  static double calculateNetCashFlow(double invested, double returned) {
    return returned - invested;
  }

  /// Calculates Total Invested (outflows) from cash flows.
  static double calculateTotalInvested(List<CashFlowEntity> cashFlows) {
    double total = 0.0;
    for (final cf in cashFlows) {
      if (cf.type.isOutflow) {
        total += cf.amount;
      }
    }
    return total;
  }

  /// Calculates Total Returned (inflows) from cash flows.
  static double calculateTotalReturned(List<CashFlowEntity> cashFlows) {
    double total = 0.0;
    for (final cf in cashFlows) {
      if (cf.type.isInflow) {
        total += cf.amount;
      }
    }
    return total;
  }

  /// Calculates Absolute Return percentage.
  static double calculateAbsoluteReturn(double invested, double returned) {
    if (invested == 0) return 0.0;
    return ((returned - invested) / invested) * 100;
  }
}
