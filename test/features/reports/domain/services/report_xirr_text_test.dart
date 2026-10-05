// A71 (#880): report exports show XIRR, a decimal rate, as a percentage,
// and an undefined XIRR as "—".
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/reports/domain/services/report_export_service.dart';

void main() {
  test('a decimal XIRR is exported as a percentage', () {
    expect(formatReportXirr(0.15), '15.00%');
    expect(formatReportXirr(-0.004370445), '-0.44%');
  });

  test('a break-even XIRR is 0.00%, an undefined one "—"', () {
    expect(formatReportXirr(0), '0.00%');
    expect(formatReportXirr(null), '—');
  });

  test('XIRR uses the export locale, like the amounts beside it', () {
    expect(formatReportXirr(0.15, locale: 'de_DE'), '15,00%');
    expect(formatReportXirr(-0.004370445, locale: 'de_DE'), '-0,44%');
    expect(formatReportXirr(123.456, locale: 'en_IN'), '12,345.60%');
    expect(formatReportXirr(null, locale: 'de_DE'), '—');
  });
}
