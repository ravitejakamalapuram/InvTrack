import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/investment/domain/entities/transaction_entity.dart';

void main() {
  group('SimpleCsvParser', () {
    group('parseString - Basic Parsing', () {
      test('parses valid CSV with all required columns', () {
        const csv = '''Date,Investment Name,Type,Amount,Notes
2024-01-15,Test Investment,INVEST,100000,Initial investment
2024-02-15,Test Investment,INCOME,1500,Monthly interest''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.totalRows, 2);
        expect(result.validRows, 2);
        expect(result.hasErrors, false);
        expect(result.rows.length, 2);

        final firstRow = result.rows.first;
        expect(firstRow.investmentName, 'Test Investment');
        expect(firstRow.type, CashFlowType.invest);
        expect(firstRow.amount, 100000);
        expect(firstRow.notes, 'Initial investment');
      });

      test('handles empty file', () {
        final result = SimpleCsvParser.parseString('');
        expect(result.rows.isEmpty, true);
        expect(result.errors, contains('Empty file'));
      });

      test('returns error for missing required columns', () {
        const csv = 'Date,Investment Name\n2024-01-15,Test';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.hasErrors, true);
        expect(result.errors.first, contains('Missing required columns'));
      });

      test('handles column header variations', () {
        // The parser recognizes 'date', 'investment'/'name', 'type', 'amount'
        const csv = '''Transaction Date,Investment Name,Type,Amount
2024-01-15,My Investment,invest,50000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.investmentName, 'My Investment');
      });
    });

    group('parseString - Date Parsing', () {
      test('parses various date formats', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-15,Test,invest,1000
15-01-2024,Test2,invest,2000
01/15/2024,Test3,invest,3000
15/01/2024,Test4,invest,4000
Jan-24,Test5,invest,5000
September-25,Test6,invest,6000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, greaterThanOrEqualTo(4));
      });

      test('parses Excel serial date numbers', () {
        const csv = '''Date,Investment Name,Type,Amount
45307,Test,invest,1000'''; // 45307 = 2024-01-15

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 1);
        final date = result.rows.first.date;
        expect(date.year, 2024);
      });

      test('returns error for invalid date', () {
        const csv = '''Date,Investment Name,Type,Amount
not-a-date,Test,invest,1000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 0);
        expect(result.errors.first, contains('Invalid date'));
      });
    });

    group('parseString - Type Parsing', () {
      test('parses all valid type variations', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,T1,invest,1000
2024-01-01,T2,investment,1000
2024-01-01,T3,deposit,1000
2024-01-01,T4,income,1000
2024-01-01,T5,interest,1000
2024-01-01,T6,dividend,1000
2024-01-01,T7,return,1000
2024-01-01,T8,withdrawal,1000
2024-01-01,T9,maturity,1000
2024-01-01,T10,fee,1000
2024-01-01,T11,expense,1000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 11);
        expect(result.rows[0].type, CashFlowType.invest);
        expect(result.rows[3].type, CashFlowType.income);
        expect(result.rows[6].type, CashFlowType.returnFlow);
        expect(result.rows[9].type, CashFlowType.fee);
      });

      test('returns error for invalid type', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Test,invalid_type,1000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 0);
        expect(result.errors.first, contains('Invalid type'));
      });
    });

    group('parseString - Amount Parsing', () {
      test('parses amounts with currency symbols', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,T1,invest,₹100000
2024-01-01,T2,invest,\$50000
2024-01-01,T3,invest,€25000
2024-01-01,T4,invest,£30000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 4);
        expect(result.rows[0].amount, 100000);
        expect(result.rows[1].amount, 50000);
      });

      test('parses amounts with commas', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Test,invest,"1,00,000"''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.amount, 100000);
      });

      test('parses negative amounts in parentheses', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Test,invest,(5000)''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.amount, -5000);
      });

      test('returns error for invalid amount', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Test,invest,not-a-number''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 0);
        expect(result.errors.first, contains('Invalid amount'));
      });
    });

    group('parseString - CSV Edge Cases', () {
      test('handles quoted values with commas', () {
        const csv = '''Date,Investment Name,Type,Amount,Notes
2024-01-01,"Investment, with comma",invest,1000,"Notes, with, commas"''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.investmentName, 'Investment, with comma');
        expect(result.rows.first.notes, 'Notes, with, commas');
      });

      test('handles escaped quotes', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,"Investment ""quoted"" name",invest,1000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.investmentName, 'Investment "quoted" name');
      });

      test('skips empty lines', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Test1,invest,1000

2024-01-02,Test2,invest,2000

''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 2);
      });

      test('handles optional notes column', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Test,invest,1000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.notes, isNull);
      });
    });

    group('parseString - Error Handling', () {
      test('returns error for missing date', () {
        const csv = '''Date,Investment Name,Type,Amount
,Test,invest,1000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 0);
        expect(result.errors.first, contains('Missing date'));
      });

      test('returns error for missing investment name', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,,invest,1000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 0);
        expect(result.errors.first, contains('Missing investment name'));
      });

      test('returns error for missing type', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Test,,1000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 0);
        expect(result.errors.first, contains('Missing type'));
      });

      test('returns error for missing amount', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Test,invest,''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 0);
        expect(result.errors.first, contains('Missing amount'));
      });

      test('includes row numbers in error messages', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Good,invest,1000
bad-date,Bad,invest,1000
2024-01-03,Good2,invest,1000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 2);
        expect(result.errors.first, contains('Row 3'));
      });
    });

    group('parse - Bytes Input', () {
      test('parses UTF-8 encoded bytes', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-15,Test Investment,invest,100000''';
        final bytes = Uint8List.fromList(utf8.encode(csv));

        final result = SimpleCsvParser.parse(bytes);

        expect(result.validRows, 1);
        expect(result.rows.first.investmentName, 'Test Investment');
      });
    });

    group('ParsedCashFlowRow', () {
      test('isValid returns true for valid rows', () {
        final row = ParsedCashFlowRow(
          rowNumber: 1,
          date: DateTime(2024, 1, 15),
          investmentName: 'Test',
          type: CashFlowType.invest,
          amount: 1000,
        );

        expect(row.isValid, true);
      });

      test('isValid returns false for error rows', () {
        final row = ParsedCashFlowRow.withError(
          rowNumber: 1,
          error: 'Test error',
        );

        expect(row.isValid, false);
        expect(row.error, 'Test error');
      });
    });

    group('ParsedCsvResult', () {
      test('validRowsOnly filters invalid rows', () {
        final validRow = ParsedCashFlowRow(
          rowNumber: 1,
          date: DateTime.now(),
          investmentName: 'Test',
          type: CashFlowType.invest,
          amount: 1000,
        );
        final invalidRow = ParsedCashFlowRow.withError(
          rowNumber: 2,
          error: 'Error',
        );

        final result = ParsedCsvResult(
          rows: [validRow, invalidRow],
          errors: ['Row 2: Error'],
          totalRows: 2,
          validRows: 1,
        );

        expect(result.validRowsOnly.length, 1);
        expect(result.validRowsOnly.first.investmentName, 'Test');
      });

      test('hasErrors returns true when errors exist', () {
        final result = ParsedCsvResult(
          rows: [],
          errors: ['Some error'],
          totalRows: 1,
          validRows: 0,
        );

        expect(result.hasErrors, true);
      });

      test('hasErrors returns false when no errors', () {
        final result = ParsedCsvResult(
          rows: [],
          errors: [],
          totalRows: 0,
          validRows: 0,
        );

        expect(result.hasErrors, false);
      });
    });
  });
}
