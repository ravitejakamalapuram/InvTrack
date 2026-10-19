import 'package:inv_tracker/core/calculations/models/cash_flow_interface.dart';

/// Money that came in (RETURN and INCOME) over a half-open date range.
///
/// The one place that totals payouts for a period. Pass flows already
/// converted to one currency (money rule 2).
class PeriodInflows {
  /// Sum of the inflow amounts.
  final double total;

  /// Number of inflows.
  final int count;

  /// Number of distinct investments that paid out.
  final int investmentCount;

  const PeriodInflows({
    required this.total,
    required this.count,
    required this.investmentCount,
  });

  static const empty = PeriodInflows(total: 0, count: 0, investmentCount: 0);

  /// The inflows dated in [start, end), compared on the date only (rule 5).
  factory PeriodInflows.of(
    Iterable<ICashFlow> flows, {
    required DateTime start,
    required DateTime end,
  }) {
    var total = 0.0;
    var count = 0;
    final investments = <String>{};
    for (final flow in flows) {
      final type = flow.calculationType;
      if (type != CalculationCashFlowType.income &&
          type != CalculationCashFlowType.returnFlow) {
        continue;
      }
      final day = DateTime(flow.date.year, flow.date.month, flow.date.day);
      if (day.isBefore(start) || !day.isBefore(end)) continue;
      total += flow.amount;
      count++;
      investments.add(flow.investmentId);
    }
    return PeriodInflows(
      total: total,
      count: count,
      investmentCount: investments.length,
    );
  }
}
