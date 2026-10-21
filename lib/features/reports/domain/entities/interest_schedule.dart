/// Interest schedule per payer for one financial year, to reconcile with
/// AIS/26AS. Amounts are gross interest in the base currency (TDS is not
/// tracked).
library;

class InterestScheduleRow {
  /// Investment platform when set, else the investment name; null when the
  /// flow's investment is unknown (the UI supplies the label).
  final String? payer;
  final double totalInterest;
  final int paymentCount;
  final DateTime firstPaymentDate;
  final DateTime lastPaymentDate;

  const InterestScheduleRow({
    required this.payer,
    required this.totalInterest,
    required this.paymentCount,
    required this.firstPaymentDate,
    required this.lastPaymentDate,
  });
}

class InterestSchedule {
  final String fyLabel;
  final List<InterestScheduleRow> rows;
  final double grandTotal;

  const InterestSchedule({
    required this.fyLabel,
    required this.rows,
    required this.grandTotal,
  });
}
