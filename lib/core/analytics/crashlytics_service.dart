/// Crashlytics service for error and crash reporting.
///
/// This abstraction layer wraps Firebase Crashlytics and provides
/// a clean interface for the rest of the app.
library;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// Provider for the crashlytics service
final crashlyticsServiceProvider = Provider<CrashlyticsService>((ref) {
  return CrashlyticsService();
});

/// Crashlytics service that wraps Firebase Crashlytics
class CrashlyticsService {
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  /// Initialize Crashlytics with Flutter error handlers
  Future<void> initialize() async {
    // Disable Crashlytics in debug mode to avoid noise
    await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      if (kDebugMode) {
        // In debug mode, print to console
        FlutterError.presentError(errorDetails);
      } else {
        // In release mode, send to Crashlytics
        _crashlytics.recordFlutterFatalError(errorDetails);
      }
    };

    LoggerService.info('Crashlytics initialized (disabled in debug mode)');
  }

  /// Record a non-fatal error
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    if (kDebugMode) {
      LoggerService.error(
        'Crashlytics recording error',
        error: exception,
        stackTrace: stack,
        metadata: {'reason': reason, 'fatal': fatal},
      );
      return;
    }

    await _crashlytics.recordError(
      exception,
      stack,
      reason: reason,
      fatal: fatal,
      information: information,
    );
  }

  /// Record a Flutter error
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (kDebugMode) {
      FlutterError.presentError(details);
      return;
    }
    await _crashlytics.recordFlutterError(details);
  }

  /// Set user identifier for crash reports
  Future<void> setUserIdentifier(String identifier) async {
    await _crashlytics.setUserIdentifier(identifier);
  }

  /// Clear user identifier (on sign out)
  Future<void> clearUserIdentifier() async {
    await _crashlytics.setUserIdentifier('');
  }

  /// Set a custom key-value pair for crash reports
  Future<void> setCustomKey(String key, Object value) async {
    await _crashlytics.setCustomKey(key, value);
  }

  /// Log a message to Crashlytics (appears in crash reports)
  Future<void> log(String message) async {
    await _crashlytics.log(message);
    LoggerService.debug('Crashlytics log', metadata: {'message': message});
  }

  /// Force a crash for testing (only use in debug/testing!)
  void testCrash() {
    if (kDebugMode) {
      LoggerService.warn('Test crash requested (disabled in debug mode)');
      return;
    }
    _crashlytics.crash();
  }

  /// Check if Crashlytics collection is enabled
  bool get isCrashlyticsCollectionEnabled =>
      _crashlytics.isCrashlyticsCollectionEnabled;
}
