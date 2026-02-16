import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/security_utils.dart';

void main() {
  group('SecurityUtils - constantTimeEquals', () {
    test('returns true for identical strings', () {
      const a = 'abc12345';
      const b = 'abc12345';
      expect(SecurityUtils.constantTimeEquals(a, b), isTrue);
    });

    test('returns false for different strings of same length', () {
      const a = 'abc12345';
      const b = 'abc12346';
      expect(SecurityUtils.constantTimeEquals(a, b), isFalse);
    });

    test('returns false for strings of different length', () {
      const a = 'abc12345';
      const b = 'abc1234';
      expect(SecurityUtils.constantTimeEquals(a, b), isFalse);
    });

    test('returns true for empty strings', () {
      expect(SecurityUtils.constantTimeEquals('', ''), isTrue);
    });

    test('returns false when one string is empty', () {
      expect(SecurityUtils.constantTimeEquals('a', ''), isFalse);
    });

    test('handles special characters', () {
      const a = '!@#\$%^&*()';
      const b = '!@#\$%^&*()';
      expect(SecurityUtils.constantTimeEquals(a, b), isTrue);
    });

    test('handles unicode characters', () {
      const a = '👍';
      const b = '👍';
      expect(SecurityUtils.constantTimeEquals(a, b), isTrue);
    });

    test('handles unicode characters mismatch', () {
      const a = '👍';
      const b = '👎';
      expect(SecurityUtils.constantTimeEquals(a, b), isFalse);
    });
  });
}
