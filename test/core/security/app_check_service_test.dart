import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/security/app_check_service.dart';

void main() {
  group('AppCheckService provider selection', () {
    test('debug builds use the debug providers', () {
      expect(
        AppCheckService.androidProvider(isDebug: true),
        isA<AndroidDebugProvider>(),
      );
      expect(
        AppCheckService.appleProvider(isDebug: true),
        isA<AppleDebugProvider>(),
      );
    });

    test('release builds use Play Integrity on Android', () {
      expect(
        AppCheckService.androidProvider(isDebug: false),
        isA<AndroidPlayIntegrityProvider>(),
      );
    });

    test('release builds use DeviceCheck on Apple (no entitlement needed)', () {
      expect(
        AppCheckService.appleProvider(isDebug: false),
        isA<AppleDeviceCheckProvider>(),
      );
    });
  });
}
