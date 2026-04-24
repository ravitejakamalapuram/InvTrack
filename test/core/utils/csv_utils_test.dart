import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/csv_utils.dart';

void main() {
  group('CsvUtils', () {
    test('sanitizeField should return non-string values as is', () {
      expect(CsvUtils.sanitizeField(123), 123);
      expect(CsvUtils.sanitizeField(12.34), 12.34);
      expect(CsvUtils.sanitizeField(true), true);
      expect(CsvUtils.sanitizeField(null), null);
    });

    test('sanitizeField should return safe strings as is', () {
      expect(CsvUtils.sanitizeField('Hello'), 'Hello');
      expect(CsvUtils.sanitizeField('123'), '123');
      expect(CsvUtils.sanitizeField('Just text'), 'Just text');
    });

    test('sanitizeField should sanitize dangerous starting characters', () {
      expect(CsvUtils.sanitizeField('=SUM(A1:B1)'), "'=SUM(A1:B1)");
      expect(CsvUtils.sanitizeField('+SUM(A1:B1)'), "'+SUM(A1:B1)");
      expect(CsvUtils.sanitizeField('-SUM(A1:B1)'), "'-SUM(A1:B1)");
      expect(CsvUtils.sanitizeField('@SUM(A1:B1)'), "'@SUM(A1:B1)");
      expect(CsvUtils.sanitizeField('\tTab'), "'\tTab");
      expect(CsvUtils.sanitizeField('\rCR'), "'\rCR");
    });

    test('sanitizeField should sanitize when spaces precede dangerous characters', () {
      expect(CsvUtils.sanitizeField(' =SUM(A1:B1)'), "' =SUM(A1:B1)");
      expect(CsvUtils.sanitizeField('   +SUM(A1:B1)'), "'   +SUM(A1:B1)");
      expect(CsvUtils.sanitizeField('\n-SUM(A1:B1)'), "'\n-SUM(A1:B1)");
    });

    test(
      'sanitizeField should not sanitize if dangerous char is not at start',
      () {
        expect(CsvUtils.sanitizeField('User = Bad'), 'User = Bad');
        expect(CsvUtils.sanitizeField('Price + Tax'), 'Price + Tax');
        expect(
          CsvUtils.sanitizeField('Email@example.com'),
          'Email@example.com',
        );
      },
    );
  });
}
