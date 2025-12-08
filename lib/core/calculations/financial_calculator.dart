import 'dart:math';
import 'package:inv_tracker/core/calculations/xirr_solver.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

class FinancialCalculator {
  /// Calculates XIRR from a list of transactions and the current value of the investment.
  /// The current value is treated as a "sell" at the current date.
  static double calculateXirr(List<TransactionEntity> transactions, double currentValue) {
    if (transactions.isEmpty) return 0.0;

    final dates = <DateTime>[];
    final amounts = <double>[];

    for (final t in transactions) {
      dates.add(t.date);
      // Outflows (BUY) are negative, Inflows (SELL, DIVIDEND) are positive
      if (t.type == 'BUY') {
        amounts.add(-(t.totalAmount));
      } else {
        amounts.add(t.totalAmount);
      }
    }

    // Add current value as a positive cash flow at today's date
    dates.add(DateTime.now());
    amounts.add(currentValue);

    return XirrSolver.calculateXirr(dates, amounts);
  }

  /// Calculates CAGR (Compound Annual Growth Rate).
  static double calculateCAGR(double startValue, double endValue, double years) {
    if (startValue <= 0 || years <= 0) return 0.0;
    return pow(endValue / startValue, 1 / years) - 1;
  }

  /// Calculates MOIC (Multiple on Invested Capital).
  static double calculateMOIC(double invested, double current) {
    if (invested == 0) return 0.0;
    return current / invested;
  }

  /// Calculates Absolute Profit/Loss.
  static double calculateProfitLoss(double invested, double current) {
    return current - invested;
  }

  /// Calculates Total Invested Amount from transactions.
  static double calculateTotalInvested(List<TransactionEntity> transactions) {
    double total = 0.0;
    for (final t in transactions) {
      if (t.type == 'BUY') {
        total += t.totalAmount;
      } else if (t.type == 'SELL') {
        // Selling reduces the "net invested" if we consider it that way,
        // but typically "Total Invested" means total capital deployed.
        // For P&L, we usually compare Net Invested (Buy - Sell) vs Current Value.
        // Let's return Net Invested here.
        total -= t.totalAmount;
      }
    }
    return total;
  }
}
