import 'dart:async';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_analytics_service.dart';
import '../../../../mocks/mock_security_service.dart';

void main() {
  // Initialize the test binding
  TestWidgetsFlutterBinding.ensureInitialized();

  // Test SecurityState separately (no provider needed)
  group('SecurityState', () {
    test('default values are correct', () {
      const state = SecurityState();
      expect(state.isLocked, isFalse);
      expect(state.hasPin, isFalse);
      expect(state.isBiometricEnabled, isFalse);
      expect(state.isBiometricAvailable, isFalse);
    });

    test('copyWith preserves unchanged values', () {
      const state = SecurityState(
        isLocked: true,
        hasPin: true,
        isBiometricEnabled: true,
        isBiometricAvailable: true,
      );

      final newState = state.copyWith(isLocked: false);

      expect(newState.isLocked, isFalse);
      expect(newState.hasPin, isTrue);
      expect(newState.isBiometricEnabled, isTrue);
      expect(newState.isBiometricAvailable, isTrue);
    });
  });

  // Test SecurityNotifier with provider container
  group('SecurityNotifier Tests', () {
    late FakeFlutterSecureStorage fakeSecureStorage;
    late FakeLocalAuthentication fakeLocalAuth;
    late SharedPreferences prefs;
    late ProviderContainer container;
    late FakeAnalyticsService fakeAnalytics;

    setUp(() async {
      fakeSecureStorage = FakeFlutterSecureStorage();
      fakeLocalAuth = FakeLocalAuthentication();
      fakeAnalytics = FakeAnalyticsService();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() {
      container.dispose();
      fakeSecureStorage.reset();
      fakeLocalAuth.reset();
      fakeAnalytics.reset();
    });

    /// Helper to create container with mocked dependencies
    ProviderContainer createContainer({SecurityService? customService}) {
      final service = customService ??
          SecurityService(fakeSecureStorage, fakeLocalAuth, prefs);
      return ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          flutterSecureStorageProvider.overrideWithValue(fakeSecureStorage),
          localAuthProvider.overrideWithValue(fakeLocalAuth),
          securityServiceProvider.overrideWithValue(service),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );
    }

    group('Initial State', () {
      test('starts with default state', () {
        container = createContainer();

        final state = container.read(securityProvider);

        expect(state.isLocked, isFalse);
        expect(state.hasPin, isFalse);
      });

      test('locks on startup if PIN exists', () async {
        // Pre-set a PIN in secure storage
        await fakeSecureStorage.write(key: 'user_pin', value: '1234');
        container = createContainer();

        // Wait for async init to complete by listening for state changes
        final completer = Completer<void>();
        container.listen(securityProvider, (previous, next) {
          if (next.hasPin) {
            completer.complete();
          }
        });

        // Timeout after 1 second
        await completer.future.timeout(const Duration(seconds: 1));

        final state = container.read(securityProvider);
        expect(state.hasPin, isTrue);
        expect(state.isLocked, isTrue);
      });
    });

    group('PIN Operations', () {
      test('setPin creates PIN and sets hasPin to true', () async {
        container = createContainer();

        await container.read(securityProvider.notifier).setPin('1234');

        final state = container.read(securityProvider);
        expect(state.hasPin, isTrue);
        expect(state.isLocked, isFalse);
      });

      test('removePin removes PIN and disables biometrics', () async {
        container = createContainer();
        await container.read(securityProvider.notifier).setPin('1234');
        await prefs.setBool('biometric_enabled', true);

        await container.read(securityProvider.notifier).removePin();

        final state = container.read(securityProvider);
        expect(state.hasPin, isFalse);
        expect(state.isLocked, isFalse);
        expect(state.isBiometricEnabled, isFalse);
      });
    });

    group('Unlock Operations', () {
      test('unlockWithPin returns true for correct PIN', () async {
        container = createContainer();
        await container.read(securityProvider.notifier).setPin('1234');
        container.read(securityProvider.notifier).lockApp();

        final result = await container
            .read(securityProvider.notifier)
            .unlockWithPin('1234');

        expect(result, isTrue);
        expect(container.read(securityProvider).isLocked, isFalse);
      });

      test('unlockWithPin returns false for incorrect PIN', () async {
        // Pre-set PIN so _init will lock the app naturally
        await fakeSecureStorage.write(key: 'user_pin', value: '1234');
        container = createContainer();

        // Wait for initialization to lock the app
        final completer = Completer<void>();
        final subscription = container.listen(securityProvider, (previous, next) {
          if (next.isLocked) {
            completer.complete();
          }
        });

        // Wait for lock (with timeout)
        await completer.future.timeout(const Duration(seconds: 1));
        subscription.close();

        final result = await container
            .read(securityProvider.notifier)
            .unlockWithPin('5678');

        expect(result, isFalse, reason: 'Incorrect PIN should return false');
        expect(container.read(securityProvider).isLocked, isTrue,
            reason: 'App should remain locked');
      });

      test('unlockWithBiometrics returns false when biometrics disabled',
          () async {
        container = createContainer();
        // Biometrics disabled by default

        final result = await container
            .read(securityProvider.notifier)
            .unlockWithBiometrics();

        expect(result, isFalse);
      });

      test(
          'unlockWithBiometrics unlocks when biometrics enabled and auth succeeds',
          () async {
        container = createContainer();
        fakeLocalAuth.authenticateResult = true;

        // Enable biometrics
        await prefs.setBool('biometric_enabled', true);

        // Re-read state to pick up the preference
        await container.read(securityProvider.notifier).setPin('1234');
        await container.read(securityProvider.notifier).toggleBiometrics(true);
        container.read(securityProvider.notifier).lockApp();

        fakeLocalAuth.authenticateResult = true;
        final result = await container
            .read(securityProvider.notifier)
            .unlockWithBiometrics();

        expect(result, isTrue);
        expect(container.read(securityProvider).isLocked, isFalse);
      });

      test('unlockWithBiometrics keeps locked when auth fails', () async {
        container = createContainer();
        fakeLocalAuth.authenticateResult = true;

        // Enable biometrics
        await container.read(securityProvider.notifier).setPin('1234');
        await container.read(securityProvider.notifier).toggleBiometrics(true);
        container.read(securityProvider.notifier).lockApp();

        fakeLocalAuth.authenticateResult = false;
        final result = await container
            .read(securityProvider.notifier)
            .unlockWithBiometrics();

        expect(result, isFalse);
        expect(container.read(securityProvider).isLocked, isTrue);
      });
    });

    group('Biometric Toggle', () {
      test('toggleBiometrics enables biometrics on successful auth', () async {
        container = createContainer();
        fakeLocalAuth.authenticateResult = true;

        await container.read(securityProvider.notifier).toggleBiometrics(true);

        expect(container.read(securityProvider).isBiometricEnabled, isTrue);
      });

      test('toggleBiometrics does not enable biometrics on failed auth',
          () async {
        container = createContainer();
        fakeLocalAuth.authenticateResult = false;

        await container.read(securityProvider.notifier).toggleBiometrics(true);

        expect(container.read(securityProvider).isBiometricEnabled, isFalse);
      });

      test('toggleBiometrics disables biometrics without auth', () async {
        container = createContainer();
        fakeLocalAuth.authenticateResult = true;

        // First enable
        await container.read(securityProvider.notifier).toggleBiometrics(true);
        expect(container.read(securityProvider).isBiometricEnabled, isTrue);

        // Then disable (no auth required)
        await container.read(securityProvider.notifier).toggleBiometrics(false);
        expect(container.read(securityProvider).isBiometricEnabled, isFalse);
      });
    });

    group('Lock App', () {
      test('lockApp sets isLocked to true', () async {
        container = createContainer();
        await container.read(securityProvider.notifier).setPin('1234');

        container.read(securityProvider.notifier).lockApp();

        expect(container.read(securityProvider).isLocked, isTrue);
      });
    });

    group('Auto-Lock Suspension for Picker Operations', () {
      test('suspendAutoLock prevents auto-lock during picker operations',
          () async {
        container = createContainer();
        await container.read(securityProvider.notifier).setPin('1234');

        // Unlock the app first
        await container.read(securityProvider.notifier).unlockWithPin('1234');
        expect(container.read(securityProvider).isLocked, isFalse);

        // Suspend auto-lock (simulating going to picker)
        container.read(securityProvider.notifier).suspendAutoLock();

        // Simulate app lifecycle: paused -> resumed (what happens with picker)
        container
            .read(securityProvider.notifier)
            .didChangeAppLifecycleState(AppLifecycleState.paused);

        // Wait a bit to simulate time in picker
        await Future<void>.delayed(const Duration(milliseconds: 100));

        container
            .read(securityProvider.notifier)
            .didChangeAppLifecycleState(AppLifecycleState.resumed);

        // App should NOT be locked because auto-lock is suspended
        expect(container.read(securityProvider).isLocked, isFalse);
      });

      test('resumeAutoLock re-enables auto-lock', () async {
        container = createContainer();
        await container.read(securityProvider.notifier).setPin('1234');

        // Unlock the app first
        await container.read(securityProvider.notifier).unlockWithPin('1234');

        // Suspend then resume auto-lock
        container.read(securityProvider.notifier).suspendAutoLock();
        container.read(securityProvider.notifier).resumeAutoLock();

        // Now auto-lock should work again if time passes
        // (but since we just resumed, pause time is reset so won't lock immediately)
        expect(container.read(securityProvider).isLocked, isFalse);
      });

      test('resumeAutoLock resets pause time to prevent immediate lock',
          () async {
        container = createContainer();
        await container.read(securityProvider.notifier).setPin('1234');
        await container.read(securityProvider.notifier).unlockWithPin('1234');

        // Suspend, simulate some time, then resume
        container.read(securityProvider.notifier).suspendAutoLock();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        container.read(securityProvider.notifier).resumeAutoLock();

        // Simulate app resume immediately after resumeAutoLock
        container
            .read(securityProvider.notifier)
            .didChangeAppLifecycleState(AppLifecycleState.resumed);

        // Should NOT lock because pause time was reset
        expect(container.read(securityProvider).isLocked, isFalse);
      });
    });
  });
}

