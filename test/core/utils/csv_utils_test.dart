import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/csv_utils.dart';

void main() {
  group('CsvUtils', () {
    test('sanitizeField returns value as-is for safe strings', () {
      expect(CsvUtils.sanitizeField('Safe String'), 'Safe String');
      expect(CsvUtils.sanitizeField('12345'), '12345');
      expect(CsvUtils.sanitizeField('A name'), 'A name');
    });

    test('sanitizeField returns value as-is for non-string types', () {
      expect(CsvUtils.sanitizeField(123), 123);
      expect(CsvUtils.sanitizeField(45.67), 45.67);
      expect(CsvUtils.sanitizeField(true), true);
      expect(CsvUtils.sanitizeField(null), null);
    });

    test('sanitizeField prepends quote for dangerous start characters', () {
      expect(CsvUtils.sanitizeField('=Formula'), "'=Formula");
      expect(CsvUtils.sanitizeField('+Formula'), "'+Formula");
      expect(CsvUtils.sanitizeField('-Formula'), "'-Formula");
      expect(CsvUtils.sanitizeField('@Formula'), "'@Formula");
      expect(CsvUtils.sanitizeField('\tDangerous'), "'\tDangerous");
      expect(CsvUtils.sanitizeField('\rDangerous'), "'\rDangerous");
    });

    test('sanitizeField does not prepend quote if dangerous char is not at start', () {
      expect(CsvUtils.sanitizeField('Safe = Not at start'), 'Safe = Not at start');
      expect(CsvUtils.sanitizeField('Value+More'), 'Value+More');
    });

    test('sanitizeField handles empty strings', () {
      expect(CsvUtils.sanitizeField(''), '');
    });
  });
}
