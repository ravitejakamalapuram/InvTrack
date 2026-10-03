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
    ProviderContainer createContainer({
      SecurityService? customService,
      SecurityClock? clock,
    }) {
      final service =
          customService ??
          SecurityService(fakeSecureStorage, fakeLocalAuth, prefs);
      return ProviderContainer(
        overrides: [
          if (clock != null) securityClockProvider.overrideWithValue(clock),
          sharedPreferencesProvider.overrideWithValue(prefs),
          flutterSecureStorageProvider.overrideWithValue(fakeSecureStorage),
          localAuthProvider.overrideWithValue(fakeLocalAuth),
          securityServiceProvider.overrideWithValue(service),
          analyticsServiceProvider.overrideWithValue(fakeAnalytics),
        ],
      );
    }

    group('Initial State', () {
      // A07: this used to expect isLocked == false on the first read. That
      // first state is what the router draws before secure storage answers,
      // so with a PIN set the portfolio rendered before the lock. Without
      // the has_pin mirror (first start after the update) the state is now
      // unknown, which counts as locked, until storage answers.
      test('starts locked while it is unknown whether a PIN is set', () async {
        container = createContainer();

        final state = container.read(securityProvider);
        expect(state.isLocked, isTrue);
        expect(state.hasPin, isFalse);

        await pumpEventQueue();
        expect(container.read(securityProvider).isLocked, isFalse);
        expect(prefs.getBool('has_pin'), isFalse);
      });

      test('starts locked on the first read when the has_pin mirror is '
          'set', () async {
        SharedPreferences.setMockInitialValues({'has_pin': true});
        prefs = await SharedPreferences.getInstance();
        await fakeSecureStorage.write(key: 'user_pin', value: '1234');
        container = createContainer();

        // Read before any await: this is what the first frame sees.
        final state = container.read(securityProvider);
        expect(state.isLocked, isTrue);
        expect(state.hasPin, isTrue);

        await pumpEventQueue();
        expect(container.read(securityProvider).isLocked, isTrue);
      });

      test('starts unlocked on the first read when the mirror says no '
          'PIN', () async {
        SharedPreferences.setMockInitialValues({'has_pin': false});
        prefs = await SharedPreferences.getInstance();
        container = createContainer();

        expect(container.read(securityProvider).isLocked, isFalse);
        await pumpEventQueue();
        expect(container.read(securityProvider).isLocked, isFalse);
      });

      test('a PIN found in storage locks and fixes a stale mirror', () async {
        SharedPreferences.setMockInitialValues({'has_pin': false});
        prefs = await SharedPreferences.getInstance();
        await fakeSecureStorage.write(key: 'user_pin', value: '1234');
        container = createContainer();
        container.read(securityProvider);

        await pumpEventQueue();
        expect(container.read(securityProvider).isLocked, isTrue);
        expect(prefs.getBool('has_pin'), isTrue);
      });

      test('stays locked when secure storage fails and the mirror says a PIN '
          'is set', () async {
        SharedPreferences.setMockInitialValues({'has_pin': true});
        prefs = await SharedPreferences.getInstance();
        fakeSecureStorage.setThrowRead('user_pin', true);
        container = createContainer();
        container.read(securityProvider);

        await pumpEventQueue();
        final state = container.read(securityProvider);
        expect(state.isLocked, isTrue);
        expect(state.hasPin, isTrue);
      });

      test('setPin sets the mirror and removePin clears it', () async {
        container = createContainer();
        final notifier = container.read(securityProvider.notifier);
        await pumpEventQueue();

        await notifier.setPin('1234');
        expect(prefs.getBool('has_pin'), isTrue);

        await notifier.removePin();
        expect(prefs.getBool('has_pin'), isFalse);
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
        final subscription = container.listen(securityProvider, (
          previous,
          next,
        ) {
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
        expect(
          container.read(securityProvider).isLocked,
          isTrue,
          reason: 'App should remain locked',
        );
      });

      test(
        'unlockWithBiometrics returns false when biometrics disabled',
        () async {
          container = createContainer();
          // Biometrics disabled by default

          final result = await container
              .read(securityProvider.notifier)
              .unlockWithBiometrics();

          expect(result, isFalse);
        },
      );

      test(
        'unlockWithBiometrics unlocks when biometrics enabled and auth succeeds',
        () async {
          container = createContainer();
          fakeLocalAuth.authenticateResult = true;

          // Enable biometrics
          await prefs.setBool('biometric_enabled', true);

          // Re-read state to pick up the preference
          await container.read(securityProvider.notifier).setPin('1234');
          await container
              .read(securityProvider.notifier)
              .toggleBiometrics(true);
          container.read(securityProvider.notifier).lockApp();

          fakeLocalAuth.authenticateResult = true;
          final result = await container
              .read(securityProvider.notifier)
              .unlockWithBiometrics();

          expect(result, isTrue);
          expect(container.read(securityProvider).isLocked, isFalse);
        },
      );

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

      test(
        'toggleBiometrics does not enable biometrics on failed auth',
        () async {
          container = createContainer();
          fakeLocalAuth.authenticateResult = false;

          await container
              .read(securityProvider.notifier)
              .toggleBiometrics(true);

          expect(container.read(securityProvider).isBiometricEnabled, isFalse);
        },
      );

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
      test(
        'suspendAutoLock prevents auto-lock during picker operations',
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
        },
      );

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

      test(
        'resumeAutoLock resets pause time to prevent immediate lock',
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
        },
      );
    });

    // A07: whoever holds an unlocked phone can change its clock. Moving it
    // back must not skip the auto-lock or stretch the unlock grace period.
    group('Auto-lock timing and device clock changes', () {
      late _FakeClock clock;

      /// PIN set, auto-lock after 60 s, unlocked at the clock's start.
      Future<SecurityNotifier> unlockedWithPin() async {
        clock = _FakeClock();
        await prefs.setInt('auto_lock_duration', 60);
        container = createContainer(clock: clock);
        final notifier = container.read(securityProvider.notifier);
        await pumpEventQueue();
        await notifier.setPin('1234');
        notifier.lockApp();
        expect(await notifier.unlockWithPin('1234'), isTrue);
        return notifier;
      }

      test('locks after 61 s in the background', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 61));
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(container.read(securityProvider).isLocked, isTrue);
      });

      test('does not lock after 59 s in the background', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 59));
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(container.read(securityProvider).isLocked, isFalse);
      });

      test(
        'locks when the clock is moved back while in the background',
        () async {
          final notifier = await unlockedWithPin();
          clock.advance(const Duration(seconds: 10));
          notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
          clock.advance(const Duration(seconds: 61));
          clock.moveWallClock(const Duration(hours: -1));
          notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);

          expect(container.read(securityProvider).isLocked, isTrue);
        },
      );

      test('locks when the clock is moved back by less than the time '
          'away', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 90));
        // Wall clock now says only 30 s passed.
        clock.moveWallClock(const Duration(seconds: -60));
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(container.read(securityProvider).isLocked, isTrue);
      });

      test(
        'a clock moved back does not stretch the unlock grace period',
        () async {
          final notifier = await unlockedWithPin();
          // Leave at once (inside the 5 s grace), stay away 61 s, and move the
          // clock back so "time since unlock" looks negative.
          notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
          clock.advance(const Duration(seconds: 61));
          clock.moveWallClock(const Duration(hours: -1));
          notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);

          expect(container.read(securityProvider).isLocked, isTrue);
        },
      );

      test('locks after time asleep, when only the wall clock moved', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        // The monotonic clock stops while the phone sleeps.
        clock.moveWallClock(const Duration(minutes: 10));
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(container.read(securityProvider).isLocked, isTrue);
      });

      test('a picker suspension still expires after 5 minutes when the clock '
          'is moved back', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.suspendAutoLock();
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock.advance(const Duration(minutes: 6));
        clock.moveWallClock(const Duration(hours: -1));
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);

        expect(container.read(securityProvider).isLocked, isTrue);
      });
    });
  });
}

/// Wall clock and monotonic clock that tests move by hand.
class _FakeClock implements SecurityClock {
  DateTime _wall = DateTime(2026, 10, 3, 9);
  Duration _monotonic = Duration.zero;

  /// Real time passing: both clocks move.
  void advance(Duration d) {
    _wall = _wall.add(d);
    _monotonic += d;
  }

  /// Someone changes the device clock: only the wall clock moves.
  void moveWallClock(Duration d) => _wall = _wall.add(d);

  @override
  DateTime now() => _wall;

  @override
  Duration monotonic() => _monotonic;
}
