import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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

  SecurityService(this._secureStorage, this._localAuth, this._prefs);

  // --- PIN Management ---

  AndroidOptions _getAndroidOptions() => const AndroidOptions();

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

  /// Hash PIN using SHA-256 with salt
  /// Returns string in format: salt:hash
  String _hashPinWithSalt(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return '$salt:${digest.toString()}';
  }

  /// Hash PIN using SHA-256 (Legacy unsalted)
  String _hashPinLegacy(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hashedPin = _hashPinWithSalt(pin, salt);
    await _secureStorage.write(
      key: _pinKey,
      value: hashedPin,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
  }

  Future<int?> getLockoutRemainingSeconds() async {
    final lockoutTimestamp = _prefs.getInt(_lockoutTimestampKey);
    if (lockoutTimestamp == null) return null;

    final lockoutTime = DateTime.fromMillisecondsSinceEpoch(lockoutTimestamp);
    final now = DateTime.now();
    final difference = now.difference(lockoutTime).inSeconds;

    if (difference < _lockoutDurationSeconds) {
      return _lockoutDurationSeconds - difference;
    } else {
      // Lockout expired, reset attempts
      await _prefs.remove(_lockoutTimestampKey);
      await _prefs.remove(_failedAttemptsKey);
      return null;
    }
  }

  Future<bool> verifyPin(String pin) async {
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

    // v2: Salted Hash (contains ':')
    if (storedPin.contains(':')) {
      final parts = storedPin.split(':');
      if (parts.length == 2) {
        final salt = parts[0];
        final expectedHash = parts[1];
        // Re-hash input with extracted salt
        final bytes = utf8.encode(pin + salt);
        final actualHash = sha256.convert(bytes).toString();
        isMatch = actualHash == expectedHash;
      }
    }
    // v1: Unsalted Hash (SHA-256 is 64 chars hex)
    else if (storedPin.length == 64) {
      final hashedInput = _hashPinLegacy(pin);
      isMatch = storedPin == hashedInput;
      if (isMatch) {
        await setPin(pin); // Upgrade
      }
    }
    // v0: Plaintext (Legacy)
    else {
      isMatch = storedPin == pin;
      if (isMatch) {
        await setPin(pin); // Upgrade
      }
    }

    if (isMatch) {
      // Reset failed attempts on success
      await _prefs.remove(_failedAttemptsKey);
      await _prefs.remove(_lockoutTimestampKey);
      return true;
    } else {
      // Handle failure
      int failedAttempts = (_prefs.getInt(_failedAttemptsKey) ?? 0) + 1;
      await _prefs.setInt(_failedAttemptsKey, failedAttempts);

      if (failedAttempts >= _maxAttempts) {
        await _prefs.setInt(
          _lockoutTimestampKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      return false;
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
        if (kDebugMode) {
          debugPrint('🔐 Biometrics not available on this device');
        }
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

      if (kDebugMode) {
        debugPrint('🔐 Biometric auth result: $result');
      }
      return result;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 Biometric platform error: ${e.code} - ${e.message}');
      }
      // Handle specific error codes
      if (e.code == 'NotAvailable' || e.code == 'NotEnrolled') {
        return false;
      }
      // For other errors (like user cancelled), just return false
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔐 Biometric auth error: $e');
      }
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
