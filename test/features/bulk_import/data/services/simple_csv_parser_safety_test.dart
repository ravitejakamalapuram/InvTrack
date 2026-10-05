import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';

/// A25 review: no amount is read as a different number without asking, no
/// row disappears behind a stray quote, and a backup restores what the app
/// itself exported.
void main() {
  const header = 'Date,Investment Name,Type,Amount';

  ParsedCsvResult parseAmounts(List<String> amounts, {bool? decimalComma}) =>
      SimpleCsvParser.parseString(
        [
          header,
          for (final (i, a) in amounts.indexed)
            '2024-01-0${i + 1},A,INVEST,"$a"',
        ].join('\n'),
        baseCurrency: 'INR',
        decimalComma: decimalComma,
      );

  List<double> amountsOf(ParsedCsvResult r) =>
      r.rows.map((row) => row.amount).toList();

  group('decimal mark', () {
    test('one comma-only cell does not re-read grouped thousands', () {
      final result = parseAmounts(['1,500', '2,000', '10,000', '50,00']);

      expect(amountsOf(result), [1500, 2000, 10000]);
      expect(result.errors, ['Row 5: Invalid amount: 50,00']);
      expect(result.decimalMarkUnclear, isTrue);
    });

    test('the user can say the same file uses a decimal comma', () {
      final result = parseAmounts([
        '1,500',
        '2,000',
        '10,000',
        '50,00',
      ], decimalComma: true);

      expect(amountsOf(result), [1.5, 2.0, 10.0, 50.0]);
      expect(result.errors, isEmpty);
      expect(result.decimalMarkUnclear, isFalse);
    });

    test('a file whose every amount reads two ways asks', () {
      final result = parseAmounts(['1.500', '25.000']);

      expect(result.decimalMarkUnclear, isTrue);
      expect(amountsOf(parseAmounts(['1.500', '25.000'], decimalComma: true)), [
        1500,
        25000,
      ]);
    });

    test('lakh grouping settles a file of thousands without asking', () {
      final result = parseAmounts(['50,000', '1,00,000', '25,000']);

      expect(amountsOf(result), [50000, 100000, 25000]);
      expect(result.errors, isEmpty);
      expect(result.decimalMarkUnclear, isFalse);
    });

    test('decimal-comma amounts that read only one way need no question', () {
      final result = parseAmounts(['1.234,56', '12,50']);

      expect(amountsOf(result), [1234.56, 12.5]);
      expect(result.decimalMarkUnclear, isFalse);
    });

    test('.5 and 5. are read as 0.5 and 5', () {
      final result = parseAmounts(['.5', '5.']);

      expect(amountsOf(result), [0.5, 5.0]);
      expect(result.errors, isEmpty);
    });
  });

  group('amounts must be more than zero', () {
    test('negative and zero amounts are row errors', () {
      final result = parseAmounts(['-5000', '(5000)', '0', '5000']);

      expect(amountsOf(result), [5000]);
      expect(result.errors, [
        'Row 2: Amount must be more than zero (Type sets the direction): -5000',
        'Row 3: Amount must be more than zero (Type sets the direction): (5000)',
        'Row 4: Amount must be more than zero (Type sets the direction): 0',
      ]);
    });
  });

  group('dates with a time of day', () {
    test('day/month dates keep only their date part', () {
      final result = SimpleCsvParser.parseString(
        '$header\n'
        '15/01/2024 10:30:00,A,INVEST,100\n'
        '16/01/2024 09:00,A,INVEST,100\n'
        '15-01-24 10:30,A,INVEST,100',
        baseCurrency: 'INR',
      );

      expect(result.errors, isEmpty);
      expect(result.rows.map((r) => r.date).toList(), [
        DateTime(2024, 1, 15),
        DateTime(2024, 1, 16),
        DateTime(2024, 1, 15),
      ]);
    });
  });

  group('quotes', () {
    const notesHeader = 'Date,Investment Name,Type,Amount,Notes';

    test('a stray quote does not swallow the rows after it', () {
      final result = SimpleCsvParser.parseString(
        '$notesHeader\n'
        '2024-01-02,A,INVEST,200,"Best" FD\n'
        '2024-01-03,B,INVEST,300,\n'
        '2024-01-04,C,INVEST,400,"Top pick\n'
        '2024-01-05,D,INVEST,500,\n'
        '2024-01-06,E,INVEST,600,',
        baseCurrency: 'INR',
      );

      expect(result.rows.map((r) => r.investmentName).toList(), [
        'A',
        'B',
        'D',
        'E',
      ]);
      expect(result.rows.first.notes, 'Best FD');
      expect(result.errors, ['Row 4: Unmatched quote']);
      expect(result.totalRows, 5);
    });

    test('a quote closed later in the file still leaves every row seen', () {
      final result = SimpleCsvParser.parseString(
        '$notesHeader\n'
        '2024-01-02,A,INVEST,200,"Gold coins\n'
        '2024-01-03,B,INVEST,300,\n'
        '2024-01-04,C,INVEST,400,"x"',
        baseCurrency: 'INR',
      );

      expect(result.rows.map((r) => r.investmentName).toList(), ['B', 'C']);
      expect(result.rows.last.notes, 'x');
      expect(result.errors, ['Row 2: Unmatched quote']);
    });

    test('a quoted word at the start of a note stays in that row', () {
      final result = SimpleCsvParser.parseString(
        '$notesHeader\n'
        '2024-01-02,A,INVEST,200,"Gold" coins\n'
        '2024-01-03,B,INVEST,300,\n'
        '2024-01-04,C,INVEST,400,\n'
        '2024-01-05,D,INVEST,500,',
        baseCurrency: 'INR',
      );

      expect(result.errors, isEmpty);
      expect(result.validRows, 4);
      expect(result.rows.first.notes, 'Gold coins');
    });

    test('a space after the comma before a quoted cell is ignored', () {
      final result = SimpleCsvParser.parseString(
        '$header\n2024-01-01, A, invest, "1,234.56"',
        baseCurrency: 'INR',
      );

      expect(result.errors, isEmpty);
      expect(result.rows.single.investmentName, 'A');
      expect(result.rows.single.amount, 1234.56);
    });

    test('a note written over two lines is still one row', () {
      final result = SimpleCsvParser.parseString(
        '$notesHeader\n'
        '2024-01-02,A,INVEST,200,"line one\n'
        'line two"\n'
        '2024-01-03,B,INVEST,300,',
        baseCurrency: 'INR',
      );

      expect(result.errors, isEmpty);
      expect(result.rows.map((r) => r.investmentName).toList(), ['A', 'B']);
      expect(result.rows.first.notes, 'line one\nline two');
    });
  });

  group('backups restore what the app exported', () {
    const exportHeader =
        'Date,Investment Name,Type,Amount,Currency,Notes,Investment Type,'
        'Investment Status';

    test('keeps old dates, stored currency codes and stored amounts', () {
      final result = SimpleCsvParser.parseString(
        '$exportHeader\n'
        '0024-03-05,Old FD,INVEST,5000.0,RS,,fixedDeposit,open\n'
        '2024-01-15,Old FD,INVEST,1.5,US\$,,fixedDeposit,open\n'
        '2024-02-15,Old FD,INCOME,-20.0,INR,,fixedDeposit,open\n'
        '2024-03-15,Old FD,INCOME,1.500,INR,,fixedDeposit,open',
        baseCurrency: 'INR',
        fromBackup: true,
      );

      expect(result.errors, isEmpty);
      expect(result.decimalMarkUnclear, isFalse);
      expect(result.rows.map((r) => r.date).toList(), [
        DateTime(24, 3, 5),
        DateTime(2024, 1, 15),
        DateTime(2024, 2, 15),
        DateTime(2024, 3, 15),
      ]);
      expect(result.rows.map((r) => r.currency).toList(), [
        'RS',
        r'US$',
        'INR',
        'INR',
      ]);
      expect(amountsOf(result), [5000, 1.5, -20, 1.5]);
    });

    test('a bulk import still rejects the same rows', () {
      final result = SimpleCsvParser.parseString(
        '$exportHeader\n'
        '0024-03-05,Old FD,INVEST,5000.0,INR,,fixedDeposit,open\n'
        '2024-01-15,Old FD,INVEST,1.5,RS,,fixedDeposit,open',
        baseCurrency: 'INR',
      );

      expect(result.validRows, 0);
      expect(result.errors, hasLength(2));
    });
  });
}
