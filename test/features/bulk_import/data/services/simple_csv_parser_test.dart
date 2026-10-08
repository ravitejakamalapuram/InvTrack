import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/data/services/csv_template_service.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';
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
      test('parses various date formats with one day/month order', () {
        // Two rows prove day-first (15-01-2024, 15/01/2024) and one proves
        // month-first (01/15/2024). The file is read day-first, so the
        // month-first row is reported instead of being read differently.
        const csv = '''Date,Investment Name,Type,Amount
2024-01-15,Test,invest,1000
15-01-2024,Test2,invest,2000
01/15/2024,Test3,invest,3000
15/01/2024,Test4,invest,4000
Jan-24,Test5,invest,5000
September-25,Test6,invest,6000''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.rows.map((r) => r.date).toList(), [
          DateTime(2024, 1, 15),
          DateTime(2024, 1, 15),
          DateTime(2024, 1, 15),
          DateTime(2024, 1, 1),
          DateTime(2025, 9, 1),
        ]);
        expect(result.rows.map((r) => r.investmentName).toList(), [
          'Test',
          'Test2',
          'Test4',
          'Test5',
          'Test6',
        ]);
        expect(result.errors, hasLength(1));
        expect(result.errors.single, startsWith('Row 4:'));
      });

      test('parses Excel serial date numbers', () {
        const csv = '''Date,Investment Name,Type,Amount
45306,Test,invest,1000'''; // =DATE(2024,1,15) in Excel is 45306

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 1);
        expect(result.rows.first.date, DateTime(2024, 1, 15));
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

      // A negative INVEST would count as money coming in; Type sets the
      // direction, as in manual entry, so the amount must be positive.
      test('a negative amount in parentheses is an error', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Test,invest,(5000)''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.validRows, 0);
        expect(result.errors.single, startsWith('Row 2: Amount must be more'));
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
          currency: 'USD', // Multi-currency support (Rule 21.4)
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
          currency: 'USD', // Multi-currency support (Rule 21.4)
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

    // ============ MULTI-CURRENCY TESTS (Rule 21.4) ============
    group('Multi-Currency Support (Rule 21.4)', () {
      group('6-Column Format (with Currency)', () {
        test('parses CSV with Currency column', () {
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-15,US Stocks,INVEST,1000,USD,Initial investment
2024-02-01,Indian FD,INVEST,100000,INR,Fixed deposit
2024-03-01,European Bonds,INVEST,800,EUR,Government bonds''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.totalRows, 3);
          expect(result.validRows, 3);
          expect(result.hasErrors, false);

          // Verify currencies are preserved
          expect(result.rows[0].currency, 'USD');
          expect(result.rows[1].currency, 'INR');
          expect(result.rows[2].currency, 'EUR');
        });

        test('preserves original currency from CSV', () {
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,Singapore Investment,INVEST,5000,SGD,Singapore Dollar''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 1);
          expect(result.rows.first.currency, 'SGD');
        });

        test('blank currency cell gives the base currency, not USD', () {
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,Test,INVEST,1000,,No currency specified''';

          final result = SimpleCsvParser.parseString(csv, baseCurrency: 'INR');

          expect(result.validRows, 1);
          expect(result.rows.first.currency, 'INR');
        });

        test(
          'blank currency cell without a base currency stays unresolved',
          () {
            const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,Test,INVEST,1000,,No currency specified''';

            final result = SimpleCsvParser.parseString(csv);

            expect(result.validRows, 1);
            // The caller resolves it to the user's base currency; never USD.
            expect(result.rows.first.currency, isNull);
          },
        );

        test('trims whitespace from currency codes', () {
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,Test,INVEST,1000,  USD  ,Whitespace around currency''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 1);
          expect(result.rows.first.currency, 'USD');
        });

        test('uppercases currency codes', () {
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,Test,INVEST,1000,usd,Lowercase currency''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 1);
          // Currency codes are normalized to uppercase
          expect(result.rows.first.currency, 'USD');
        });
      });

      group('5-Column Format (Backward Compatibility)', () {
        test(
          'defaults to the base currency when Currency column is missing',
          () {
            const csv = '''Date,Investment Name,Type,Amount,Notes
2024-01-15,Test Investment,INVEST,1000,No currency column''';

            final result = SimpleCsvParser.parseString(
              csv,
              baseCurrency: 'INR',
            );

            expect(result.validRows, 1);
            expect(result.rows.first.currency, 'INR');
          },
        );

        test('handles old 5-column format without errors', () {
          const csv = '''Date,Investment Name,Type,Amount,Notes
2024-01-01,Investment 1,INVEST,1000,Note 1
2024-01-02,Investment 2,INCOME,50,Note 2
2024-01-03,Investment 3,RETURN,500,Note 3''';

          final result = SimpleCsvParser.parseString(csv, baseCurrency: 'INR');

          expect(result.validRows, 3);
          expect(result.hasErrors, false);

          // Every row takes the user's base currency
          for (final row in result.rows) {
            expect(row.currency, 'INR');
          }
        });

        test('a CSV with no Currency column never becomes USD', () {
          const csv = '''Date,Investment Name,Type,Amount
2024-01-15,HDFC FD,INVEST,100000
2024-06-01,HDFC FD,INCOME,3500''';

          final withBase = SimpleCsvParser.parseString(
            csv,
            baseCurrency: 'INR',
          );
          final withoutBase = SimpleCsvParser.parseString(csv);

          expect(withBase.rows.map((r) => r.currency), ['INR', 'INR']);
          expect(withBase.rows.map((r) => r.amount), [100000.0, 3500.0]);
          expect(withoutBase.rows.map((r) => r.currency), [null, null]);
        });

        test('bytes entry point passes the base currency through', () {
          final bytes = Uint8List.fromList(
            utf8.encode(
              'Date,Investment Name,Type,Amount\n'
              '2024-01-15,HDFC FD,INVEST,100000',
            ),
          );

          final result = SimpleCsvParser.parse(bytes, baseCurrency: 'INR');

          expect(result.rows.single.currency, 'INR');
        });
      });

      group('Data Integrity (Rule 21.1)', () {
        test('does not convert amounts based on currency', () {
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,Test 1,INVEST,1000,USD,
2024-01-02,Test 2,INVEST,1000,INR,
2024-01-03,Test 3,INVEST,1000,EUR,''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 3);

          // Amounts should remain unchanged (no conversion)
          expect(result.rows[0].amount, 1000.0);
          expect(result.rows[1].amount, 1000.0);
          expect(result.rows[2].amount, 1000.0);

          // Currencies should be preserved
          expect(result.rows[0].currency, 'USD');
          expect(result.rows[1].currency, 'INR');
          expect(result.rows[2].currency, 'EUR');
        });

        test('preserves original data on import', () {
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,US Tech Stocks,INVEST,1000.00,USD,Initial investment
2024-01-15,US Tech Stocks,INCOME,50.00,USD,Q1 dividend
2024-02-01,Indian FD,INVEST,100000.00,INR,Fixed deposit 1 year
2024-03-01,European Bonds,INVEST,800.00,EUR,Government bonds''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 4);

          // Verify first investment
          expect(result.rows[0].investmentName, 'US Tech Stocks');
          expect(result.rows[0].type, CashFlowType.invest);
          expect(result.rows[0].amount, 1000.0);
          expect(result.rows[0].currency, 'USD');

          // Verify dividend
          expect(result.rows[1].type, CashFlowType.income);
          expect(result.rows[1].amount, 50.0);
          expect(result.rows[1].currency, 'USD');

          // Verify Indian FD
          expect(result.rows[2].investmentName, 'Indian FD');
          expect(result.rows[2].amount, 100000.0);
          expect(result.rows[2].currency, 'INR');

          // Verify European bonds
          expect(result.rows[3].currency, 'EUR');
        });
      });

      group('Real-World Scenarios', () {
        test('handles export-import round trip without data loss', () {
          // Simulating data exported from app with multi-currency support
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,US Tech Stocks,INVEST,1000.00,USD,Initial investment
2024-01-15,US Tech Stocks,INCOME,50.00,USD,Q1 dividend
2024-02-01,Indian FD,INVEST,100000.00,INR,Fixed deposit 1 year
2024-02-15,Indian FD,INCOME,2000.00,INR,Monthly interest
2024-03-01,European Bonds,INVEST,800.00,EUR,Government bonds
2024-03-15,European Bonds,INCOME,20.00,EUR,Quarterly interest''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 6);
          expect(result.hasErrors, false);

          // Verify all data preserved
          final currencies = result.rows.map((r) => r.currency).toSet();
          expect(currencies, containsAll(['USD', 'INR', 'EUR']));

          // Verify amounts not modified
          expect(result.rows[0].amount, 1000.0);
          expect(result.rows[2].amount, 100000.0);
          expect(result.rows[4].amount, 800.0);
        });

        test('handles mixed 5-column and 6-column formats gracefully', () {
          // User manually adds Currency column to old CSV
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,Old Investment,INVEST,1000,USD,Migrated from old format
2024-01-02,New Investment,INVEST,2000,EUR,New format''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 2);
          expect(result.rows[0].currency, 'USD');
          expect(result.rows[1].currency, 'EUR');
        });

        test('handles CSV with special characters in notes', () {
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,Test,INVEST,1000,USD,"Note with, comma"
2024-01-02,Test,INCOME,50,USD,"Note with ""quotes"""''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 2);
          expect(result.rows[0].currency, 'USD');
          expect(result.rows[1].currency, 'USD');
        });

        test('handles all supported currencies', () {
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,USD Investment,INVEST,1000,USD,US Dollar
2024-01-02,EUR Investment,INVEST,1000,EUR,Euro
2024-01-03,GBP Investment,INVEST,1000,GBP,British Pound
2024-01-04,INR Investment,INVEST,1000,INR,Indian Rupee
2024-01-05,JPY Investment,INVEST,1000,JPY,Japanese Yen
2024-01-06,AUD Investment,INVEST,1000,AUD,Australian Dollar
2024-01-07,CAD Investment,INVEST,1000,CAD,Canadian Dollar
2024-01-08,CHF Investment,INVEST,1000,CHF,Swiss Franc
2024-01-09,CNY Investment,INVEST,1000,CNY,Chinese Yuan
2024-01-10,SGD Investment,INVEST,1000,SGD,Singapore Dollar''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 10);
          expect(result.hasErrors, false);

          final currencies = result.rows.map((r) => r.currency).toList();
          expect(
            currencies,
            containsAll([
              'USD',
              'EUR',
              'GBP',
              'INR',
              'JPY',
              'AUD',
              'CAD',
              'CHF',
              'CNY',
              'SGD',
            ]),
          );
        });
      });

      group('Edge Cases', () {
        test('handles CSV with extra columns after Currency', () {
          const csv =
              '''Date,Investment Name,Type,Amount,Currency,Notes,Extra Column
2024-01-01,Test,INVEST,1000,USD,Note,Extra Data''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 1);
          expect(result.rows.first.currency, 'USD');
        });

        test('handles inconsistent column count', () {
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,Test 1,INVEST,1000,USD,Note 1
2024-01-02,Test 2,INVEST,2000,Note 2 missing currency''';

          final result = SimpleCsvParser.parseString(csv);

          // First row should parse correctly
          expect(result.rows.any((r) => r.investmentName == 'Test 1'), true);
          final test1 = result.rows.firstWhere(
            (r) => r.investmentName == 'Test 1',
          );
          expect(test1.currency, 'USD');
        });

        test('reports a currency code that is not supported', () {
          // A14: an unknown code used to be stored and then failed every FX
          // conversion. It is now a row error, like on the goals CSV.
          const csv = '''Date,Investment Name,Type,Amount,Currency,Notes
2024-01-01,Test,INVEST,1000,USD123,Not a currency''';

          final result = SimpleCsvParser.parseString(csv);

          expect(result.validRows, 0);
          expect(result.errors.single, 'Row 2: Invalid currency code: USD123');
        });
      });
    });

    // ============ A25: read the file the way it is meant ============
    group('Dates are read with one order per file (A25)', () {
      ParsedCsvResult parseDates(List<String> dates, {CsvDateOrder? order}) {
        final csv = [
          'Date,Investment Name,Type,Amount',
          for (var i = 0; i < dates.length; i++)
            '${dates[i]},Inv ${i + 1},INVEST,1000',
        ].join('\n');
        return SimpleCsvParser.parseString(csv, dateOrder: order);
      }

      test('two-digit years are read as this century', () {
        expect(parseDates(['05-03-24']).rows.single.date, DateTime(2024, 3, 5));
        expect(parseDates(['5-Mar-24']).rows.single.date, DateTime(2024, 3, 5));
        expect(parseDates(['05/03/24']).rows.single.date, DateTime(2024, 3, 5));
      });

      test('one month-first row does not flip a day-first file', () {
        final result = parseDates([
          '13/02/2024',
          '05/03/2024',
          '01/13/2024',
          '05/03/2024',
        ]);

        expect(result.rows.map((r) => r.date).toList(), [
          DateTime(2024, 2, 13),
          DateTime(2024, 3, 5),
          DateTime(2024, 3, 5),
        ]);
        expect(result.errors, hasLength(1));
        expect(result.errors.single, startsWith('Row 4:'));
        expect(result.dateOrderQuestion, isNull);
      });

      test('a US file is read month-first from its first row', () {
        final result = parseDates([
          '01/02/2024',
          '02/10/2024',
          '01/15/2024',
          '03/04/2024',
        ]);

        expect(result.errors, isEmpty);
        expect(result.rows.map((r) => r.date).toList(), [
          DateTime(2024, 1, 2),
          DateTime(2024, 2, 10),
          DateTime(2024, 1, 15),
          DateTime(2024, 3, 4),
        ]);
        expect(result.dateOrderQuestion, isNull);
      });

      test('a file whose dates fit both orders asks which one it uses', () {
        const dates = ['05/03/2024', '04/02/2024'];

        final question = parseDates(dates).dateOrderQuestion;
        expect(question, isNotNull);
        expect(question!.sample, '05/03/2024');
        expect(question.dayFirst, DateTime(2024, 3, 5));
        expect(question.monthFirst, DateTime(2024, 5, 3));

        final dayFirst = parseDates(dates, order: CsvDateOrder.dayFirst);
        expect(dayFirst.dateOrderQuestion, isNull);
        expect(dayFirst.rows.map((r) => r.date).toList(), [
          DateTime(2024, 3, 5),
          DateTime(2024, 2, 4),
        ]);

        final monthFirst = parseDates(dates, order: CsvDateOrder.monthFirst);
        expect(monthFirst.dateOrderQuestion, isNull);
        expect(monthFirst.rows.map((r) => r.date).toList(), [
          DateTime(2024, 5, 3),
          DateTime(2024, 4, 2),
        ]);
      });

      test('ISO dates never raise the question', () {
        final result = parseDates(['2024-03-05', '2024-02-04']);

        expect(result.dateOrderQuestion, isNull);
        expect(result.rows.map((r) => r.date).toList(), [
          DateTime(2024, 3, 5),
          DateTime(2024, 2, 4),
        ]);
      });

      test('a year before 1950 is an error row', () {
        final result = parseDates(['01/01/1949', '01/01/1950']);

        expect(result.rows.map((r) => r.date).toList(), [DateTime(1950, 1, 1)]);
        expect(result.errors, hasLength(1));
        expect(result.errors.single, startsWith('Row 2:'));
      });

      test('a date far in the future is an error row', () {
        final result = parseDates(['2999-01-01']);

        expect(result.validRows, 0);
        expect(result.errors.single, startsWith('Row 2:'));
      });
    });

    group('Amounts are read with one decimal mark per file (A25)', () {
      List<double> amounts(String csv, {bool? decimalComma}) =>
          SimpleCsvParser.parseString(
            csv,
            decimalComma: decimalComma,
          ).rows.map((r) => r.amount).toList();

      test('decimal-comma mode reads 1.234,56 as 1234.56', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,Test,invest,"1.234,56"''';

        expect(amounts(csv, decimalComma: true), [1234.56]);
      });

      test('by default commas group thousands and lakhs', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,T1,invest,"1,234.56"
2024-01-01,T2,invest,"₹1,23,456.78"''';

        expect(amounts(csv), [1234.56, 123456.78]);
      });

      test('a file whose amounts use a decimal comma is read that way', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,T1,invest,"1.234,56"
2024-01-01,T2,invest,"12,50"''';

        expect(amounts(csv), [1234.56, 12.5]);
      });

      test('an amount that fits neither mark is an error, never 1.23456', () {
        const csv = '''Date,Investment Name,Type,Amount
2024-01-01,T1,invest,"1,234.56"
2024-01-01,T2,invest,"1.234,56"''';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.rows.map((r) => r.amount).toList(), [1234.56]);
        expect(result.errors.single, 'Row 3: Invalid amount: 1.234,56');
      });
    });

    group('Investment Type values (A25)', () {
      InvestmentType? typeOf(String value) => SimpleCsvParser.parseString(
        'Date,Investment Name,Type,Amount,Investment Type\n'
        '2024-01-01,Test,INVEST,1000,$value',
      ).rows.single.investmentType;

      test('common names map to the right type', () {
        expect(typeOf('p2p'), InvestmentType.p2pLending);
        expect(typeOf('P2P Lending'), InvestmentType.p2pLending);
        expect(typeOf('p2pLending'), InvestmentType.p2pLending);
        expect(typeOf('mutualFund'), InvestmentType.mutualFunds);
        expect(typeOf('mf'), InvestmentType.mutualFunds);
        expect(typeOf('fd'), InvestmentType.fixedDeposit);
        expect(typeOf('Fixed Deposit'), InvestmentType.fixedDeposit);
        expect(typeOf('something else'), InvestmentType.other);
      });

      test('no template row is read as Other', () {
        final result = SimpleCsvParser.parseString(
          CsvTemplateService.generateTemplateContent(),
          baseCurrency: 'INR',
        );

        expect(result.errors, isEmpty);
        expect(
          result.rows.map((r) => r.investmentType).toList(),
          everyElement(isNot(anyOf(isNull, InvestmentType.other))),
        );
        expect(
          result.rows
              .where((r) => r.investmentName == 'Bhive Investment')
              .map((r) => r.investmentType)
              .toSet(),
          {InvestmentType.p2pLending},
        );
      });
    });

    group('Records (A25)', () {
      test('a quoted note with a line break stays one row', () {
        const csv =
            'Date,Investment Name,Type,Amount,Notes\n'
            '2024-01-15,Test,INVEST,1000,"x\ny"';

        final result = SimpleCsvParser.parseString(csv);

        expect(result.errors, isEmpty);
        expect(result.rows, hasLength(1));
        expect(result.rows.single.notes, 'x\ny');
        expect(result.rows.single.amount, 1000);
      });
    });

    group('Currency codes (A14)', () {
      test('an unknown code is a row error', () {
        const csv = '''Date,Investment Name,Type,Amount,Currency
2024-01-01,T1,INVEST,1000,XYZ
2024-01-02,T2,INVEST,1000,INR''';

        final result = SimpleCsvParser.parseString(csv, baseCurrency: 'INR');

        expect(result.rows.map((r) => r.investmentName).toList(), ['T2']);
        expect(result.errors, ['Row 2: Invalid currency code: XYZ']);
      });

      test('a lower-case code is read in upper case', () {
        const csv = '''Date,Investment Name,Type,Amount,Currency
2024-01-01,Dubai FD,INVEST,1000,aed''';

        final result = SimpleCsvParser.parseString(csv, baseCurrency: 'INR');

        expect(result.errors, isEmpty);
        expect(result.rows.single.currency, 'AED');
      });
    });

    // ============ A106: the guide's sample matches the template ============
    group('docs/BULK_IMPORT_GUIDE.md sample (A106)', () {
      String guideSample() {
        final guide = File('docs/BULK_IMPORT_GUIDE.md').readAsStringSync();
        final match = RegExp(r'```csv\n([\s\S]*?)\n```').firstMatch(guide);
        expect(match, isNotNull, reason: 'the guide has a ```csv block');
        return match!.group(1)!;
      }

      test('uses the same columns as the in-app template', () {
        expect(
          guideSample().split('\n').first,
          CsvTemplateService.headers.join(','),
        );
      });

      test('parses without errors and keeps the USD row in USD', () {
        final result = SimpleCsvParser.parseString(
          guideSample(),
          baseCurrency: 'INR',
        );

        expect(result.errors, isEmpty);
        expect(result.dateOrderQuestion, isNull);
        expect(result.decimalMarkUnclear, isFalse);
        final usd = result.rows.where((r) => r.currency == 'USD').toList();
        expect(usd, isNotEmpty);
        expect(usd.first.amount, 1000.50);
        expect(
          result.rows.where((r) => r.currency != 'USD').map((r) => r.currency),
          everyElement('INR'),
        );
      });
    });
  });
}
