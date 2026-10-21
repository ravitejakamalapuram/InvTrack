import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/reporting/metric_value.dart';
import 'package:inv_tracker/core/reporting/report_definition.dart';
import 'package:inv_tracker/core/reporting/report_definitions.dart';
import 'package:inv_tracker/core/reporting/report_formatter.dart';
import 'package:inv_tracker/core/reporting/report_period.dart';

void main() {
  const fmt = ReportFormatter(symbol: '₹', locale: 'en_IN');

  test('unknown is an em dash, never 0 or 0%', () {
    const u = Unknown(UnknownReason.awaitingValue);
    expect(fmt.money(u), '—');
    expect(fmt.percent(u), '—');
  });

  test('known money uses Indian grouping and two decimals', () {
    expect(fmt.money(const Known(1234567.5)), '₹12,34,567.50');
    expect(fmt.money(const Known(0)), '₹0.00');
  });

  test('percent keeps one decimal and an optional plus', () {
    expect(fmt.percent(const Known(12.54), signed: true), '+12.5%');
    expect(fmt.percent(const Known(-3)), '-3.0%');
    expect(fmt.percent(const Known(0), signed: true), '0.0%');
  });

  test(
    'privacy hides every known amount but still shows unknown as a dash',
    () {
      const p = ReportFormatter(symbol: '₹', locale: 'en_IN', privacy: true);
      expect(p.money(const Known(1234567.5)), ReportFormatter.masked);
      expect(p.money(const Unknown(UnknownReason.awaitingValue)), '—');
    },
  );

  test('definitions: weekly, monthly, yearly', () {
    expect(definitionFor(ReportPeriodKind.week), weeklyReport);
    expect(definitionFor(ReportPeriodKind.month), monthlyReport);
    expect(definitionFor(ReportPeriodKind.fy), yearlyReport);
    expect(yearlyReport.breakdowns, contains(Breakdown.byMonth));
    expect(() => definitionFor(ReportPeriodKind.custom), throwsArgumentError);
    for (final d in [weeklyReport, monthlyReport, yearlyReport]) {
      expect(d.comparePrevious, isTrue);
      expect(d.metrics, contains(ReportMetric.netCashFlow));
    }
  });
}
