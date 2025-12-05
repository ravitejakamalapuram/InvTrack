import 'dart:async';
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

  AndroidOptions _getAndroidOptions() => const AndroidOptions(
        encryptedSharedPreferences: true,
      );

  IOSOptions _getIOSOptions() => const IOSOptions(
        accessibility: KeychainAccessibility.first_unlock,
      );

  Future<bool> hasPin() async {
    final pin = await _secureStorage.read(
      key: _pinKey,
      aOptions: _getAndroidOptions(),
      iOptions: _getIOSOptions(),
    );
    return pin != null;
  }

  Future<void> setPin(String pin) async {
    // In a real app, hash the PIN before storing.
    // For MVP/Demo, we store as is in secure storage.
    await _secureStorage.write(
      key: _pinKey,
      value: pin,
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
    return storedPin == pin;
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
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to unlock InvTracker',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (e) {
      print('Biometric auth error: $e');
      return false;
    }
  }

  bool get isBiometricEnabled => _prefs.getBool(_biometricEnabledKey) ?? false;

  Future<void> setBiometricEnabled(bool enabled) async {
    await _prefs.setBool(_biometricEnabledKey, enabled);
  }

  // --- Auto Lock ---

  int get autoLockDurationSeconds => _prefs.getInt(_autoLockDurationKey) ?? 0; // 0 = Immediate

  Future<void> setAutoLockDuration(int seconds) async {
    await _prefs.setInt(_autoLockDurationKey, seconds);
  }
}
