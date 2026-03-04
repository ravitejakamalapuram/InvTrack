import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/utils/security_utils.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuth;
  final SharedPreferences _prefs;

  static const String _pinKey = 'user_pin';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _autoLockDurationKey = 'auto_lock_duration';
  static const String _failedAttemptsKey = 'pin_failed_attempts';
  static const String _lockoutTimestampKey = 'pin_lockout_timestamp';
  static const int _maxAttempts = 5;
  static const int _lockoutDurationSeconds = 900; // 15 minutes

  bool _isVerifying = false;

  SecurityService(this._secureStorage, this._localAuth, this._prefs);

  // --- PIN Management ---

  AndroidOptions _getAndroidOptions() => const AndroidOptions(encryptedSharedPreferences: true);

  IOSOptions _getIOSOptions() =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  Future<bool> hasPin() async {
    final pin = await _secureStorage.read(
      key: _pinKey,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    return pin != null;
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
    await _secureStorage.write(
      key: _pinKey,
      value: hashedPin,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
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
  Future<int?> _getLockoutTimestamp() async {
    // Check Secure Storage first
    final stored = await _secureStorage.read(
      key: _lockoutTimestampKey,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    if (stored != null) {
      return int.tryParse(stored);
    }

    // Fallback/Migrate from SharedPreferences
    final legacy = _prefs.getInt(_lockoutTimestampKey);
    if (legacy != null) {
      // Migrate
      await _setLockoutTimestamp(legacy);
      // Cleanup legacy is handled in _setLockoutTimestamp
      return legacy;
    }
    return null;
  }

  /// Set lockout timestamp to secure storage
  Future<void> _setLockoutTimestamp(int timestamp) async {
    await _secureStorage.write(
      key: _lockoutTimestampKey,
      value: timestamp.toString(),
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

  Future<int?> getLockoutRemainingSeconds() async {
    final lockoutTimestamp = await _getLockoutTimestamp();
    if (lockoutTimestamp == null) return null;

    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutTimestamp);
    final now = DateTime.now();
    final difference = now.difference(lockoutTime).inSeconds;

    if (difference < _lockoutDurationSeconds) {
      return _lockoutDurationSeconds - difference;
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
        final storedHash = _hashPinLegacy(storedPin + fixedSalt);
        final inputHash = _hashPinLegacy(pin + fixedSalt);

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
          await _setLockoutTimestamp(DateTime.now().millisecondsSinceEpoch);
        }
        return false;
      }
    } finally {
      _isVerifying = false;
    }
  }

  Future<void> removePin() async {
    await _secureStorage.delete(
      key: _pinKey,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    await setBiometricEnabled(false); // Disable biometrics if PIN is removed
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

      LoggerService.debug('Biometric auth result', metadata: {'result': result});
      return result;
    } on PlatformException catch (e) {
      LoggerService.warn('Biometric platform error', error: e, metadata: {
        'code': e.code,
        'message': e.message,
      });
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
