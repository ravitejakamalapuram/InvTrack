import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/bulk_import/data/services/csv_template_service.dart';
import 'package:inv_tracker/features/bulk_import/data/services/simple_csv_parser.dart';

void main() {
  group('CsvTemplateService', () {
    group('headers', () {
      test('contains all required columns', () {
        expect(CsvTemplateService.headers, contains('Date'));
        expect(CsvTemplateService.headers, contains('Investment Name'));
        expect(CsvTemplateService.headers, contains('Type'));
        expect(CsvTemplateService.headers, contains('Amount'));
        expect(CsvTemplateService.headers, contains('Notes'));
      });

      test('contains optional columns for investment metadata', () {
        expect(CsvTemplateService.headers, contains('Investment Type'));
        expect(CsvTemplateService.headers, contains('Investment Status'));
      });

      test('has exactly 7 headers', () {
        expect(CsvTemplateService.headers.length, 7);
      });
    });

    group('sampleRows', () {
      test('contains sample data rows', () {
        expect(CsvTemplateService.sampleRows.isNotEmpty, true);
        expect(CsvTemplateService.sampleRows.length, greaterThan(5));
      });

      test('each row has correct number of columns', () {
        for (final row in CsvTemplateService.sampleRows) {
          expect(row.length, CsvTemplateService.headers.length);
        }
      });

      test('includes various transaction types', () {
        final types = CsvTemplateService.sampleRows.map((r) => r[2]).toSet();
        expect(types, contains('INVEST'));
        expect(types, contains('INCOME'));
        expect(types, contains('RETURN'));
      });

      test('includes multiple investments', () {
        final names = CsvTemplateService.sampleRows.map((r) => r[1]).toSet();
        expect(names.length, greaterThan(2));
      });
    });

    group('generateTemplateContent', () {
      test('generates valid CSV content', () {
        final content = CsvTemplateService.generateTemplateContent();

        expect(content.isNotEmpty, true);
        expect(content, contains('Date'));
        expect(content, contains('Investment Name'));
        expect(content, contains('Type'));
        expect(content, contains('Amount'));
      });

      test('header row is first line', () {
        final content = CsvTemplateService.generateTemplateContent();
        final lines = content.split('\n');

        expect(lines.first, CsvTemplateService.headers.join(','));
      });

      test('contains sample data after header', () {
        final content = CsvTemplateService.generateTemplateContent();
        final lines = content.split('\n').where((l) => l.isNotEmpty).toList();

        // Header + at least some data rows
        expect(lines.length, greaterThan(1));
      });

      test('generated content is parseable by SimpleCsvParser', () {
        final content = CsvTemplateService.generateTemplateContent();
        final result = SimpleCsvParser.parseString(content);

        expect(result.hasErrors, false);
        expect(result.validRows, CsvTemplateService.sampleRows.length);
      });
    });

    group('getTemplateBytes', () {
      test('returns valid UTF-8 bytes', () {
        final bytes = CsvTemplateService.getTemplateBytes();

        expect(bytes.isNotEmpty, true);

        // Should be valid UTF-8
        final content = utf8.decode(bytes);
        expect(content, contains('Date'));
      });

      test('bytes match generated content', () {
        final bytes = CsvTemplateService.getTemplateBytes();
        final content = CsvTemplateService.generateTemplateContent();

        expect(utf8.decode(bytes), content);
      });
    });

    group('CSV escaping', () {
      test('sample rows with commas are properly escaped', () {
        final content = CsvTemplateService.generateTemplateContent();

        // Parse it to verify escaping works
        final result = SimpleCsvParser.parseString(content);
        expect(result.hasErrors, false);
      });

      test('generated CSV maintains data integrity after round-trip', () {
        final content = CsvTemplateService.generateTemplateContent();
        final result = SimpleCsvParser.parseString(content);

        // Check first row matches expected
        final firstRow = result.rows.first;
        expect(firstRow.investmentName, CsvTemplateService.sampleRows[0][1]);
        expect(firstRow.amount, double.parse(CsvTemplateService.sampleRows[0][3]));
      });
    });

    group('typeDescription', () {
      test('contains documentation for all types', () {
        const desc = CsvTemplateService.typeDescription;

        expect(desc, contains('INVEST'));
        expect(desc, contains('INCOME'));
        expect(desc, contains('RETURN'));
        expect(desc, contains('FEE'));
      });

      test('explains inflow vs outflow', () {
        const desc = CsvTemplateService.typeDescription;

        expect(desc, contains('outflow'));
        expect(desc, contains('inflow'));
      });

      test('documents optional investment type and status columns', () {
        const desc = CsvTemplateService.typeDescription;

        expect(desc, contains('Investment Type'));
        expect(desc, contains('Investment Status'));
        expect(desc, contains('optional'));
        expect(desc, contains('p2p'));
        expect(desc, contains('open'));
        expect(desc, contains('closed'));
      });
    });
  });
}
