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
}
