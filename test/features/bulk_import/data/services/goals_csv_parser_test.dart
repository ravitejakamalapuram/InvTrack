import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';

void main() {
  group('GoalsCsvParser', () {
    group('parseString - Basic Parsing', () {
      test('parses valid CSV with all required columns', () {
        const csv =
            '''Name,Type,Target Amount,Target Monthly Income,Target Date,Tracking Mode,Linked Investment IDs,Linked Types,Icon,Color
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
        expect(result.rows.first.linkedInvestmentNames, [
          'inv-1',
          'inv-2',
          'inv-3',
        ]);
      });

      test('parses linked types with semicolon separator', () {
        const csv = '''Name,Type,Target Amount,Linked Types
Type Goal,targetAmount,50000,stock;bond;mutualFund''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.linkedTypes, ['stock', 'bond', 'mutualFund']);
      });

      test('handles empty linked fields', () {
        const csv =
            '''Name,Type,Target Amount,Linked Investment IDs,Linked Types
No Links,targetAmount,50000,,''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.linkedInvestmentNames, isEmpty);
        expect(result.rows.first.linkedTypes, isEmpty);
      });

      test('filters empty parts from semicolon-delimited linkedInvestmentNames',
          () {
        // Semicolons can produce empty parts at start, middle, or end
        const csv =
            '''Name,Type,Target Amount,Linked Investment Names
Goal1,targetAmount,10000,;inv-1;;inv-2;''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 1);
        // Empty parts from leading/trailing/consecutive semicolons are filtered out
        expect(result.rows.first.linkedInvestmentNames, ['inv-1', 'inv-2']);
      });

      test('filters empty parts from semicolon-delimited linkedTypes', () {
        const csv = '''Name,Type,Target Amount,Linked Types
Goal1,targetAmount,10000,stock;;bond;''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.linkedTypes, ['stock', 'bond']);
      });
    });

    group('ParsedGoalsResult', () {
      test('validRowsOnly returns only valid rows', () {
        final validRow = ParsedGoalRow(
          rowNumber: 1,
          name: 'Valid Goal',
          type: 'targetAmount',
          targetAmount: 1000,
          trackingMode: 'all',
          linkedInvestmentNames: const [],
          linkedTypes: const [],
          icon: '🎯',
          colorValue: 0xFF4CAF50,
          currency: 'USD',
        );
        final invalidRow = ParsedGoalRow.withError(
          rowNumber: 2,
          error: 'Missing name',
        );

        final result = ParsedGoalsResult(
          rows: [validRow, invalidRow],
          errors: ['Row 2: Missing name'],
          totalRows: 2,
          validRows: 1,
        );

        expect(result.validRowsOnly.length, 1);
        expect(result.validRowsOnly.first.name, 'Valid Goal');
      });

      test('validRowsOnly returns empty list when all rows are invalid', () {
        final result = ParsedGoalsResult(
          rows: [
            ParsedGoalRow.withError(rowNumber: 1, error: 'Error 1'),
            ParsedGoalRow.withError(rowNumber: 2, error: 'Error 2'),
          ],
          errors: ['Row 1: Error 1', 'Row 2: Error 2'],
          totalRows: 2,
          validRows: 0,
        );

        expect(result.validRowsOnly, isEmpty);
      });

      test('validRowsOnly returns all rows when all are valid', () {
        final rows = [
          ParsedGoalRow(
            rowNumber: 1,
            name: 'Goal A',
            type: 'targetAmount',
            targetAmount: 1000,
            trackingMode: 'all',
            linkedInvestmentNames: const [],
            linkedTypes: const [],
            icon: '🎯',
            colorValue: 0xFF4CAF50,
            currency: 'USD',
          ),
          ParsedGoalRow(
            rowNumber: 2,
            name: 'Goal B',
            type: 'targetAmount',
            targetAmount: 2000,
            trackingMode: 'all',
            linkedInvestmentNames: const [],
            linkedTypes: const [],
            icon: '💰',
            colorValue: 0xFF4CAF50,
            currency: 'USD',
          ),
        ];

        final result = ParsedGoalsResult(
          rows: rows,
          errors: [],
          totalRows: 2,
          validRows: 2,
        );

        expect(result.validRowsOnly.length, 2);
      });

      test('validRows reflects count of rows in the rows list', () {
        // After the PR change, validRows = rows.length (rows only contains valid rows)
        const csv = '''Name,Type,Target Amount
Good Goal 1,targetAmount,10000
Good Goal 2,targetAmount,20000''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, result.rows.length);
        expect(result.validRows, 2);
      });

      test('validRows is 0 when all rows have errors', () {
        const csv = '''Name,Type,Target Amount
,targetAmount,10000
Goal2,,20000''';

        final result = GoalsCsvParser.parseString(csv);

        expect(result.validRows, 0);
        expect(result.rows, isEmpty);
      });

      test('hasErrors returns true when errors list is non-empty', () {
        final result = ParsedGoalsResult(
          rows: [],
          errors: ['Row 1: Missing name'],
          totalRows: 1,
          validRows: 0,
        );

        expect(result.hasErrors, isTrue);
      });

      test('hasErrors returns false when errors list is empty', () {
        final result = ParsedGoalsResult(
          rows: [],
          errors: [],
          totalRows: 0,
          validRows: 0,
        );

        expect(result.hasErrors, isFalse);
      });

      test('validRows matches rows.length for mixed valid/invalid parse result',
          () {
        // Parse CSV where some rows succeed, some fail
        const csv = '''Name,Type,Target Amount
Valid Goal,targetAmount,5000
,targetAmount,5000
Another Valid Goal,targetAmount,8000''';

        final result = GoalsCsvParser.parseString(csv);

        // rows only contains valid rows; validRows equals that count
        expect(result.validRows, result.rows.length);
        expect(result.validRows, 2);
        expect(result.totalRows, 3);
      });
    });
  });
}