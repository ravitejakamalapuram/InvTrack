import 'package:inv_tracker/core/calculations/models/cash_flow_interface.dart';

/// A data structure representing monthly cash flow totals.
class MonthlyBucket {
  /// Money invested (outflow) during the month.
  final double invested;

  /// Money returned from exit/sale (inflow) during the month.
  final double returns;

  /// Income received (inflow) during the month.
  final double income;

  /// Fees or expenses paid (outflow) during the month.
  final double fees;

  const MonthlyBucket({
    this.invested = 0.0,
    this.returns = 0.0,
    this.income = 0.0,
    this.fees = 0.0,
  });

  /// Computes net cash flow for the bucket (inflows - outflows).
  double get net => (returns + income) - (invested + fees);
}

/// A pure utility class for calculating taxes, holding periods,
/// and aggregation buckets.
class TaxAndBasisCalculator {
  /// Aggregates a list of cash flows into monthly buckets.
  ///
  /// Returns a map where keys are the first day of each month (e.g. DateTime(2023, 5, 1)).
  static Map<DateTime, MonthlyBucket> calculateMonthlyBuckets(
    List<ICashFlow> cashFlows,
  ) {
    final Map<DateTime, MonthlyBucket> buckets = {};

    for (final cf in cashFlows) {
      final monthKey = DateTime(cf.date.year, cf.date.month, 1);
      final current = buckets[monthKey] ?? const MonthlyBucket();

      double invested = current.invested;
      double returns = current.returns;
      double income = current.income;
      double fees = current.fees;

      switch (cf.calculationType) {
        case CalculationCashFlowType.invest:
          invested += cf.amount;
          break;
        case CalculationCashFlowType.returnFlow:
          returns += cf.amount;
          break;
        case CalculationCashFlowType.income:
          income += cf.amount;
          break;
        case CalculationCashFlowType.fee:
          fees += cf.amount;
          break;
      }

      buckets[monthKey] = MonthlyBucket(
        invested: invested,
        returns: returns,
        income: income,
        fees: fees,
      );
    }

    return buckets;
  }

  /// Calculates capital gains (short-term vs long-term) based on holding periods.
  ///
  /// - Short-term gains: holding period < 365 days.
  /// - Long-term gains: holding period >= 365 days.
  static (double shortTermGains, double longTermGains) calculateCapitalGains({
    required List<ICashFlow> cashFlows,
    required Map<String, DateTime> investmentStartDates,
    double assumedGainPercentage = 0.10, // Default 10%
  }) {
    double shortTermGains = 0;
    double longTermGains = 0;

    for (final cf in cashFlows) {
      if (cf.calculationType == CalculationCashFlowType.returnFlow) {
        final startDate = investmentStartDates[cf.investmentId];
        if (startDate == null) continue;

        final holdingDays = cf.date.difference(startDate).inDays;
        final gain = cf.amount * assumedGainPercentage;

        if (holdingDays < 365) {
          shortTermGains += gain;
        } else {
          longTermGains += gain;
        }
      }
    }

    return (shortTermGains, longTermGains);
  }
}
