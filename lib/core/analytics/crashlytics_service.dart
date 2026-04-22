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

  /// Enable Crashlytics in debug mode for testing (default: false)
  /// Set this to true via debug settings to test Crashlytics in debug builds
  static bool enableInDebugMode = false;

  /// Initialize Crashlytics with Flutter error handlers
  Future<void> initialize() async {
    // BUG FIX: Allow enabling Crashlytics in debug mode for testing
    // By default, disabled in debug mode to avoid noise
    // Can be enabled via Debug Settings -> Enable Crashlytics in Debug Mode
    final shouldEnable = !kDebugMode || enableInDebugMode;
    await _crashlytics.setCrashlyticsCollectionEnabled(shouldEnable);

    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = (errorDetails) {
      if (kDebugMode && !enableInDebugMode) {
        // In debug mode (without override), print to console
        FlutterError.presentError(errorDetails);
      } else {
        // In release mode OR debug mode with override, send to Crashlytics
        _crashlytics.recordFlutterFatalError(errorDetails);
      }
    };

    LoggerService.info(
      'Crashlytics initialized',
      metadata: {
        'enabled': shouldEnable,
        'debugMode': kDebugMode,
        'debugOverride': enableInDebugMode,
      },
    );
  }

  /// Record a non-fatal error
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    if (kDebugMode && !enableInDebugMode) {
      LoggerService.error(
        'Crashlytics recording error (debug mode - not sent)',
        error: exception,
        stackTrace: stack,
        metadata: {'reason': reason, 'fatal': fatal},
      );
      return;
    }

    // In release mode OR debug mode with override, send to Crashlytics
    await _crashlytics.recordError(
      exception,
      stack,
      reason: reason,
      fatal: fatal,
      information: information,
    );

    LoggerService.info(
      'Error recorded to Crashlytics',
      metadata: {'reason': reason, 'fatal': fatal},
    );
  }

  /// Record a Flutter error
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (kDebugMode && !enableInDebugMode) {
      FlutterError.presentError(details);
      return;
    }
    await _crashlytics.recordFlutterError(details);
    LoggerService.info('Flutter error recorded to Crashlytics');
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

  /// Force a crash for testing (works in debug mode if enableInDebugMode is true)
  ///
  /// BUG FIX: Now works in debug mode when Crashlytics is enabled via debug settings
  /// This allows testing crash reporting before releasing to production
  void testCrash() {
    if (kDebugMode && !enableInDebugMode) {
      LoggerService.warn(
        'Test crash requested but Crashlytics is disabled in debug mode. '
        'Enable "Crashlytics in Debug Mode" in Debug Settings to test crashes.',
      );
      return;
    }

    LoggerService.warn('Test crash initiated - app will crash now!');
    _crashlytics.crash();
  }

  /// Record a test non-fatal error for testing Crashlytics
  Future<void> testNonFatalError() async {
    await recordError(
      Exception('Test non-fatal error from Debug Settings'),
      StackTrace.current,
      reason: 'Testing Crashlytics error reporting',
      fatal: false,
    );
  }

  /// Check if Crashlytics collection is enabled
  bool get isCrashlyticsCollectionEnabled =>
      _crashlytics.isCrashlyticsCollectionEnabled;
}
