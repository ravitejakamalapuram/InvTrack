import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/error/app_exception.dart';

/// Log levels for structured logging
enum LogLevel {
  debug,
  info,
  warn,
  error;

  /// Get emoji icon for log level
  String get icon {
    switch (this) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warn:
        return '⚠️';
      case LogLevel.error:
        return '🔴';
    }
  }

  /// Get label for log level
  String get label {
    switch (this) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warn:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }
}

/// Centralized logging service for the application.
/// Provides structured logging with log levels, context metadata, and Crashlytics integration.
///
/// Usage:
/// ```dart
/// LoggerService.debug('User tapped button', metadata: {'screen': 'home'});
/// LoggerService.info('Investment created', metadata: {'id': investmentId, 'type': type.name});
/// LoggerService.warn('API rate limit approaching', metadata: {'remaining': 10});
/// LoggerService.error('Failed to save data', error: e, stackTrace: st, metadata: {'userId': userId});
/// ```
class LoggerService {
  LoggerService._();

  /// Static instance of CrashlyticsService to avoid provider errors
  /// This is initialized lazily and reused across all log calls
  static CrashlyticsService? _crashlyticsService;

  /// Log a debug message (only in debug mode)
  static void debug(String message, {Map<String, dynamic>? metadata}) {
    _log(LogLevel.debug, message, metadata: metadata);
  }

  /// Log an info message (only in debug mode)
  static void info(String message, {Map<String, dynamic>? metadata}) {
    _log(LogLevel.info, message, metadata: metadata);
  }

  /// Log a warning message (debug mode + Crashlytics in production)
  static void warn(
    String message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.warn,
      message,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an error message (debug mode + Crashlytics in production)
  static void error(
    String message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      metadata: metadata,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Internal logging implementation
  static void _log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? metadata,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // In debug mode: print structured logs
    if (kDebugMode) {
      final buffer = StringBuffer();
      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buffer.writeln('${level.icon} ${level.label}: $message');

      if (metadata != null && metadata.isNotEmpty) {
        buffer.writeln('Metadata:');
        metadata.forEach((key, value) {
          buffer.writeln('  $key: $value');
        });
      }

      if (error != null) {
        buffer.writeln('Error: $error');
      }

      if (stackTrace != null) {
        buffer.writeln('Stack Trace:\n$stackTrace');
      }

      buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint(buffer.toString());
    }

    // In production: send warnings and errors to Crashlytics
    // BUT: Skip transient errors (shouldReport = false) to avoid spam
    if (!kDebugMode && (level == LogLevel.warn || level == LogLevel.error)) {
      // Check if error is an AppException with shouldReport = false
      bool shouldReport = true;
      if (error is AppException) {
        shouldReport = error.shouldReport;
      }

      if (shouldReport) {
        final reason = metadata != null
            ? '$message | Metadata: ${metadata.entries.map((e) => '${e.key}=${e.value}').join(', ')}'
            : message;

        // Initialize Crashlytics service lazily to avoid provider errors
        _crashlyticsService ??= CrashlyticsService(debugModeEnabled: false);
        _crashlyticsService!.recordError(
          error ?? Exception(message),
          stackTrace,
          reason: reason,
          fatal: level == LogLevel.error,
        );
      }
    }
  }
}
