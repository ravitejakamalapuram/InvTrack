import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/security/data/services/security_clock.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:local_auth/local_auth.dart';

import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

// Dependencies
final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  ),
);
final localAuthProvider = Provider((ref) => LocalAuthentication());
// sharedPreferencesProvider is imported from settings_provider.dart

/// Time source for auto-lock and the PIN lockout; see [SecurityClock].
final securityClockProvider = Provider<SecurityClock>((ref) => SecurityClock());

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(
    ref.watch(flutterSecureStorageProvider),
    ref.watch(localAuthProvider),
    ref.watch(sharedPreferencesProvider),
    ref.watch(securityClockProvider),
  );
});

/// True from a resume until the auto-lock check has decided. The check waits
/// for a [SecurityClock] reading, so the privacy cover stays up meanwhile:
/// no frame of the portfolio may show, or take taps, before the lock. Kept
/// out of [SecurityState] because the router rebuilds on every change there.
final autoLockCheckPendingProvider =
    NotifierProvider<AutoLockCheckPending, bool>(AutoLockCheckPending.new);

class AutoLockCheckPending extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool pending) => state = pending;
}

/// A [SecurityClock] reading, taken when it was asked for. Readings are
/// asynchronous; holding the future keeps their order even when the app
/// resumes before the pause reading has arrived.
typedef _ClockMark = Future<Duration>;

// State
class SecurityState {
  final bool isLocked;
  final bool hasPin;
  final bool isBiometricEnabled;
  final bool isBiometricAvailable;

  const SecurityState({
    this.isLocked = false,
    this.hasPin = false,
    this.isBiometricEnabled = false,
    this.isBiometricAvailable = false,
  });

  SecurityState copyWith({
    bool? isLocked,
    bool? hasPin,
    bool? isBiometricEnabled,
    bool? isBiometricAvailable,
  }) {
    return SecurityState(
      isLocked: isLocked ?? this.isLocked,
      hasPin: hasPin ?? this.hasPin,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      isBiometricAvailable: isBiometricAvailable ?? this.isBiometricAvailable,
    );
  }
}

class SecurityNotifier extends Notifier<SecurityState>
    with WidgetsBindingObserver {
  _ClockMark? _lastPausedTime;
  _ClockMark? _lastUnlockTime;
  Timer? _lockTimer;

  // Counts successful unlocks, so start-up checks that finish after one do
  // not lock the app again (A114).
  int _unlockCount = 0;

  // Secure storage failed with no has_pin mirror, so whether a PIN is set is
  // not known; the next resume reads storage again.
  bool _pinStateUnknown = false;

  // Counts auto-lock checks, so an older one that finishes late does not lift
  // the privacy cover while a newer one is still deciding.
  int _autoLockChecks = 0;

  // Grace period after unlock before auto-lock can trigger again
  // This prevents re-locking during app switches immediately after unlock
  static const Duration _unlockGracePeriod = Duration(seconds: 5);

  // Flag to temporarily suspend auto-lock during system picker operations
  // (camera, gallery, file picker) which take the app to background
  bool _isAutoLockSuspended = false;
  _ClockMark? _suspendedAt;

  @override
  SecurityState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _lockTimer?.cancel();
    });
    final hasPinMirror = _readHasPinMirror();
    _init(hasPinMirror);
    // Secure storage answers asynchronously, and the router draws this state
    // first. Trust the mirror until then; with no mirror the state is
    // unknown, which counts as locked, so no portfolio frame renders before
    // the lock.
    return SecurityState(
      hasPin: hasPinMirror ?? false,
      isLocked: hasPinMirror ?? true,
      isBiometricEnabled: _readBiometricEnabled(),
    );
  }

  SecurityService get _service => ref.read(securityServiceProvider);

  SecurityClock get _clock => ref.read(securityClockProvider);

  bool? _readHasPinMirror() {
    try {
      return _service.hasPinMirror;
    } catch (e) {
      LoggerService.warn('Could not read the PIN mirror', error: e);
      return null;
    }
  }

  bool _readBiometricEnabled() {
    try {
      return _service.isBiometricEnabled;
    } catch (e) {
      LoggerService.warn('Could not read the biometric setting', error: e);
      return false;
    }
  }

  _ClockMark _mark() => _clock.elapsed();

  /// Time between [mark] and [now], both [SecurityClock] readings. That
  /// clock counts deep sleep and cannot be changed by whoever holds the
  /// phone; the wall clock is not read at all. It never runs backwards, so a
  /// negative difference means it fell back to its stopwatch in between; that
  /// counts as long enough to lock.
  Duration _elapsedBetween(Duration mark, Duration now) {
    final elapsed = now - mark;
    return elapsed.isNegative ? const Duration(days: 3650) : elapsed;
  }

  Future<void> _init(bool? hasPinMirror) async {
    final unlocksBefore = _unlockCount;
    try {
      final hasPin = await _service.hasPin();
      final isBiometricEnabled = _service.isBiometricEnabled;

      // Biometric check can fail on emulators, so wrap in try-catch
      bool isBiometricAvailable = false;
      try {
        isBiometricAvailable = await _service.isBiometricAvailable();
      } catch (e) {
        // Biometrics not available (e.g., on emulator)
        isBiometricAvailable = false;
      }

      // Check if provider is still mounted before updating state
      if (!ref.mounted) return;

      state = state.copyWith(
        hasPin: hasPin,
        isBiometricEnabled: isBiometricEnabled,
        isBiometricAvailable: isBiometricAvailable,
        // Lock on startup if PIN exists, unless the user unlocked while
        // these checks ran (then keep whatever happened since).
        isLocked: hasPin && (_unlockCount == unlocksBefore || state.isLocked),
      );
    } catch (e) {
      // Secure storage failed. If a PIN was set, stay locked rather than
      // open the portfolio. With no mirror nobody knows whether one is set,
      // so stay locked too, and read storage again when the app resumes.
      LoggerService.warn('Security init failed', error: e);
      if (!ref.mounted) return;
      _pinStateUnknown = hasPinMirror == null;
      state = SecurityState(
        hasPin: hasPinMirror ?? false,
        isLocked:
            (hasPinMirror ?? true) &&
            (_unlockCount == unlocksBefore || state.isLocked),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedTime = _mark();
    } else if (state == AppLifecycleState.resumed) {
      if (_pinStateUnknown) {
        _pinStateUnknown = false;
        _init(_readHasPinMirror());
        return;
      }
      unawaited(_checkAutoLock());
    }
  }

  Future<void> _checkAutoLock() async {
    // Don't lock if no PIN or already locked
    if (!state.hasPin || state.isLocked) return;

    // Set before the first frame after the resume, cleared in the same
    // microtask as the lock, so the cover goes when the lock screen comes.
    final check = ++_autoLockChecks;
    final pending = ref.read(autoLockCheckPendingProvider.notifier)..set(true);
    try {
      await _decideAutoLock();
    } finally {
      // A newer check still deciding keeps the cover up.
      if (ref.mounted && check == _autoLockChecks) pending.set(false);
    }
  }

  Future<void> _decideAutoLock() async {
    try {
      // Decide on what the app knew when it resumed. The trusted clock answers
      // asynchronously, so read every time before deciding.
      final suspended = _isAutoLockSuspended;
      final suspendedMark = _suspendedAt;
      final unlockedMark = _lastUnlockTime;
      final pausedMark = _lastPausedTime;
      final now = await _clock.elapsed();
      final suspendedFor = suspendedMark == null
          ? null
          : _elapsedBetween(await suspendedMark, now);
      final sinceUnlock = unlockedMark == null
          ? null
          : _elapsedBetween(await unlockedMark, now);
      final away = pausedMark == null
          ? null
          : _elapsedBetween(await pausedMark, now);
      if (!ref.mounted || !state.hasPin || state.isLocked) return;

      // Check if auto-lock is suspended (e.g., during picker operations)
      if (suspended) {
        if (suspendedFor == null) {
          LoggerService.debug('Auto-lock suspended, skipping');
          return;
        }
        if (suspendedFor < const Duration(minutes: 5)) {
          LoggerService.debug(
            'Auto-lock suspended for picker operation, skipping',
          );
          return;
        }
        LoggerService.debug('Auto-lock suspension expired after 5 minutes');
        if (identical(_suspendedAt, suspendedMark)) {
          _isAutoLockSuspended = false;
          _suspendedAt = null;
        }
      }

      if (sinceUnlock != null && sinceUnlock < _unlockGracePeriod) {
        LoggerService.debug('Within unlock grace period, skipping auto-lock');
        return;
      }

      if (away != null) {
        final autoLockSeconds = _service.autoLockDurationSeconds;
        if (away.inSeconds >= autoLockSeconds) {
          LoggerService.info(
            'Auto-locking app',
            metadata: {
              'durationSeconds': away.inSeconds,
              'thresholdSeconds': autoLockSeconds,
            },
          );
          lockApp();
        }
      }
    } catch (e, st) {
      // A missing/untrusted clock must never weaken the privacy boundary.
      LoggerService.error(
        'Trusted security clock unavailable; locking app',
        metadata: {'errorType': e.runtimeType.toString()},
        error: e,
        stackTrace: st,
      );
      if (ref.mounted) lockApp();
    }
  }

  void lockApp() {
    state = state.copyWith(isLocked: true);
  }

  void _onSuccessfulUnlock() {
    _unlockCount++;
    _lastUnlockTime = _mark();
    _lastPausedTime = null; // Reset pause time to prevent immediate re-lock
    state = state.copyWith(isLocked: false);
  }

  Future<bool> unlockWithPin(String pin) async {
    final isValid = await _service.verifyPin(pin);
    if (isValid) {
      _onSuccessfulUnlock();
    }
    return isValid;
  }

  Future<bool> unlockWithBiometrics() async {
    if (!state.isBiometricEnabled) return false;

    final isAuthenticated = await _service.authenticateWithBiometrics();
    if (isAuthenticated) {
      _onSuccessfulUnlock();
    }
    return isAuthenticated;
  }

  Future<void> setPin(String pin) async {
    await _service.setPin(pin);
    state = state.copyWith(hasPin: true, isLocked: false);

    // Track analytics
    ref.read(analyticsServiceProvider).logSecurityEnabled(method: 'passcode');
  }

  Future<void> removePin() async {
    await _service.removePin();
    state = state.copyWith(
      hasPin: false,
      isLocked: false,
      isBiometricEnabled: false,
    );

    // Track analytics
    ref.read(analyticsServiceProvider).logSecurityDisabled();
  }

  Future<void> toggleBiometrics(bool enabled) async {
    if (enabled) {
      // Verify biometrics before enabling
      final success = await _service.authenticateWithBiometrics();
      if (success) {
        await _service.setBiometricEnabled(true);
        state = state.copyWith(isBiometricEnabled: true);

        // Track analytics
        ref
            .read(analyticsServiceProvider)
            .logSecurityEnabled(method: 'biometric');
      }
    } else {
      await _service.setBiometricEnabled(false);
      state = state.copyWith(isBiometricEnabled: false);
      // Note: We don't track biometric disable separately since it's a secondary auth method
    }
  }

  /// Temporarily suspends auto-lock to allow system picker operations
  /// (camera, gallery, file picker) that take the app to background.
  ///
  /// Call [resumeAutoLock] when the picker operation completes.
  /// Auto-lock will automatically resume after 5 minutes as a safety measure.
  void suspendAutoLock() {
    LoggerService.debug('Suspending auto-lock for picker operation');
    _isAutoLockSuspended = true;
    _suspendedAt = _mark();
    // Reset pause time so we don't accumulate background time
    _lastPausedTime = null;
  }

  /// Resumes auto-lock after a system picker operation completes.
  ///
  /// This should be called after [suspendAutoLock] when the picker
  /// operation is complete (whether successful or cancelled).
  void resumeAutoLock() {
    LoggerService.debug('Resuming auto-lock after picker operation');
    _isAutoLockSuspended = false;
    _suspendedAt = null;
    // Reset pause time to current time so we don't immediately lock
    _lastPausedTime = _mark();
  }
}

final securityProvider = NotifierProvider<SecurityNotifier, SecurityState>(
  SecurityNotifier.new,
);
