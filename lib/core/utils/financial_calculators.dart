import 'dart:math';
import 'package:inv_tracker/domain/entities/entry.dart';

/// Cash flow for XIRR calculation.
class CashFlow {
  final DateTime date;
  final double amount;

  const CashFlow({required this.date, required this.amount});
}

/// Financial calculators for investment analysis.
class FinancialCalculators {
  FinancialCalculators._();

  /// XIRR: Extended Internal Rate of Return using Newton-Raphson method.
  ///
  /// [cashFlows] List of cash flows where:
  ///   - Negative amounts are outflows (investments)
  ///   - Positive amounts are inflows (returns/current value)
  ///
  /// Returns annualized rate as decimal (0.15 = 15%), or null if doesn't converge.
  static double? calculateXIRR(List<CashFlow> cashFlows, {double guess = 0.1}) {
    if (cashFlows.isEmpty || cashFlows.length < 2) return null;

    const maxIterations = 100;
    const tolerance = 1e-7;

    // Sort by date
    final sorted = List<CashFlow>.from(cashFlows)..sort((a, b) => a.date.compareTo(b.date));
    final firstDate = sorted.first.date;

    double rate = guess;

    for (int i = 0; i < maxIterations; i++) {
      double npv = 0;
      double dnpv = 0; // derivative

      for (final cf in sorted) {
        final years = cf.date.difference(firstDate).inDays / 365.0;
        if (1 + rate <= 0) {
          rate = 0.01; // Reset if rate goes too negative
          continue;
        }
        final factor = pow(1 + rate, years);
        npv += cf.amount / factor;
        dnpv -= years * cf.amount / (factor * (1 + rate));
      }

      if (dnpv.abs() < 1e-10) return null; // Avoid division by zero

      final newRate = rate - npv / dnpv;

      if ((newRate - rate).abs() < tolerance) {
        return newRate;
      }

      rate = newRate;

      // Bound the rate to reasonable values
      if (rate < -0.99) rate = -0.99;
      if (rate > 10) rate = 10;
    }

    return null; // Did not converge
  }

  /// CAGR: Compound Annual Growth Rate.
  ///
  /// Formula: (EndValue / StartValue)^(1/years) - 1
  static double calculateCAGR(double startValue, double endValue, double years) {
    if (startValue <= 0 || years <= 0) return 0;
    return pow(endValue / startValue, 1 / years) - 1;
  }

  /// CAGR from dates.
  static double calculateCAGRFromDates(double startValue, double endValue, DateTime startDate, DateTime endDate) {
    final years = endDate.difference(startDate).inDays / 365.0;
    return calculateCAGR(startValue, endValue, years);
  }

  /// MOIC: Multiple on Invested Capital.
  ///
  /// Formula: CurrentValue / TotalInvested
  static double calculateMOIC(double currentValue, double totalInvested) {
    if (totalInvested <= 0) return 0;
    return currentValue / totalInvested;
  }

  /// Absolute P/L (Profit/Loss).
  static double calculateAbsolutePL(double currentValue, double totalInvested) {
    return currentValue - totalInvested;
  }

  /// Percentage P/L.
  static double calculatePercentagePL(double currentValue, double totalInvested) {
    if (totalInvested <= 0) return 0;
    return ((currentValue - totalInvested) / totalInvested) * 100;
  }

  /// Calculate total invested from entries (inflows - outflows).
  static double calculateTotalInvested(List<Entry> entries) {
    return entries.fold(0.0, (sum, e) {
      if (e.type == EntryType.inflow) return sum + e.amount;
      if (e.type == EntryType.outflow) return sum - e.amount;
      return sum;
    });
  }

  /// Calculate total dividends received.
  static double calculateTotalDividends(List<Entry> entries) {
    return entries.where((e) => e.type == EntryType.dividend).fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Calculate total expenses.
  static double calculateTotalExpenses(List<Entry> entries) {
    return entries.where((e) => e.type == EntryType.expense).fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Get current value from latest valuation entry.
  static double? getCurrentValue(List<Entry> entries) {
    final valuations = entries.where((e) => e.type == EntryType.valuation).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return valuations.isNotEmpty ? valuations.first.amount : null;
  }

  /// Convert entries to cash flows for XIRR.
  ///
  /// Inflows are negative (money going out from investor)
  /// Outflows and current value are positive (money coming back)
  static List<CashFlow> entriesToCashFlows(List<Entry> entries, {double? currentValue, DateTime? currentDate}) {
    final flows = <CashFlow>[];

    for (final e in entries) {
      switch (e.type) {
        case EntryType.inflow:
          flows.add(CashFlow(date: e.date, amount: -e.amount)); // Investment = negative
        case EntryType.outflow:
          flows.add(CashFlow(date: e.date, amount: e.amount)); // Withdrawal = positive
        case EntryType.dividend:
          flows.add(CashFlow(date: e.date, amount: e.amount)); // Dividend = positive
        case EntryType.expense:
          flows.add(CashFlow(date: e.date, amount: -e.amount)); // Expense = negative
        case EntryType.valuation:
          break; // Skip valuations, we'll add current value separately
      }
    }

    // Add current value as final positive cash flow
    if (currentValue != null && currentValue > 0) {
      flows.add(CashFlow(date: currentDate ?? DateTime.now(), amount: currentValue));
    }

    return flows;
  }
}

