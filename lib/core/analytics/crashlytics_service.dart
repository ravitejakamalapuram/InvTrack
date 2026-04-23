/// Crashlytics service for error and crash reporting.
///
/// This abstraction layer wraps Firebase Crashlytics and provides
/// a clean interface for the rest of the app.
///
/// **BUG FIX (2026-04-22)**: Comprehensive crash reporting
/// - Added PlatformDispatcher.instance.onError for async errors
/// - Enhanced error logging with metadata
/// - Improved debug mode handling
library;

import 'dart:ui';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';

/// Provider for Crashlytics debug mode state (reactive toggle)
///
/// This provider manages whether Crashlytics is enabled in debug builds.
/// In release builds, Crashlytics is always enabled regardless of this setting.
final crashlyticsDebugModeProvider = NotifierProvider<CrashlyticsDebugModeNotifier, bool>(
  CrashlyticsDebugModeNotifier.new,
);

/// Notifier for managing Crashlytics debug mode state.
///
/// When enabled in debug mode, Crashlytics will collect and report crashes.
/// When disabled in debug mode, errors are only logged locally.
class CrashlyticsDebugModeNotifier extends Notifier<bool> {
  static const _prefKey = 'crashlytics_debug_mode_enabled';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Set Crashlytics debug mode to a specific value.
  ///
  /// This also updates the Firebase Crashlytics collection state immediately.
  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return; // No change needed
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_prefKey, enabled);
    state = enabled;

    // Update Crashlytics collection state
    final shouldEnable = !kDebugMode || enabled;
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(shouldEnable);
  }
}

/// Provider for the crashlytics service
final crashlyticsServiceProvider = Provider<CrashlyticsService>((ref) {
  final debugModeEnabled = ref.watch(crashlyticsDebugModeProvider);
  return CrashlyticsService(debugModeEnabled: debugModeEnabled);
});

/// Crashlytics service that wraps Firebase Crashlytics
class CrashlyticsService {
  final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;
  final bool debugModeEnabled;

  CrashlyticsService({required this.debugModeEnabled});

  // Track whether handlers have been installed to make installation idempotent
  static bool _handlersInstalled = false;

  /// Static flag for backward compatibility with direct instantiation
  /// This allows CrashlyticsService(debugModeEnabled: CrashlyticsService.enableInDebugMode)
  /// TODO: Remove once all call sites migrate to using crashlyticsDebugModeProvider
  static bool enableInDebugMode = false;

  // Store previous handlers so we can chain them
  static FlutterExceptionHandler? _previousFlutterOnError;
  static ErrorCallback? _previousPlatformOnError;

  /// Initialize Crashlytics with comprehensive error handlers
  ///
  /// BUG FIX: Added PlatformDispatcher.instance.onError to catch ALL async errors
  /// that escape runZonedGuarded and FlutterError.onError.
  ///
  /// Handler installation is idempotent - handlers are installed only once
  /// and existing handlers are chained to prevent clobbering other code.
  Future<void> initialize() async {
    // Update Crashlytics collection state
    final shouldEnable = !kDebugMode || debugModeEnabled;
    await _crashlytics.setCrashlyticsCollectionEnabled(shouldEnable);

    // Install global handlers only once (idempotent)
    if (!_handlersInstalled) {
      _installGlobalHandlers();
      _handlersInstalled = true;
    }

    LoggerService.info(
      'Crashlytics initialized',
      metadata: {
        'enabled': shouldEnable,
        'debugMode': kDebugMode,
        'debugOverride': debugModeEnabled,
        'handlers': 'FlutterError.onError + PlatformDispatcher.onError',
        'handlersInstalled': _handlersInstalled,
      },
    );
  }

  /// Install global error handlers (called only once)
  ///
  /// Captures existing handlers and chains them so we don't clobber other code.
  void _installGlobalHandlers() {
    // 1. Capture and chain Flutter framework error handler
    _previousFlutterOnError = FlutterError.onError;

    FlutterError.onError = (errorDetails) {
      if (kDebugMode && !debugModeEnabled) {
        // In debug mode (without override), print to console
        FlutterError.presentError(errorDetails);
      } else {
        // In release mode OR debug mode with override, send to Crashlytics
        _crashlytics.recordFlutterFatalError(errorDetails);
        LoggerService.error(
          'Flutter framework error',
          error: errorDetails.exception,
          stackTrace: errorDetails.stack,
          metadata: {
            'library': errorDetails.library,
            'context': errorDetails.context?.toString() ?? 'unknown',
          },
        );
      }

      // Chain to previous handler if it exists
      _previousFlutterOnError?.call(errorDetails);
    };

    // 2. Capture and chain platform dispatcher error handler
    _previousPlatformOnError = PlatformDispatcher.instance.onError;

    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode && !debugModeEnabled) {
        // In debug mode (without override), log to console
        LoggerService.error(
          'Uncaught async error',
          error: error,
          stackTrace: stack,
          metadata: {'source': 'PlatformDispatcher'},
        );
      } else {
        // In release mode OR debug mode with override, send to Crashlytics
        final isFatal = !_isTransientError(error, stack);
        _crashlytics.recordError(
          error,
          stack,
          reason: 'Uncaught async error from PlatformDispatcher',
          fatal: isFatal,
        );
        LoggerService.error(
          'Uncaught async error reported to Crashlytics',
          error: error,
          stackTrace: stack,
          metadata: {'fatal': isFatal.toString(), 'source': 'PlatformDispatcher'},
        );
      }

      // Chain to previous handler if it exists, otherwise return true (handled)
      return _previousPlatformOnError?.call(error, stack) ?? true;
    };
  }

  /// Determine if an error is transient/recoverable (non-fatal)
  ///
  /// Returns true for network errors, timeouts, stream cancellations, etc.
  /// Returns false for logic errors, state errors, etc. (fatal)
  bool _isTransientError(dynamic error, StackTrace? stack) {
    final errorString = error.toString().toLowerCase();

    // Network-related errors (transient)
    if (errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return true;
    }

    // Stream/async cancellations (transient)
    if (errorString.contains('bad state: stream has already been listened to') ||
        errorString.contains('bad state: no element') ||
        errorString.contains('bad state: cannot') ||
        errorString.contains('cancelled')) {
      return true;
    }

    // HTTP errors (transient)
    if (errorString.contains('http') ||
        errorString.contains('404') ||
        errorString.contains('500') ||
        errorString.contains('503')) {
      return true;
    }

    // Default: treat as fatal
    return false;
  }

  /// Record a non-fatal error
  ///
  /// BUG FIX: Now respects debug override and provides better logging
  Future<void> recordError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
    Iterable<Object> information = const [],
  }) async {
    if (kDebugMode && !debugModeEnabled) {
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

    // Only log success in debug mode to avoid noisy logs and potential cycles
    if (kDebugMode) {
      LoggerService.info(
        'Error recorded to Crashlytics',
        metadata: {
          'reason': reason,
          'fatal': fatal,
          'exceptionType': exception.runtimeType.toString(),
        },
      );
    }
  }

  /// Record a Flutter error
  ///
  /// BUG FIX: Now respects debug override
  Future<void> recordFlutterError(FlutterErrorDetails details) async {
    if (kDebugMode && !debugModeEnabled) {
      FlutterError.presentError(details);
      return;
    }
    await _crashlytics.recordFlutterError(details);

    // Only log success in debug mode to avoid noisy logs
    if (kDebugMode) {
      LoggerService.info(
        'Flutter error recorded to Crashlytics',
        metadata: {
          'exception': details.exception.runtimeType.toString(),
          'library': details.library,
        },
      );
    }
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

  /// Force a crash for testing (works in debug mode if debugModeEnabled is true)
  ///
  /// BUG FIX: Now works in debug mode when Crashlytics is enabled via debug settings
  /// This allows testing crash reporting before releasing to production
  void testCrash() {
    if (kDebugMode && !debugModeEnabled) {
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
  ///
  /// BUG FIX: Added to allow testing non-fatal error reporting
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