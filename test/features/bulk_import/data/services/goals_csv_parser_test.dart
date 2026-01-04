import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';

void main() {
  group('GoalsCsvParser', () {
    group('parseString - Basic Parsing', () {
      test('parses valid CSV with all required columns', () {
        const csv = '''Name,Type,Target Amount,Target Monthly Income,Target Date,Tracking Mode,Linked Investment IDs,Linked Types,Icon,Color
Retirement Fund,targetAmount,1000000,,,all,,,🎯,4282339765
Emergency Fund,targetAmount,50000,,,all,,,💰,4294951175''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.totalRows, 2);
        expect(result.validRows, 2);
        expect(result.hasErrors, false);
        expect(result.rows.length, 2);

        final firstRow = result.rows.first;
        expect(firstRow.name, 'Retirement Fund');
        expect(firstRow.type, 'targetAmount');
        expect(firstRow.targetAmount, 1000000);
        expect(firstRow.icon, '🎯');
      });

      test('handles missing optional columns gracefully', () {
        const csv = '''Name,Type,Target Amount
Simple Goal,targetAmount,10000''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.hasErrors, false);

        final row = result.rows.first;
        expect(row.trackingMode, 'all'); // Default
        expect(row.icon, '🎯'); // Default
        expect(row.linkedInvestmentNames, isEmpty);
      });

      test('returns error for empty file', () {
        const csv = '';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.hasErrors, true);
        expect(result.errors, contains('Empty file'));
      });

      test('returns error for missing required columns', () {
        const csv = '''Name,Description
Goal1,A goal''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.hasErrors, true);
        expect(result.errors.first, contains('Missing required columns'));
      });
    });

    group('parseString - Row Validation', () {
      test('reports error for missing name', () {
        const csv = '''Name,Type,Target Amount
,targetAmount,10000''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.hasErrors, true);
        expect(result.errors.first, contains('Missing name'));
      });

      test('reports error for missing type', () {
        const csv = '''Name,Type,Target Amount
Test Goal,,10000''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.hasErrors, true);
        expect(result.errors.first, contains('Missing type'));
      });

      test('reports error for invalid target amount', () {
        const csv = '''Name,Type,Target Amount
Test Goal,targetAmount,invalid''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.hasErrors, true);
        expect(result.errors.first, contains('Invalid target amount'));
      });

      test('skips empty lines', () {
        const csv = '''Name,Type,Target Amount
Goal1,targetAmount,10000

Goal2,targetAmount,20000''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 2);
      });
    });

    group('parseString - Optional Fields', () {
      test('parses target monthly income', () {
        const csv = '''Name,Type,Target Amount,Target Monthly Income
Income Goal,monthlyIncome,100000,5000''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.targetMonthlyIncome, 5000);
      });

      test('parses target date in ISO format', () {
        const csv = '''Name,Type,Target Amount,Target Date
Deadline Goal,targetAmount,50000,2025-12-31''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.targetDate, DateTime(2025, 12, 31));
      });

      test('parses linked investment IDs with semicolon separator', () {
        const csv = '''Name,Type,Target Amount,Linked Investment IDs
Multi-Link Goal,targetAmount,50000,inv-1;inv-2;inv-3''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.linkedInvestmentNames, ['inv-1', 'inv-2', 'inv-3']);
      });

      test('parses linked types with semicolon separator', () {
        const csv = '''Name,Type,Target Amount,Linked Types
Type Goal,targetAmount,50000,stock;bond;mutualFund''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.linkedTypes, ['stock', 'bond', 'mutualFund']);
      });

      test('handles empty linked fields', () {
        const csv = '''Name,Type,Target Amount,Linked Investment IDs,Linked Types
No Links,targetAmount,50000,,''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.linkedInvestmentNames, isEmpty);
        expect(result.rows.first.linkedTypes, isEmpty);
      });
    });
  });
}

