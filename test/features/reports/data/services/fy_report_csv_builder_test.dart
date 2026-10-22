import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
import 'package:inv_tracker/features/reports/data/services/fy_report_csv_builder.dart';
import 'package:inv_tracker/features/reports/domain/entities/fy_report.dart';

InvestmentEntity _inv(String name) => InvestmentEntity(
  id: 'i',
  name: name,
  type: InvestmentType.stocks,
  status: InvestmentStatus.open,
  startDate: DateTime(2025, 4, 1),
  createdAt: DateTime(2025, 4, 1),
  updatedAt: DateTime(2025, 4, 1),
  currency: 'INR',
);

FYReport _report({double? xirr = 0.1234, List<String> names = const []}) =>
    FYReport(
      fyStart: DateTime(2025, 4, 1),
      fyEnd: DateTime(2026, 3, 31),
      fyLabel: '2025-26',
      totalInvested: 100000,
      totalReturns: 54000.5,
      totalIncome: 4000,
      totalFees: 150.25,
      netCashFlow: -42149.75,
      xirr: xirr,
      monthlyBreakdown: const [
        MonthlyFYData(
          month: 4,
          year: 2025,
          invested: 100000,
          returns: 0,
          income: 0,
          fees: 150.25,
        ),
        MonthlyFYData(
          month: 5,
          year: 2025,
          invested: 0,
          returns: 54000.5,
          income: 4000,
          fees: 0,
        ),
      ],
      topPerformersByReturns: [
        for (final n in names)
          InvestmentWithReturns(
            investment: _inv(n),
            absoluteReturns: 10,
            xirr: null,
            percentageGain: 1,
          ),
      ],
      topPerformersByXIRR: const [],
      portfolioValueAtStart: 0,
      portfolioValueAtEnd: 0,
      shortTermCapitalGains: 0,
      longTermCapitalGains: 0,
      dividendIncome: 1000,
      interestIncome: 3000,
    );

List<List<dynamic>> _parse(String csv) => Csv().decode(csv);

List<dynamic> _row(List<List<dynamic>> rows, String item) =>
    rows.firstWhere((r) => r.length > 1 && r[1] == item);

void main() {
  group('FYReportCsvBuilder', () {
    test('header names base currency and half-open window', () {
      final rows = _parse(FYReportCsvBuilder.build(_report(), 'INR'));
      expect(rows.first, ['Section', 'Item', 'Amount (INR)']);
      expect(_row(rows, 'Period start (inclusive)')[2], '2025-04-01');
      expect(_row(rows, 'Period end (exclusive)')[2], '2026-04-01');
    });

    test('income by type lists interest and dividend', () {
      final rows = _parse(FYReportCsvBuilder.build(_report(), 'INR'));
      expect(_row(rows, 'Interest income')[2], '3000.00');
      expect(_row(rows, 'Dividend income')[2], '1000.00');
    });

    test('capital gains is an explicit not-calculated row, never 0', () {
      final csv = FYReportCsvBuilder.build(_report(), 'INR');
      final rows = _parse(csv);
      expect(_row(rows, 'Capital gains')[2], 'Not calculated');
      expect(csv.contains('Short-term'), isFalse);
    });

    test('cash-flow totals', () {
      final rows = _parse(FYReportCsvBuilder.build(_report(), 'INR'));
      expect(_row(rows, 'Total invested')[2], '100000.00');
      expect(_row(rows, 'Total returns')[2], '54000.50');
      expect(_row(rows, 'Total income')[2], '4000.00');
      expect(_row(rows, 'Total fees')[2], '150.25');
      expect(_row(rows, 'Net cash flow')[2], '-42149.75');
    });

    test('XIRR is a percentage, blank when null', () {
      expect(
        _row(_parse(FYReportCsvBuilder.build(_report(), 'INR')), 'XIRR (%)')[2],
        '12.34',
      );
      expect(
        _row(
          _parse(FYReportCsvBuilder.build(_report(xirr: null), 'INR')),
          'XIRR (%)',
        )[2],
        '',
      );
    });

    test('monthly breakdown rows', () {
      final rows = _parse(FYReportCsvBuilder.build(_report(), 'INR'));
      final head = rows.indexWhere((r) => r.isNotEmpty && r[0] == 'Month');
      expect(rows[head], [
        'Month',
        'Invested (INR)',
        'Returns (INR)',
        'Income (INR)',
        'Fees (INR)',
        'Net (INR)',
      ]);
      expect(rows[head + 1], [
        '2025-04',
        '100000.00',
        '0.00',
        '0.00',
        '150.25',
        '-100150.25',
      ]);
      expect(rows[head + 2][0], '2025-05');
    });

    test('investment names are guarded against formula injection', () {
      final csv = FYReportCsvBuilder.build(
        _report(names: ['=HYPERLINK("x")', 'Safe']),
        'INR',
      );
      final rows = _parse(csv);
      expect(rows.any((r) => r.contains('\'=HYPERLINK("x")')), isTrue);
      expect(rows.any((r) => r.contains('=HYPERLINK("x")')), isFalse);
      expect(rows.any((r) => r.contains('Safe')), isTrue);
    });
  });
}
