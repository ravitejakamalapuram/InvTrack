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
    return base64Url.encode(values);
  }

  /// Hash PIN using SHA-256 with optional salt
  /// Returns "hash" if no salt provided, or "salt:hash" if salt provided.
  String _hashPin(String pin, {String? salt}) {
    if (salt != null) {
      final bytes = utf8.encode(salt + pin);
      final digest = sha256.convert(bytes);
      return '$salt:$digest';
    }
    // Legacy unsalted hash
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    final hashedPin = _hashPin(pin, salt: salt);
    await _secureStorage.write(
      key: _pinKey,
      value: hashedPin,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
  }

  Future<bool> verifyPin(String pin) async {
    final storedPin = await _secureStorage.read(
      key: _pinKey,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );

    if (storedPin == null) return false;

    // Check if stored PIN is salted (contains ':')
    if (storedPin.contains(':')) {
      final parts = storedPin.split(':');
      if (parts.length != 2) return false; // Invalid format

      final salt = parts[0];
      // Recalculate hash with extracted salt
      final calculatedHash = _hashPin(pin, salt: salt);
      return calculatedHash == storedPin;
    }
    // Check if stored PIN is legacy unsalted hashed (SHA-256 is 64 chars hex)
    else if (storedPin.length == 64) {
      final hashedInput = _hashPin(pin);
      final isMatch = storedPin == hashedInput;
      if (isMatch) {
        // Upgrade to salted hash
        await setPin(pin);
      }
      return isMatch;
    } else {
      // Legacy support: stored PIN is plaintext
      final isMatch = storedPin == pin;
      if (isMatch) {
        // Upgrade to hashed storage
        await setPin(pin);
      }
      return isMatch;
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
        debugPrint('🔐 Biometrics not available on this device');
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
        persistAcrossBackgrounding: true, // Keep auth valid across app lifecycle changes
        sensitiveTransaction: false, // Don't require re-auth for app resume
      );

      debugPrint('🔐 Biometric auth result: $result');
      return result;
    } on PlatformException catch (e) {
      debugPrint('🔐 Biometric platform error: ${e.code} - ${e.message}');
      // Handle specific error codes
      if (e.code == 'NotAvailable' || e.code == 'NotEnrolled') {
        return false;
      }
      // For other errors (like user cancelled), just return false
      return false;
    } catch (e) {
      debugPrint('🔐 Biometric auth error: $e');
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
