import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';

void main() {
  group('SimpleCsvParser date parsing', () {
    test('parses various date formats without errors', () {
      final testDates = [
        'Sept-25',
        'Sep-25',
        'Jan-21',
        'September 2025',
        '2025-09-01',
        'Jan/21',
        'Feb-22',
        'Dec-24',
        'Aug 23',
      ];

      for (final d in testDates) {
        final csv =
            'Date,Investment Name,Type,Amount\n$d,Test Investment,INVEST,1000';
        final result = SimpleCsvParser.parseString(csv);

        expect(
          result.errors,
          isEmpty,
          reason: 'Date "$d" should parse without errors',
        );
        expect(
          result.rows,
          isNotEmpty,
          reason: 'Date "$d" should produce at least one row',
        );
      }
    });

    test('parses Sept-25 correctly as September 2025', () {
      final csv = 'Date,Investment Name,Type,Amount\nSept-25,Test,INVEST,1000';
      final result = SimpleCsvParser.parseString(csv);

      expect(result.errors, isEmpty,
          reason: 'Sept-25 should parse without errors');
      expect(result.rows.first.date.month, 9);
      expect(result.rows.first.date.year, 2025);
    });

    test('parses ISO date format correctly', () {
      final csv =
          'Date,Investment Name,Type,Amount\n2024-06-15,Test,INVEST,5000';
      final result = SimpleCsvParser.parseString(csv);

      expect(result.errors, isEmpty);
      expect(result.rows.first.date.year, 2024);
      expect(result.rows.first.date.month, 6);
      expect(result.rows.first.date.day, 15);
    });

    test('parses month-year format with slash separator', () {
      final csv = 'Date,Investment Name,Type,Amount\nJan/21,Test,INVEST,1000';
      final result = SimpleCsvParser.parseString(csv);

      expect(result.errors, isEmpty);
      expect(result.rows.first.date.month, 1);
      expect(result.rows.first.date.year, 2021);
    });

    test('handles invalid date gracefully', () {
      final csv =
          'Date,Investment Name,Type,Amount\nNotADate,Test,INVEST,1000';
      final result = SimpleCsvParser.parseString(csv);

      // Should either produce an error or skip the row
      expect(
        result.errors.isNotEmpty || result.rows.isEmpty,
        isTrue,
        reason: 'Invalid date should produce an error or be skipped',
      );
    });
  });
}
