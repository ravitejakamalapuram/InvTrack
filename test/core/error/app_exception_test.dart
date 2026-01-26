import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/error/app_exception.dart';

void main() {
  group('NetworkException', () {
    test('has correct default user message', () {
      final exception = NetworkException(technicalMessage: 'Test error');
      expect(
        exception.userMessage,
        'Unable to connect. Please check your internet connection.',
      );
    });

    test('has custom user message when provided', () {
      final exception = NetworkException(
        userMessage: 'Custom message',
        technicalMessage: 'Test error',
      );
      expect(exception.userMessage, 'Custom message');
    });

    test('timeout factory creates correct message', () {
      final exception = NetworkException.timeout();
      expect(exception.userMessage, contains('timed out'));
      expect(exception.shouldReport, false);
    });

    test('noConnection factory creates correct message', () {
      final exception = NetworkException.noConnection();
      expect(exception.userMessage, contains('No internet'));
      expect(exception.shouldReport, false);
    });

    test('toString includes runtime type and technical message', () {
      final exception = NetworkException(technicalMessage: 'Test error');
      expect(exception.toString(), contains('NetworkException'));
      expect(exception.toString(), contains('Test error'));
    });

    test('stores cause and stackTrace', () {
      final cause = Exception('Original error');
      final stackTrace = StackTrace.current;
      final exception = NetworkException(
        technicalMessage: 'Test',
        cause: cause,
        stackTrace: stackTrace,
      );
      expect(exception.cause, cause);
      expect(exception.stackTrace, stackTrace);
    });
  });

  group('AuthException', () {
    test('has correct default user message', () {
      final exception = AuthException(technicalMessage: 'Test');
      expect(exception.userMessage, contains('Authentication failed'));
    });

    test('signInCancelled factory creates correct message', () {
      final exception = AuthException.signInCancelled();
      expect(exception.userMessage, contains('cancelled'));
      expect(exception.shouldReport, false);
    });

    test('signInFailed factory creates correct message', () {
      final exception = AuthException.signInFailed();
      expect(exception.userMessage, contains('Sign in failed'));
    });

    test('notAuthenticated factory creates correct message', () {
      final exception = AuthException.notAuthenticated();
      expect(exception.userMessage, contains('sign in'));
      expect(exception.shouldReport, false);
    });
  });

  group('DataException', () {
    test('has correct default user message', () {
      final exception = DataException(technicalMessage: 'Test');
      expect(exception.userMessage, contains('error occurred'));
    });

    test('notFound factory creates correct message', () {
      final exception = DataException.notFound('Investment', '123');
      expect(exception.userMessage, 'Investment not found.');
      expect(exception.technicalMessage, contains('123'));
      expect(exception.shouldReport, false);
    });

    test('saveFailed factory creates correct message', () {
      final exception = DataException.saveFailed(
        operation: 'create investment',
      );
      expect(exception.userMessage, contains('Failed to save'));
    });

    test('deleteFailed factory creates correct message', () {
      final exception = DataException.deleteFailed();
      expect(exception.userMessage, contains('Failed to delete'));
    });
  });

  group('ValidationException', () {
    test('shouldReport is always false', () {
      final exception = ValidationException(
        userMessage: 'Test',
        technicalMessage: 'Test',
      );
      expect(exception.shouldReport, false);
    });

    test('emptyField factory creates correct message', () {
      final exception = ValidationException.emptyField('Name');
      expect(exception.userMessage, 'Name cannot be empty.');
    });

    test('invalidAmount factory creates correct message', () {
      final exception = ValidationException.invalidAmount(-100);
      expect(exception.userMessage, contains('greater than zero'));
    });

    test('invalidDate factory creates correct message', () {
      final exception = ValidationException.invalidDate(DateTime(2099, 1, 1));
      expect(exception.userMessage, contains('future'));
    });

    test('tooLong factory creates correct message', () {
      final exception = ValidationException.tooLong('Description', 500);
      expect(exception.userMessage, contains('too long'));
      expect(exception.userMessage, contains('500'));
    });
  });
}
