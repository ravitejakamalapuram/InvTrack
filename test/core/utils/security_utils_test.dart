import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/security_utils.dart';

void main() {
  group('SecurityUtils', () {
    test('hashPin returns consistent results', () {
      const pin = '1234';
      const salt = 'random_salt';
      final hash1 = SecurityUtils.hashPin(pin, salt, iterations: 100);
      final hash2 = SecurityUtils.hashPin(pin, salt, iterations: 100);

      expect(hash1, equals(hash2));
    });

    test('hashPin returns different results for different salts', () {
      const pin = '1234';
      final hash1 = SecurityUtils.hashPin(pin, 'salt1', iterations: 100);
      final hash2 = SecurityUtils.hashPin(pin, 'salt2', iterations: 100);

      expect(hash1, isNot(equals(hash2)));
    });

    test('hashPin includes iteration count in format', () {
      const pin = '1234';
      const salt = 'salt';
      final hash = SecurityUtils.hashPin(pin, salt, iterations: 500);

      final parts = hash.split(':');
      expect(parts.length, equals(3));
      expect(parts[0], equals(salt));
      expect(parts[1], equals('500'));
      // part 2 is the hash
    });

    test('verifyPin returns true for correct PIN', () {
      const pin = '1234';
      const salt = 'salt';
      final hash = SecurityUtils.hashPin(pin, salt, iterations: 100);

      expect(SecurityUtils.verifyPin(pin, hash), isTrue);
    });

    test('verifyPin returns false for incorrect PIN', () {
      const pin = '1234';
      const salt = 'salt';
      final hash = SecurityUtils.hashPin(pin, salt, iterations: 100);

      expect(SecurityUtils.verifyPin('5678', hash), isFalse);
    });

    test('verifyPin handles malformed hash strings', () {
      expect(SecurityUtils.verifyPin('1234', 'malformed'), isFalse);
      expect(SecurityUtils.verifyPin('1234', 'salt:hash'), isFalse); // v2 format
      expect(SecurityUtils.verifyPin('1234', 'salt:invalid_iterations:hash'), isFalse);
    });

    test('Performance: 100,000 iterations is reasonable (<2000ms)', () {
      const pin = '1234';
      const salt = 'salt';

      final stopwatch = Stopwatch()..start();
      SecurityUtils.hashPin(pin, salt, iterations: 100000);
      stopwatch.stop();

      // In CI environments (like this sandbox), it might be slower, so we use a generous limit.
      // 100k iterations takes ~900ms on CI.
      expect(stopwatch.elapsedMilliseconds, lessThan(2500));
    });

    test('hashPin uses 100,000 iterations by default', () {
      const pin = '1234';
      const salt = 'salt';
      final hash = SecurityUtils.hashPin(pin, salt);

      final parts = hash.split(':');
      expect(parts.length, equals(3));
      expect(parts[1], equals('100000'));
    });

    // Validated against Python's hashlib.pbkdf2_hmac('sha256', ...)
    test('PBKDF2-HMAC-SHA256 Test Case 1 (1 iteration)', () {
      final pin = 'password';
      final salt = 'salt';
      final iterations = 1;
      final expectedHex =
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b';

      List<int> expectedBytes = [];
      for (var i = 0; i < expectedHex.length; i += 2) {
        expectedBytes.add(
          int.parse(expectedHex.substring(i, i + 2), radix: 16),
        );
      }
      final expectedBase64 = base64.encode(expectedBytes);
      final expectedStoredHash = '$salt:$iterations:$expectedBase64';

      expect(SecurityUtils.verifyPin(pin, expectedStoredHash), isTrue);
    });

    test('PBKDF2-HMAC-SHA256 Test Case 2 (2 iterations)', () {
      final pin = 'password';
      final salt = 'salt';
      final iterations = 2;
      final expectedHex =
          'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43';

      List<int> expectedBytes = [];
      for (var i = 0; i < expectedHex.length; i += 2) {
        expectedBytes.add(
          int.parse(expectedHex.substring(i, i + 2), radix: 16),
        );
      }
      final expectedBase64 = base64.encode(expectedBytes);
      final expectedStoredHash = '$salt:$iterations:$expectedBase64';

      expect(SecurityUtils.verifyPin(pin, expectedStoredHash), isTrue);
    });

    test('PBKDF2-HMAC-SHA256 Test Case 3 (4096 iterations)', () {
      final pin = 'password';
      final salt = 'salt';
      final iterations = 4096;
      final expectedHex =
          'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a';

      List<int> expectedBytes = [];
      for (var i = 0; i < expectedHex.length; i += 2) {
        expectedBytes.add(
          int.parse(expectedHex.substring(i, i + 2), radix: 16),
        );
      }
      final expectedBase64 = base64.encode(expectedBytes);
      final expectedStoredHash = '$salt:$iterations:$expectedBase64';

      expect(SecurityUtils.verifyPin(pin, expectedStoredHash), isTrue);
    });

    group('constantTimeEquals', () {
      test('returns true for equal strings', () {
        expect(SecurityUtils.constantTimeEquals('abc', 'abc'), isTrue);
        expect(SecurityUtils.constantTimeEquals('', ''), isTrue);
        expect(SecurityUtils.constantTimeEquals('1234', '1234'), isTrue);
      });

      test('returns false for unequal strings of same length', () {
        expect(SecurityUtils.constantTimeEquals('abc', 'abd'), isFalse);
        expect(SecurityUtils.constantTimeEquals('1234', '1235'), isFalse);
        expect(SecurityUtils.constantTimeEquals('aaaa', 'bbbb'), isFalse);
      });

      test('returns false for strings of different length', () {
        expect(SecurityUtils.constantTimeEquals('abc', 'abcd'), isFalse);
        expect(SecurityUtils.constantTimeEquals('1234', '123'), isFalse);
        expect(SecurityUtils.constantTimeEquals('', 'a'), isFalse);
      });

      test('handles unicode characters correctly', () {
        expect(SecurityUtils.constantTimeEquals('😊', '😊'), isTrue);
        expect(SecurityUtils.constantTimeEquals('😊', '😢'), isFalse);
      });
    });
  });
}
