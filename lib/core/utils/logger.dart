import 'dart:developer' as developer;

/// Simple logging utility for the app.
/// 
/// Provides consistent logging across the application with
/// different log levels.
class AppLogger {
  AppLogger._();

  static const String _tag = 'InvTracker';

  /// Log debug information
  static void debug(String message, {String? tag}) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 500, // Fine
    );
  }

  /// Log general information
  static void info(String message, {String? tag}) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 800, // Info
    );
  }

  /// Log warnings
  static void warning(String message, {String? tag}) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 900, // Warning
    );
  }

  /// Log errors with optional stack trace
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: tag ?? _tag,
      level: 1000, // Severe
      error: error,
      stackTrace: stackTrace,
    );
  }
}

