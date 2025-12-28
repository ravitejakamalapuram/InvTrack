/// Base exception class for all app-specific exceptions.
/// Provides user-friendly messages and technical details for logging.
abstract class AppException implements Exception {
  /// User-friendly message suitable for display in UI
  String get userMessage;

  /// Technical message for logging/debugging
  String get technicalMessage;

  /// Whether this error should be reported to error tracking service
  bool get shouldReport => true;

  /// Original error that caused this exception (if any)
  Object? get cause;

  /// Stack trace from the original error
  StackTrace? get stackTrace;

  @override
  String toString() => '$runtimeType: $technicalMessage';
}

/// Network-related errors (connectivity, timeouts, server errors)
class NetworkException extends AppException {
  @override
  final String userMessage;

  @override
  final String technicalMessage;

  @override
  final Object? cause;

  @override
  final StackTrace? stackTrace;

  @override
  final bool shouldReport;

  NetworkException({
    this.userMessage =
        'Unable to connect. Please check your internet connection.',
    required this.technicalMessage,
    this.cause,
    this.stackTrace,
    this.shouldReport = true,
  });

  factory NetworkException.timeout({Object? cause, StackTrace? stackTrace}) {
    return NetworkException(
      userMessage: 'Request timed out. Please try again.',
      technicalMessage: 'Network request timed out',
      cause: cause,
      stackTrace: stackTrace,
      shouldReport: false, // Timeouts are common, don't spam reports
    );
  }

  factory NetworkException.noConnection({
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return NetworkException(
      userMessage:
          'No internet connection. Your changes will sync when back online.',
      technicalMessage: 'No network connection available',
      cause: cause,
      stackTrace: stackTrace,
      shouldReport: false,
    );
  }
}

/// Authentication-related errors
class AuthException extends AppException {
  @override
  final String userMessage;

  @override
  final String technicalMessage;

  @override
  final Object? cause;

  @override
  final StackTrace? stackTrace;

  @override
  final bool shouldReport;

  AuthException({
    this.userMessage = 'Authentication failed. Please sign in again.',
    required this.technicalMessage,
    this.cause,
    this.stackTrace,
    this.shouldReport = true,
  });

  factory AuthException.signInCancelled() {
    return AuthException(
      userMessage: 'Sign in was cancelled.',
      technicalMessage: 'User cancelled sign in flow',
      shouldReport: false,
    );
  }

  factory AuthException.signInFailed({Object? cause, StackTrace? stackTrace}) {
    return AuthException(
      userMessage: 'Sign in failed. Please try again.',
      technicalMessage: 'Google sign in failed: $cause',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory AuthException.notAuthenticated() {
    return AuthException(
      userMessage: 'Please sign in to continue.',
      technicalMessage: 'User not authenticated',
      shouldReport: false,
    );
  }
}

/// Data/Repository errors (CRUD operations, validation)
class DataException extends AppException {
  @override
  final String userMessage;

  @override
  final String technicalMessage;

  @override
  final Object? cause;

  @override
  final StackTrace? stackTrace;

  @override
  final bool shouldReport;

  DataException({
    this.userMessage = 'An error occurred while saving your data.',
    required this.technicalMessage,
    this.cause,
    this.stackTrace,
    this.shouldReport = true,
  });

  factory DataException.notFound(String entityType, String id) {
    return DataException(
      userMessage: '$entityType not found.',
      technicalMessage: '$entityType with id $id not found',
      shouldReport: false,
    );
  }

  factory DataException.saveFailed({
    required String operation,
    Object? cause,
    StackTrace? stackTrace,
  }) {
    return DataException(
      userMessage: 'Failed to save. Please try again.',
      technicalMessage: 'Failed to $operation: $cause',
      cause: cause,
      stackTrace: stackTrace,
    );
  }

  factory DataException.deleteFailed({Object? cause, StackTrace? stackTrace}) {
    return DataException(
      userMessage: 'Failed to delete. Please try again.',
      technicalMessage: 'Delete operation failed: $cause',
      cause: cause,
      stackTrace: stackTrace,
    );
  }
}

/// Input validation errors.
/// These are user errors (not system errors) and should not be reported to crash analytics.
class ValidationException extends AppException {
  @override
  final String userMessage;

  @override
  final String technicalMessage;

  @override
  final Object? cause;

  @override
  final StackTrace? stackTrace;

  @override
  bool get shouldReport => false;

  ValidationException({
    required this.userMessage,
    required this.technicalMessage,
    this.cause,
    this.stackTrace,
  });

  factory ValidationException.emptyField(String fieldName) {
    return ValidationException(
      userMessage: '$fieldName cannot be empty.',
      technicalMessage: 'Validation failed: $fieldName is empty or whitespace',
    );
  }

  factory ValidationException.invalidAmount(double amount) {
    return ValidationException(
      userMessage: 'Amount must be greater than zero.',
      technicalMessage: 'Validation failed: amount $amount is not positive',
    );
  }

  factory ValidationException.invalidDate(DateTime date) {
    return ValidationException(
      userMessage: 'Date cannot be in the future.',
      technicalMessage: 'Validation failed: date $date is in the future',
    );
  }

  factory ValidationException.tooLong(String fieldName, int maxLength) {
    return ValidationException(
      userMessage: '$fieldName is too long (max $maxLength characters).',
      technicalMessage:
          'Validation failed: $fieldName exceeds $maxLength characters',
    );
  }
}
