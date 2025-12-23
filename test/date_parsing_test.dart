import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/domain/services/simple_csv_parser.dart';

void main() {
  test('SimpleCsvParser can parse various date formats', () {
    final testDates = [
      'Sept-25', 'Sep-25', 'Jan-21', 'September 2025', '2025-09-01',
      'Jan/21', 'Feb-22', 'Dec-24', 'Aug 23',
    ];

    for (final d in testDates) {
      final csv = 'Date,Investment Name,Type,Amount\n$d,Test Investment,INVEST,1000';
      final result = SimpleCsvParser.parseString(csv);

      if (result.errors.isEmpty) {
        print('$d -> ${result.rows.first.date}');
      } else {
        print('$d -> ERROR: ${result.errors.first}');
      }
    }

    // Verify specific cases work
    final septCsv = 'Date,Investment Name,Type,Amount\nSept-25,Test,INVEST,1000';
    final septResult = SimpleCsvParser.parseString(septCsv);
    expect(septResult.errors, isEmpty, reason: 'Sept-25 should parse without errors');
    expect(septResult.rows.first.date.month, 9);
    expect(septResult.rows.first.date.year, 2025);
  });
}
