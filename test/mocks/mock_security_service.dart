import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_platform_interface/types/auth_messages.dart';
import 'package:mocktail/mocktail.dart';

/// Mock implementation of LocalAuthentication for testing.
class MockLocalAuthentication extends Mock implements LocalAuthentication {}

/// Fake implementation of FlutterSecureStorage for testing.
class FakeFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};

  FakeFlutterSecureStorage() : super();

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }

  /// Reset storage for test isolation
  void reset() {
    _storage.clear();
  }

  /// Get current storage contents for assertions
  Map<String, String> get storage => Map.unmodifiable(_storage);
}

/// Fake implementation of LocalAuthentication for testing.
/// Allows fine-grained control over biometric auth behavior.
class FakeLocalAuthentication implements LocalAuthentication {
  bool canCheckBiometricsValue = true;
  bool isDeviceSupportedValue = true;
  bool authenticateResult = true;
  bool shouldThrowPlatformException = false;
  String platformExceptionCode = 'NotAvailable';
  String platformExceptionMessage = 'Biometrics not available';
  bool shouldThrowGenericException = false;
  int stopAuthenticationCallCount = 0;
  int authenticateCallCount = 0;

  void reset() {
    canCheckBiometricsValue = true;
    isDeviceSupportedValue = true;
    authenticateResult = true;
    shouldThrowPlatformException = false;
    platformExceptionCode = 'NotAvailable';
    platformExceptionMessage = 'Biometrics not available';
    shouldThrowGenericException = false;
    stopAuthenticationCallCount = 0;
    authenticateCallCount = 0;
  }

  @override
  Future<bool> get canCheckBiometrics async => canCheckBiometricsValue;

  @override
  Future<bool> isDeviceSupported() async => isDeviceSupportedValue;

  @override
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (canCheckBiometricsValue && isDeviceSupportedValue) {
      return [BiometricType.fingerprint, BiometricType.face];
    }
    return [];
  }

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<AuthMessages> authMessages = const <AuthMessages>[],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    authenticateCallCount++;
    debugPrint(
      '🔐 FakeLocalAuth: authenticate called (call #$authenticateCallCount)',
    );

    if (shouldThrowPlatformException) {
      throw PlatformException(
        code: platformExceptionCode,
        message: platformExceptionMessage,
      );
    }

    if (shouldThrowGenericException) {
      throw Exception('Generic biometric error');
    }

    return authenticateResult;
  }

  @override
  Future<bool> stopAuthentication() async {
    stopAuthenticationCallCount++;
    debugPrint(
      '🔐 FakeLocalAuth: stopAuthentication called (call #$stopAuthenticationCallCount)',
    );
    return true;
  }
}

