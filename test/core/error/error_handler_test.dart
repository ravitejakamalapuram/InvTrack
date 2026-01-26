import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/error/error_handler.dart';

void main() {
  group('ErrorHandler', () {
    group('mapException', () {
      test('returns same exception if already AppException', () {
        final original = NetworkException(technicalMessage: 'Test');
        final result = ErrorHandler.mapException(original);

        expect(result, same(original));
      });

      test('maps TimeoutException to NetworkException.timeout', () {
        final timeout = TimeoutException('Timed out');
        final result = ErrorHandler.mapException(timeout);

        expect(result, isA<NetworkException>());
        expect(result.userMessage, contains('timed out'));
      });

      test('maps unknown errors to DataException', () {
        final error = Exception('Unknown error');
        final result = ErrorHandler.mapException(error);

        expect(result, isA<DataException>());
        expect(result.userMessage, contains('unexpected error'));
      });

      test('preserves stack trace', () {
        final error = Exception('Test');
        final stackTrace = StackTrace.current;
        final result = ErrorHandler.mapException(error, stackTrace);

        expect(result.stackTrace, stackTrace);
      });

      test('preserves cause', () {
        final error = Exception('Test');
        final result = ErrorHandler.mapException(error);

        expect(result.cause, error);
      });
    });

    group('handle', () {
      test('returns mapped exception', () {
        final error = TimeoutException('Test');
        final result = ErrorHandler.handle(error, null, showFeedback: false);

        expect(result, isA<NetworkException>());
      });

      test('logs error in debug mode', () {
        final error = Exception('Test error');
        // This should not throw
        expect(
          () => ErrorHandler.handle(error, null, showFeedback: false),
          returnsNormally,
        );
      });
    });

    group('logError', () {
      test('does not throw', () {
        final exception = DataException(technicalMessage: 'Test');

        expect(() => ErrorHandler.logError(exception), returnsNormally);
      });

      test('handles exception with null cause and stackTrace', () {
        final exception = ValidationException.emptyField('Name');

        expect(() => ErrorHandler.logError(exception), returnsNormally);
      });

      test('handles exception with cause and stackTrace', () {
        final exception = NetworkException(
          technicalMessage: 'Test',
          cause: Exception('Cause'),
          stackTrace: StackTrace.current,
        );

        expect(() => ErrorHandler.logError(exception), returnsNormally);
      });
    });
  });
}
