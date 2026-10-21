import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// Firebase App Check start-up (#774, A32).
///
/// MONITOR mode only: this attaches App Check tokens to Firebase requests so
/// the console can show verified vs unverified traffic. Enforcement is a
/// separate console step; nothing here can reject a request.
class AppCheckService {
  const AppCheckService._();

  /// Debug builds use the debug provider (register its token in the console);
  /// release builds use Play Integrity.
  @visibleForTesting
  static AndroidAppCheckProvider androidProvider({required bool isDebug}) =>
      isDebug
      ? const AndroidDebugProvider()
      : const AndroidPlayIntegrityProvider();

  /// Debug builds use the debug provider; release builds use DeviceCheck,
  /// which needs no extra entitlement.
  @visibleForTesting
  static AppleAppCheckProvider appleProvider({required bool isDebug}) =>
      isDebug ? const AppleDebugProvider() : const AppleDeviceCheckProvider();

  /// Call after `Firebase.initializeApp`. Never throws: a failure here must
  /// not stop the app from starting.
  static Future<void> initialize() async {
    // A mobile browser reports Android or iOS too, but this app uses the
    // native providers only.
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: androidProvider(isDebug: kDebugMode),
        providerApple: appleProvider(isDebug: kDebugMode),
      );
    } catch (e, stack) {
      LoggerService.error(
        'Failed to activate App Check',
        error: e,
        stackTrace: stack,
        metadata: {'service': 'AppCheckService'},
      );
    }
  }
}
