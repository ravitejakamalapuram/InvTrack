import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/features/security/data/services/security_clock.dart';
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

      // A07: the lock screen shows from the first frame, so it must know
      // biometrics are on before secure storage answers.
      test('reads the biometric setting on the first read', () async {
        SharedPreferences.setMockInitialValues({
          'has_pin': true,
          'biometric_enabled': true,
        });
        prefs = await SharedPreferences.getInstance();
        container = createContainer();

        expect(container.read(securityProvider).isBiometricEnabled, isTrue);
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

      // With no mirror (first start after the update) and secure storage
      // failing, nobody knows whether a PIN is set: stay locked rather than
      // open the portfolio, and read storage again when the app resumes.
      test('stays locked when secure storage fails and there is no '
          'mirror', () async {
        fakeSecureStorage.setThrowRead('user_pin', true);
        container = createContainer();
        container.read(securityProvider);

        await pumpEventQueue();
        expect(container.read(securityProvider).isLocked, isTrue);
      });

      test('after a failed read with no mirror, reads storage again on '
          'resume and unlocks when no PIN is set', () async {
        fakeSecureStorage.setThrowRead('user_pin', true);
        container = createContainer();
        container.read(securityProvider);
        await pumpEventQueue();

        fakeSecureStorage.setThrowRead('user_pin', false);
        container
            .read(securityProvider.notifier)
            .didChangeAppLifecycleState(AppLifecycleState.resumed);
        await pumpEventQueue();

        final state = container.read(securityProvider);
        expect(state.isLocked, isFalse);
        expect(state.hasPin, isFalse);
        expect(prefs.getBool('has_pin'), isFalse);
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
          await pumpEventQueue();

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
          await pumpEventQueue();

          // Should NOT lock because pause time was reset
          expect(container.read(securityProvider).isLocked, isFalse);
        },
      );
    });

    // A07 and A112: time away is measured on the boot clock (see
    // SecurityClock), which counts deep sleep and which whoever holds the
    // phone cannot change. The wall clock is not read at all, so the fake
    // has none.
    group('Auto-lock timing on the boot clock', () {
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

      Future<bool> lockedAfterResume(SecurityNotifier notifier) async {
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await pumpEventQueue();
        return container.read(securityProvider).isLocked;
      }

      test('locks after 61 s in the background', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 61));

        expect(await lockedAfterResume(notifier), isTrue);
      });

      test('does not lock after 59 s in the background', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock.advance(const Duration(seconds: 59));

        expect(await lockedAfterResume(notifier), isFalse);
      });

      // Before A112 these said that a monotonic clock stops while the phone
      // sleeps and only the wall clock moves. The boot clock keeps counting
      // in deep sleep, so time asleep is time away.
      test('locks after 10 minutes asleep', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock.advance(const Duration(minutes: 10));

        expect(await lockedAfterResume(notifier), isTrue);
      });

      test('time asleep does not stretch the unlock grace period', () async {
        final notifier = await unlockedWithPin();
        // Leave inside the 5 s grace, then sleep for 10 minutes.
        clock.advance(const Duration(seconds: 2));
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock.advance(const Duration(minutes: 10));

        expect(await lockedAfterResume(notifier), isTrue);
      });

      test(
        'leaving at once does not stretch the unlock grace period',
        () async {
          final notifier = await unlockedWithPin();
          notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
          clock.advance(const Duration(seconds: 61));

          expect(await lockedAfterResume(notifier), isTrue);
        },
      );

      test('a picker suspension expires after 5 minutes', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.suspendAutoLock();
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock.advance(const Duration(minutes: 6));

        expect(await lockedAfterResume(notifier), isTrue);
      });

      test('a picker suspension holds for 4 minutes 59 seconds', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.suspendAutoLock();
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        clock.advance(const Duration(minutes: 4, seconds: 59));

        expect(await lockedAfterResume(notifier), isFalse);
      });

      test('a reading that runs backwards (the clock fell back to its '
          'stopwatch) locks', () async {
        final notifier = await unlockedWithPin();
        clock.advance(const Duration(seconds: 10));
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        await pumpEventQueue();
        clock.advance(const Duration(hours: -1));

        expect(await lockedAfterResume(notifier), isTrue);
      });
    });

    // A112: time away is read from Android's boot clock
    // (SystemClock.elapsedRealtime over the security channel). It keeps
    // counting while the phone sleeps and the user cannot set it, so the
    // device clock can neither skip nor force the auto-lock.
    group('A112: auto-lock reads the boot clock', () {
      const channel = MethodChannel('com.invtracker/security');
      late int bootMs;

      setUp(() {
        bootMs = 1000000;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'elapsedRealtime') return bootMs;
              return null;
            });
      });

      tearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      /// PIN set and unlocked at boot time 1,000 s, auto-lock after
      /// [autoLockSeconds].
      Future<SecurityNotifier> unlockedWithPin(
        int autoLockSeconds, {
        SecurityClock? clock,
      }) async {
        await prefs.setInt('auto_lock_duration', autoLockSeconds);
        container = createContainer(clock: clock);
        final notifier = container.read(securityProvider.notifier);
        await pumpEventQueue();
        await notifier.setPin('1234');
        notifier.lockApp();
        expect(await notifier.unlockWithPin('1234'), isTrue);
        await pumpEventQueue();
        return notifier;
      }

      /// Leaves the app at boot time 1,000 s and comes back at [resumeAtMs].
      Future<bool> lockedAfterResumeAt(
        SecurityNotifier notifier,
        int resumeAtMs,
      ) async {
        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        await pumpEventQueue();
        bootMs = resumeAtMs;
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await pumpEventQueue();
        return container.read(securityProvider).isLocked;
      }

      test(
        'locks after 30 minutes asleep, whatever the wall clock says',
        () async {
          // Paused at 10:00, asleep until 10:30, clock then set to 10:00:30:
          // the wall clock and a stopwatch both say about 30 s.
          final notifier = await unlockedWithPin(60);

          expect(await lockedAfterResumeAt(notifier, 2800000), isTrue);
        },
      );

      // Before A112 a wall clock moved back even 2 s (an NTP correction)
      // counted as 10 years and locked here. The wall clock is not read now.
      test('does not lock after 10 s with a 5 minute setting', () async {
        final notifier = await unlockedWithPin(300);

        expect(await lockedAfterResumeAt(notifier, 1010000), isFalse);
      });

      test('does not lock after 59 s with a 60 s setting', () async {
        final notifier = await unlockedWithPin(60);

        expect(await lockedAfterResumeAt(notifier, 1059000), isFalse);
      });

      test('locks after exactly 60 s with a 60 s setting', () async {
        final notifier = await unlockedWithPin(60);

        expect(await lockedAfterResumeAt(notifier, 1060000), isTrue);
      });

      test('without the channel, falls back to a stopwatch and locks after '
          '61 s', () async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        final stopwatch = _ManualStopwatch();
        final notifier = await unlockedWithPin(
          60,
          clock: SecurityClock(stopwatch: stopwatch),
        );

        notifier.didChangeAppLifecycleState(AppLifecycleState.paused);
        await pumpEventQueue();
        stopwatch.value += const Duration(seconds: 61);
        notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await pumpEventQueue();

        expect(container.read(securityProvider).isLocked, isTrue);
      });
    });

    // A114: the lock screen shows before secure storage answers, so the
    // user can unlock before the start-up checks finish. Those checks must
    // not lock the app again.
    group('A114: start-up checks after an unlock', () {
      late _HeldHasPinService service;

      Future<SecurityNotifier> lockedWhileStorageIsSlow() async {
        SharedPreferences.setMockInitialValues({'has_pin': true});
        prefs = await SharedPreferences.getInstance();
        service = _HeldHasPinService(fakeSecureStorage, fakeLocalAuth, prefs);
        container = createContainer(customService: service);
        expect(container.read(securityProvider).isLocked, isTrue);
        return container.read(securityProvider.notifier);
      }

      test('a PIN unlock before storage answers is not undone', () async {
        final notifier = await lockedWhileStorageIsSlow();

        expect(await notifier.unlockWithPin('1234'), isTrue);
        expect(container.read(securityProvider).isLocked, isFalse);

        service.hasPinAnswer.complete(true);
        await pumpEventQueue();

        final state = container.read(securityProvider);
        expect(state.isLocked, isFalse);
        expect(state.hasPin, isTrue);
      });

      // The same when secure storage then fails: the failure path used to
      // lock from the has_pin mirror alone.
      test('a PIN unlock is not undone when storage then fails', () async {
        final notifier = await lockedWhileStorageIsSlow();
        expect(await notifier.unlockWithPin('1234'), isTrue);

        service.hasPinAnswer.completeError(
          PlatformException(code: 'READ_ERROR'),
        );
        await pumpEventQueue();

        final state = container.read(securityProvider);
        expect(state.isLocked, isFalse);
        expect(state.hasPin, isTrue);
      });

      test('without an unlock, a storage failure still locks', () async {
        await lockedWhileStorageIsSlow();

        service.hasPinAnswer.completeError(
          PlatformException(code: 'READ_ERROR'),
        );
        await pumpEventQueue();

        expect(container.read(securityProvider).isLocked, isTrue);
      });

      test('without an unlock, the start-up checks still lock', () async {
        await lockedWhileStorageIsSlow();

        service.hasPinAnswer.complete(true);
        await pumpEventQueue();

        expect(container.read(securityProvider).isLocked, isTrue);
      });

      test('a lock after that unlock is not undone either', () async {
        final notifier = await lockedWhileStorageIsSlow();
        expect(await notifier.unlockWithPin('1234'), isTrue);
        notifier.lockApp();

        service.hasPinAnswer.complete(true);
        await pumpEventQueue();

        expect(container.read(securityProvider).isLocked, isTrue);
      });

      test('lockApp after the start-up checks still locks', () async {
        final notifier = await lockedWhileStorageIsSlow();
        expect(await notifier.unlockWithPin('1234'), isTrue);
        service.hasPinAnswer.complete(true);
        await pumpEventQueue();

        notifier.lockApp();

        expect(container.read(securityProvider).isLocked, isTrue);
      });
    });
  });
}

/// A security service whose secure storage has not answered yet: hasPin()
/// waits for [hasPinAnswer]. The PIN is 1234.
class _HeldHasPinService extends SecurityService {
  _HeldHasPinService(super.secureStorage, super.localAuth, super.prefs);

  final hasPinAnswer = Completer<bool>();

  @override
  Future<bool> hasPin() => hasPinAnswer.future;

  @override
  Future<bool> verifyPin(String pin) async => pin == '1234';
}

/// A stopwatch that tests move by hand.
class _ManualStopwatch extends Stopwatch {
  Duration value = Duration.zero;

  @override
  Duration get elapsed => value;
}

/// Boot clock that tests move by hand.
class _FakeClock implements SecurityClock {
  Duration _boot = const Duration(seconds: 1000);

  /// Time passing, asleep or awake.
  void advance(Duration d) => _boot += d;

  @override
  Future<Duration> elapsed() async => _boot;

  @override
  bool get isBootClock => true;

  /// Auto-lock never reads it.
  @override
  DateTime wallTime() => DateTime.utc(2026, 10, 5);
}
