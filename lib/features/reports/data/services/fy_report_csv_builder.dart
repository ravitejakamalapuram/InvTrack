import 'package:csv/csv.dart';
import 'package:inv_tracker/core/utils/csv_utils.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';

/// Builds a CSV of a Tax-Year (FY) report. Pure: no I/O, no Flutter.
///
/// All amounts are in [baseCurrency]. The window is half-open
/// [1 Apr, 1 Apr next year). Capital gains are not computed by the app yet, so
/// they are written as an explicit "Not calculated" row, never as 0.
class FYReportCsvBuilder {
  FYReportCsvBuilder._();

  static const notCalculated = 'Not calculated';

  static const masked = '••••••';

  /// With [maskSensitiveData] (privacy mode) amounts, XIRR and investment
  /// names are replaced by [masked].
  static String build(
    FYReport r,
    String baseCurrency, {
    bool maskSensitiveData = false,
  }) {
    String amt(double v) => maskSensitiveData ? masked : v.toStringAsFixed(2);
    String day(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';

    final rows = <List<dynamic>>[
      ['Section', 'Item', 'Amount ($baseCurrency)'],
      ['Report', 'Financial year', r.fyLabel],
      ['Report', 'Period start (inclusive)', day(r.fyStart)],
      [
        'Report',
        'Period end (exclusive)',
        day(DateTime(r.fyStart.year + 1, r.fyStart.month, r.fyStart.day)),
      ],
      ['Income by type', 'Interest income', amt(r.interestIncome)],
      ['Income by type', 'Dividend income', amt(r.dividendIncome)],
      ['Capital gains', 'Capital gains', notCalculated],
      ['Cash flow', 'Total invested', amt(r.totalInvested)],
      ['Cash flow', 'Total returns', amt(r.totalReturns)],
      ['Cash flow', 'Total income', amt(r.totalIncome)],
      ['Cash flow', 'Total fees', amt(r.totalFees)],
      ['Cash flow', 'Net cash flow', amt(r.netCashFlow)],
      [
        'Performance',
        'XIRR (%)',
        r.xirr == null
            ? ''
            : maskSensitiveData
            ? masked
            : (r.xirr! * 100).toStringAsFixed(2),
      ],
    ];

    if (r.topPerformersByReturns.isNotEmpty) {
      rows
        ..add([])
        ..add(['Top performers', 'Investment', 'Returns ($baseCurrency)']);
      for (final p in r.topPerformersByReturns) {
        rows.add([
          'Top performers',
          maskSensitiveData
              ? masked
              : CsvUtils.sanitizeField(p.investment.name),
          amt(p.absoluteReturns),
        ]);
      }
    }

    rows
      ..add([])
      ..add([
        'Month',
        'Invested ($baseCurrency)',
        'Returns ($baseCurrency)',
        'Income ($baseCurrency)',
        'Fees ($baseCurrency)',
        'Net ($baseCurrency)',
      ]);
    for (final m in r.monthlyBreakdown) {
      rows.add([
        '${m.year}-${m.month.toString().padLeft(2, '0')}',
        amt(m.invested),
        amt(m.returns),
        amt(m.income),
        amt(m.fees),
        amt(m.net),
      ]);
    }

    return Csv().encoder.convert(rows);
  }
}
