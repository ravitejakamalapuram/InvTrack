import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/error/app_exception.dart';

// Create a mock GoogleSignInException that mimics the real one's structure
class MockGoogleSignInException implements Exception {
  final Object code;
  MockGoogleSignInException(this.code);

  // ErrorHandler uses runtimeType.toString(), so we need to override it
  // This is tricky in Dart, so we test the structure we can
}

void main() {
  group('ErrorHandler Platform Exceptions', () {
    test('maps PlatformException sign_in_canceled to AuthException.signInCancelled', () {
      final error = PlatformException(code: 'sign_in_canceled');
      final result = ErrorHandler.mapException(error);

      expect(result, isA<AuthException>());
      expect((result as AuthException).code, AuthExceptionCode.cancelled);
      expect(result.shouldReport, false);
    });

    test('maps other PlatformExceptions to AuthException.signInFailed', () {
      final error = PlatformException(code: 'some_other_error', message: 'test');
      final result = ErrorHandler.mapException(error);

      expect(result, isA<AuthException>());
      expect((result as AuthException).code, AuthExceptionCode.signInFailed);
      expect(result.cause, error);
    });
  });
}
