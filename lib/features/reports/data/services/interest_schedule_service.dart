/// Builds the per-payer interest schedule for a financial year.
library;

import 'package:inv_tracker/core/calculations/calculation_engine.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_service.dart';
import 'package:inv_tracker/features/reports/domain/entities/interest_schedule.dart';

/// Named payers sorted by name; the unmatched-investment row (null) last.
int _byPayer(String? a, String? b) {
  if (a == null || b == null) return a == null ? (b == null ? 0 : 1) : -1;
  return a.compareTo(b);
}

class InterestScheduleService {
  final CalculationEngine _engine;

  InterestScheduleService(this._engine);

  /// [fyYear] is the year the FY starts (2023 for FY 2023-24). The window is
  /// the half-open [1 Apr fyYear, 1 Apr fyYear+1) on date-only values, as in
  /// [FYReportService]. A flow with no currency rate is left out. Flows whose investment
  /// is not in [allInvestments] are grouped under a null payer.
  Future<InterestSchedule> generate({
    required int fyYear,
    required List<CashFlowEntity> allCashFlows,
    required List<InvestmentEntity> allInvestments,
    required String baseCurrency,
  }) async {
    final start = DateTime(fyYear, 4, 1);
    final endExclusive = DateTime(fyYear + 1, 4, 1);

    final baseFlows = await _engine.currency.batchConvertToBase(
      cashFlows: allCashFlows,
      baseCurrency: baseCurrency,
    );

    final payerById = {
      for (final i in allInvestments)
        i.id: i.hasPlatform ? i.platform! : i.name,
    };

    final totals = <String?, double>{};
    final counts = <String?, int>{};
    final firsts = <String?, DateTime>{};
    final lasts = <String?, DateTime>{};
    var grandTotal = 0.0;

    for (final cf in baseFlows) {
      final day = DateTime(cf.date.year, cf.date.month, cf.date.day);
      if (day.isBefore(start) || !day.isBefore(endExclusive)) continue;
      if (!isInterestIncomeFlow(cf)) continue;

      final payer = payerById[cf.investmentId];
      totals[payer] = (totals[payer] ?? 0) + cf.amount;
      counts[payer] = (counts[payer] ?? 0) + 1;
      final first = firsts[payer];
      if (first == null || day.isBefore(first)) firsts[payer] = day;
      final last = lasts[payer];
      if (last == null || day.isAfter(last)) lasts[payer] = day;
      grandTotal += cf.amount;
    }

    final rows = [
      for (final payer in totals.keys.toList()..sort(_byPayer))
        InterestScheduleRow(
          payer: payer,
          totalInterest: totals[payer]!,
          paymentCount: counts[payer]!,
          firstPaymentDate: firsts[payer]!,
          lastPaymentDate: lasts[payer]!,
        ),
    ];

    return InterestSchedule(
      fyLabel: '$fyYear-${(fyYear + 1) % 100}',
      rows: rows,
      grandTotal: grandTotal,
    );
  }
}
