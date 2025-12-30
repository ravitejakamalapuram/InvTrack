import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:local_auth/local_auth.dart';

import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

// Dependencies
final flutterSecureStorageProvider = Provider(
  (ref) => const FlutterSecureStorage(),
);
final localAuthProvider = Provider((ref) => LocalAuthentication());
// sharedPreferencesProvider is imported from settings_provider.dart

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService(
    ref.watch(flutterSecureStorageProvider),
    ref.watch(localAuthProvider),
    ref.watch(sharedPreferencesProvider),
  );
});

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
  DateTime? _lastPausedTime;
  DateTime? _lastUnlockTime;
  Timer? _lockTimer;

  // Grace period after unlock before auto-lock can trigger again
  // This prevents re-locking during app switches immediately after unlock
  static const Duration _unlockGracePeriod = Duration(seconds: 5);

  @override
  SecurityState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _lockTimer?.cancel();
    });
    _init();
    return const SecurityState();
  }

  SecurityService get _service => ref.read(securityServiceProvider);

  Future<void> _init() async {
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
        isLocked: hasPin, // Lock on startup if PIN exists
      );
    } catch (e) {
      // If initialization fails, just use default state
      if (!ref.mounted) return;
      state = const SecurityState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      _checkAutoLock();
    }
  }

  void _checkAutoLock() {
    // Don't lock if no PIN or already locked
    if (!state.hasPin || state.isLocked) return;

    // Check if we're within the grace period after a successful unlock
    // This prevents the biometric dialog dismissal from triggering a re-lock
    if (_lastUnlockTime != null) {
      final timeSinceUnlock = DateTime.now().difference(_lastUnlockTime!);
      if (timeSinceUnlock < _unlockGracePeriod) {
        debugPrint('🔐 Within unlock grace period, skipping auto-lock');
        return;
      }
    }

    if (_lastPausedTime != null) {
      final duration = DateTime.now().difference(_lastPausedTime!);
      final autoLockSeconds = _service.autoLockDurationSeconds;

      if (duration.inSeconds >= autoLockSeconds) {
        debugPrint('🔐 Auto-locking app after ${duration.inSeconds}s (threshold: ${autoLockSeconds}s)');
        lockApp();
      }
    }
  }

  void lockApp() {
    state = state.copyWith(isLocked: true);
  }

  void _onSuccessfulUnlock() {
    _lastUnlockTime = DateTime.now();
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
  }

  Future<void> removePin() async {
    await _service.removePin();
    state = state.copyWith(
      hasPin: false,
      isLocked: false,
      isBiometricEnabled: false,
    );
  }

  Future<void> toggleBiometrics(bool enabled) async {
    if (enabled) {
      // Verify biometrics before enabling
      final success = await _service.authenticateWithBiometrics();
      if (success) {
        await _service.setBiometricEnabled(true);
        state = state.copyWith(isBiometricEnabled: true);
      }
    } else {
      await _service.setBiometricEnabled(false);
      state = state.copyWith(isBiometricEnabled: false);
    }
  }
}

final securityProvider = NotifierProvider<SecurityNotifier, SecurityState>(
  SecurityNotifier.new,
);
