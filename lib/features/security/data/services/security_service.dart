import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/utils/security_utils.dart';
import 'package:inv_tracker/features/security/data/services/security_clock.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When a failed-PIN lockout began: a [SecurityClock] reading, which clock
/// gave it ('boot' or 'stopwatch'), and the device clock in milliseconds.
/// Older versions stored the device clock alone (no source, no reading).
typedef _LockoutStart = ({String? source, int? clockMs, int wallMs});
typedef _ClockNow = ({String source, int clockMs, int wallMs});

class SecurityService {
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;
  final SharedPreferences _prefs;
  final SecurityClock _clock;

  static const String _pinKey = 'user_pin';
  static const String _hasPinMirrorKey = 'has_pin';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _autoLockDurationKey = 'auto_lock_duration';
  static const String _failedAttemptsKey = 'pin_failed_attempts';
  // When the lockout began, as "<source>:<reading ms>:<device clock ms>".
  static const String _lockoutTimestampKey = 'pin_lockout_timestamp';
  static const int _maxAttempts = 5;
  static const int _lockoutDurationSeconds = 900; // 15 minutes

  bool _isVerifying = false;
  Future<bool>? _hasPinFuture;

  SecurityService(
    this._secureStorage,
    this._localAuth,
    this._prefs, [
    SecurityClock? clock,
  ]) : _clock = clock ?? SecurityClock();

  // --- PIN Management ---

  // Security: Android uses Keystore for encryption via FlutterSecureStorage.
  // Data will be automatically migrated from SharedPreferences (legacy) on first access.
  AndroidOptions _getAndroidOptions() => const AndroidOptions();

  IOSOptions _getIOSOptions() =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  Future<bool> hasPin() {
    _hasPinFuture ??= _hasPinInternal().whenComplete(
      () => _hasPinFuture = null,
    );
    return _hasPinFuture!;
  }

  /// Whether a PIN is set, as last seen. Unlike [hasPin] it is read
  /// synchronously, so the app's first frame can already be the lock screen.
  /// Null when not known yet (first start after an update or a data clear).
  bool? get hasPinMirror => _prefs.getBool(_hasPinMirrorKey);

  Future<bool> _hasPinInternal() async {
    final hasPin = await _readHasPin();
    await _prefs.setBool(_hasPinMirrorKey, hasPin);
    return hasPin;
  }

  Future<bool> _readHasPin() async {
    // Check Secure Storage first
    final pin = await _secureStorage.read(
      key: _pinKey,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    if (pin != null && pin.isNotEmpty) {
      // Cleanup legacy even if secure storage has PIN
      if (_prefs.containsKey(_pinKey)) {
        await _prefs.remove(_pinKey);
      }
      return true;
    }

    // Fallback/Migrate from SharedPreferences
    final legacyPin = _prefs.getString(_pinKey);
    if (legacyPin != null && legacyPin.isNotEmpty) {
      // Migrate to Secure Storage
      await _secureStorage.write(
        key: _pinKey,
        value: legacyPin,
        aOptions: _getAndroidOptions(),
        iOptions: _getIOSOptions(),
      );
      // Cleanup legacy
      await _prefs.remove(_pinKey);
      return true;
    }

    return false;
  }

  /// Generate a random 16-byte salt
  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64.encode(values);
  }

  /// Hash PIN using SHA-256 (Legacy unsalted)
  String _hashPinLegacy(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    // Use PBKDF2 with 100,000 iterations (v3 format: salt:iterations:hash)
    final hashedPin = SecurityUtils.hashPin(pin, salt, iterations: 100000);
    // Mirror first: if the app dies between the two writes, the next start
    // shows the lock instead of the portfolio.
    await _prefs.setBool(_hasPinMirrorKey, true);
    await _secureStorage.write(
      key: _pinKey,
      value: hashedPin,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    await _clearRateLimit();
  }

  // --- Rate Limiting Helpers ---

  /// Get failed attempts from secure storage (migrating from prefs if needed)
  Future<int> _getFailedAttempts() async {
    // Check Secure Storage first
    final stored = await _secureStorage.read(
      key: _failedAttemptsKey,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    if (stored != null) {
      return int.tryParse(stored) ?? 0;
    }

    // Fallback/Migrate from SharedPreferences
    final legacy = _prefs.getInt(_failedAttemptsKey);
    if (legacy != null) {
      // Migrate to Secure Storage
      await _setFailedAttempts(legacy);
      // Cleanup legacy is handled in _setFailedAttempts
      return legacy;
    }
    return 0;
  }

  /// Set failed attempts to secure storage
  Future<void> _setFailedAttempts(int attempts) async {
    await _secureStorage.write(
      key: _failedAttemptsKey,
      value: attempts.toString(),
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    // Ensure legacy is cleaned up
    if (_prefs.containsKey(_failedAttemptsKey)) {
      await _prefs.remove(_failedAttemptsKey);
    }
  }

  /// Get lockout timestamp from secure storage (migrating from prefs if needed)
  Future<String?> _getLockoutTimestamp() async {
    // Check Secure Storage first
    final stored = await _secureStorage.read(
      key: _lockoutTimestampKey,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    if (stored != null) return stored;

    // Fallback/Migrate from SharedPreferences
    final legacy = _prefs.getInt(_lockoutTimestampKey);
    if (legacy != null) {
      // Migrate
      await _setLockoutTimestamp('$legacy');
      // Cleanup legacy is handled in _setLockoutTimestamp
      return '$legacy';
    }
    return null;
  }

  /// Set lockout timestamp to secure storage
  Future<void> _setLockoutTimestamp(String timestamp) async {
    await _secureStorage.write(
      key: _lockoutTimestampKey,
      value: timestamp,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    // Ensure legacy is cleaned up
    if (_prefs.containsKey(_lockoutTimestampKey)) {
      await _prefs.remove(_lockoutTimestampKey);
    }
  }

  /// Clear all rate limiting data
  Future<void> _clearRateLimit() async {
    await _secureStorage.delete(
      key: _failedAttemptsKey,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    await _secureStorage.delete(
      key: _lockoutTimestampKey,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    // Also clear legacy just in case
    if (_prefs.containsKey(_failedAttemptsKey)) {
      await _prefs.remove(_failedAttemptsKey);
    }
    if (_prefs.containsKey(_lockoutTimestampKey)) {
      await _prefs.remove(_lockoutTimestampKey);
    }
  }

  Future<_ClockNow> _clockNow() async {
    final reading = await _clock.elapsed();
    return (
      source: _clock.isBootClock ? 'boot' : 'stopwatch',
      clockMs: reading.inMilliseconds,
      wallMs: _clock.wallTime().millisecondsSinceEpoch,
    );
  }

  static String _encodeLockoutStart(_ClockNow start) =>
      '${start.source}:${start.clockMs}:${start.wallMs}';

  static _LockoutStart? _decodeLockoutStart(String stored) {
    final parts = stored.split(':');
    if (parts.length == 3) {
      final clockMs = int.tryParse(parts[1]);
      final wallMs = int.tryParse(parts[2]);
      if (clockMs == null || wallMs == null) return null;
      return (source: parts[0], clockMs: clockMs, wallMs: wallMs);
    }
    final wallMs = int.tryParse(stored);
    return wallMs == null
        ? null
        : (source: null, clockMs: null, wallMs: wallMs);
  }

  /// Seconds left of the failed-PIN lockout, or null when there is none.
  ///
  /// Measured on [SecurityClock], so changing the device clock cannot end it
  /// early. That clock cannot judge a start from before a phone restart (it
  /// restarts at zero), from its stopwatch fallback, or from an older version
  /// (which stored the device clock alone). After a phone restart only the
  /// time since the restart counts. For a stopwatch or older start the
  /// device clock judges it, once. Either way an ended lockout is cleared,
  /// and the rest of a running one is timed on [SecurityClock] again. A
  /// start ahead of the device clock restarts the lockout rather than end it
  /// early, and so does a stopwatch start after the app restarted.
  Future<int?> getLockoutRemainingSeconds() async {
    final stored = await _getLockoutTimestamp();
    final start = stored == null ? null : _decodeLockoutStart(stored);

    // The attempt counter is itself a security boundary. If five or more
    // failures were durably recorded but the timestamp could not be written
    // (for example, storage failed between the two writes), never treat the
    // missing timestamp as "no lockout". Keep the account locked until a
    // trusted lockout record can be established or rate limiting is explicitly
    // cleared by a successful biometric/PIN reset.
    if (start == null) {
      final failedAttempts = await _getFailedAttempts();
      if (failedAttempts >= _maxAttempts) {
        return _lockoutDurationSeconds;
      }
      return null;
    }

    final now = await _clockNow();
    final startClockMs = start.clockMs;
    final int servedMs;
    if (start.source == now.source &&
        startClockMs != null &&
        startClockMs <= now.clockMs) {
      servedMs = now.clockMs - startClockMs;
    } else {
      // Not when both readings came from the stopwatch: it restarts with the
      // app, which whoever holds the phone can do at will.
      final bothStopwatch =
          start.source == 'stopwatch' && now.source == 'stopwatch';
      // Boot clock behind the start: the phone restarted after the lockout
      // began. The time since the restart is a lower bound on the time
      // served, and the device clock, which whoever holds the phone can
      // set, is not trusted.
      final restarted = start.source == 'boot' && now.source == 'boot';
      servedMs = bothStopwatch
          ? 0
          : restarted
          ? now.clockMs
          : max(0, now.wallMs - start.wallMs);
      if (servedMs < _lockoutDurationSeconds * 1000) {
        await _setLockoutTimestamp(
          _encodeLockoutStart((
            source: now.source,
            clockMs: now.clockMs - servedMs,
            wallMs: now.wallMs - servedMs,
          )),
        );
      }
    }
    final served = servedMs ~/ 1000;

    if (served < _lockoutDurationSeconds) {
      return _lockoutDurationSeconds - served;
    } else {
      // Lockout expired, reset attempts
      await _clearRateLimit();
      return null;
    }
  }

  Future<bool> verifyPin(String pin) async {
    if (_isVerifying) return false;
    _isVerifying = true;

    try {
      // Check lockout first
      final remainingLockout = await getLockoutRemainingSeconds();
      if (remainingLockout != null) {
        return false; // Still locked out
      }

      final storedPin = await _secureStorage.read(
        key: _pinKey,
        aOptions: _getAndroidOptions(),
        iOptions: _getIOSOptions(),
      );

      if (storedPin == null) return false;

      bool isMatch = false;
      bool needsUpgrade = false;

      // v3: PBKDF2 (contains 2 colons 'salt:iterations:hash')
      if (storedPin.split(':').length == 3) {
        isMatch = SecurityUtils.verifyPin(pin, storedPin);
        if (isMatch) {
          final parts = storedPin.split(':');
          final iterations = int.tryParse(parts[1]) ?? 0;
          if (iterations < 100000) {
            needsUpgrade = true;
          }
        }
      }
      // v2: Salted Hash (contains 1 colon 'salt:hash')
      else if (storedPin.contains(':')) {
        final parts = storedPin.split(':');
        if (parts.length == 2) {
          final salt = parts[0];
          final expectedHash = parts[1];
          // Re-hash input with extracted salt (Legacy SHA-256)
          final bytes = utf8.encode(pin + salt);
          final actualHash = sha256.convert(bytes).toString();
          isMatch = SecurityUtils.constantTimeEquals(actualHash, expectedHash);
          if (isMatch) needsUpgrade = true;
        }
      }
      // v1: Unsalted Hash (SHA-256 is 64 chars hex)
      else if (storedPin.length == 64) {
        final hashedInput = _hashPinLegacy(pin);
        isMatch = SecurityUtils.constantTimeEquals(storedPin, hashedInput);
        if (isMatch) needsUpgrade = true;
      }
      // v0: Plaintext (Legacy)
      else {
        // Hash both to ensure constant time comparison (prevent length leaks)
        const fixedSalt = 'legacy_pin_verification_salt';
        final storedHash = SecurityUtils.hashPin(
          storedPin,
          fixedSalt,
          iterations: 1000,
        );
        final inputHash = SecurityUtils.hashPin(
          pin,
          fixedSalt,
          iterations: 1000,
        );

        isMatch = SecurityUtils.constantTimeEquals(storedHash, inputHash);
        if (isMatch) needsUpgrade = true;
      }

      if (isMatch) {
        // Reset failed attempts on success
        await _clearRateLimit();

        if (needsUpgrade) {
          await setPin(pin); // Upgrade to PBKDF2
        }
        return true;
      } else {
        // Handle failure
        int failedAttempts = (await _getFailedAttempts()) + 1;
        await _setFailedAttempts(failedAttempts);

        if (failedAttempts >= _maxAttempts) {
          await _setLockoutTimestamp(_encodeLockoutStart(await _clockNow()));
        }
        return false;
      }
    } finally {
      _isVerifying = false;
    }
  }

  Future<void> removePin() async {
    try {
      await _clearRateLimit();
      await _secureStorage.delete(
        key: _pinKey,
        aOptions: _getAndroidOptions(),
        iOptions: _getIOSOptions(),
      );
      // Only once the PIN is gone, so the mirror never says "no PIN" while
      // one is still set.
      await _prefs.setBool(_hasPinMirrorKey, false);
    } finally {
      // Always disable biometrics even if PIN removal fails
      await setBiometricEnabled(false);
    }
  }

  // --- Biometrics ---

  Future<bool> isBiometricAvailable() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    return canCheck && isDeviceSupported;
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      // Check if biometrics are available before attempting auth
      final isAvailable = await isBiometricAvailable();
      if (!isAvailable) {
        LoggerService.debug('Biometrics not available on this device');
        return false;
      }

      // Cancel any existing authentication sessions first
      // This prevents stale auth dialogs from causing issues
      await _localAuth.stopAuthentication();

      // local_auth 3.0.0 API: parameters are now direct instead of AuthenticationOptions
      // - biometricOnly: only allow biometric auth (no PIN/pattern fallback)
      // - persistAcrossBackgrounding (stickyAuth): keep auth valid across app lifecycle changes
      // - sensitiveTransaction: whether this is a sensitive transaction
      final result = await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock InvTracker',
        biometricOnly: true,
        persistAcrossBackgrounding:
            true, // Keep auth valid across app lifecycle changes
        sensitiveTransaction: false, // Don't require re-auth for app resume
      );

      LoggerService.debug(
        'Biometric auth result',
        metadata: {'result': result},
      );
      if (result) {
        // The owner proved who they are, so an old failed-PIN lockout must
        // not come back, after a phone restart for example.
        try {
          await _clearRateLimit();
        } catch (e) {
          LoggerService.warn(
            'Could not clear the PIN lockout',
            metadata: {'errorType': e.runtimeType.toString()},
          );
        }
      }
      return result;
    } on PlatformException catch (e) {
      LoggerService.warn(
        'Biometric platform error',
        error: e,
        metadata: {'code': e.code, 'message': e.message},
      );
      // Handle specific error codes
      if (e.code == 'NotAvailable' || e.code == 'NotEnrolled') {
        return false;
      }
      // For other errors (like user cancelled), just return false
      return false;
    } catch (e) {
      LoggerService.warn('Biometric auth error', error: e);
      return false;
    }
  }

  bool get isBiometricEnabled => _prefs.getBool(_biometricEnabledKey) ?? false;

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_biometricEnabledKey, enabled);
  }

  // --- Auto Lock ---

  int get autoLockDurationSeconds =>
      _prefs.getInt(_autoLockDurationKey) ?? 0; // 0 = Immediate

  Future<void> setAutoLockDuration(int seconds) async {
    await _prefs.setInt(_autoLockDurationKey, seconds);
  }
}
