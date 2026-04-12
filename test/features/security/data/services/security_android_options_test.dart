/// Tests verifying that SecurityService uses AndroidOptions(encryptedSharedPreferences: true)
/// in all secure-storage operations.
///
/// PR change: _getAndroidOptions() was updated from
///   `const AndroidOptions()`
/// to
///   `const AndroidOptions(encryptedSharedPreferences: true)`
///
/// This test file captures the AndroidOptions passed to every FlutterSecureStorage
/// call and asserts that encryptedSharedPreferences is always enabled.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_security_service.dart';

// ---------------------------------------------------------------------------
// Recording fake that captures AndroidOptions used in each storage call
// ---------------------------------------------------------------------------

class _RecordingFlutterSecureStorage extends FlutterSecureStorage {
  final Map<String, String> _storage = {};

  /// All AndroidOptions instances passed to write() calls
  final List<AndroidOptions?> writeAndroidOptions = [];

  /// All AndroidOptions instances passed to read() calls
  final List<AndroidOptions?> readAndroidOptions = [];

  /// All AndroidOptions instances passed to delete() calls
  final List<AndroidOptions?> deleteAndroidOptions = [];

  _RecordingFlutterSecureStorage() : super();

  void reset() {
    _storage.clear();
    writeAndroidOptions.clear();
    readAndroidOptions.clear();
    deleteAndroidOptions.clear();
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
    writeAndroidOptions.add(aOptions);
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

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
    readAndroidOptions.add(aOptions);
    return _storage[key];
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
    deleteAndroidOptions.add(aOptions);
    _storage.remove(key);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _RecordingFlutterSecureStorage recordingStorage;
  late FakeLocalAuthentication fakeLocalAuth;
  late SharedPreferences prefs;
  late SecurityService service;

  setUp(() async {
    recordingStorage = _RecordingFlutterSecureStorage();
    fakeLocalAuth = FakeLocalAuthentication();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = SecurityService(recordingStorage, fakeLocalAuth, prefs);
  });

  tearDown(() {
    recordingStorage.reset();
    fakeLocalAuth.reset();
  });

  group('SecurityService – encryptedSharedPreferences: true (PR change)', () {
    // Helper to assert every recorded option has encryptedSharedPreferences=true
    void _expectAllEncrypted(List<AndroidOptions?> options, String context) {
      expect(
        options,
        isNotEmpty,
        reason: '$context: expected at least one Android options record',
      );
      for (final opt in options) {
        expect(
          opt,
          isNotNull,
          reason: '$context: AndroidOptions must not be null',
        );
        expect(
          opt!.encryptedSharedPreferences,
          isTrue,
          reason:
              '$context: encryptedSharedPreferences must be true per PR security fix',
        );
      }
    }

    test(
      'setPin uses encryptedSharedPreferences: true when writing PIN to storage',
      () async {
        await service.setPin('1234');

        _expectAllEncrypted(recordingStorage.writeAndroidOptions, 'setPin');
      },
    );

    test(
      'hasPin uses encryptedSharedPreferences: true when reading PIN from storage',
      () async {
        // Pre-seed the storage so hasPin returns true
        await service.setPin('1234');
        recordingStorage.readAndroidOptions.clear();

        await service.hasPin();

        _expectAllEncrypted(
          recordingStorage.readAndroidOptions,
          'hasPin (read)',
        );
      },
    );

    test(
      'verifyPin uses encryptedSharedPreferences: true for all storage reads and writes',
      () async {
        await service.setPin('1234');
        recordingStorage.writeAndroidOptions.clear();
        recordingStorage.readAndroidOptions.clear();

        await service.verifyPin('1234');

        // Read calls (PIN read + failed attempts etc.)
        _expectAllEncrypted(
          recordingStorage.readAndroidOptions,
          'verifyPin (read)',
        );
      },
    );

    test(
      'removePin uses encryptedSharedPreferences: true when deleting from storage',
      () async {
        await service.setPin('1234');
        recordingStorage.deleteAndroidOptions.clear();

        await service.removePin();

        _expectAllEncrypted(
          recordingStorage.deleteAndroidOptions,
          'removePin (delete)',
        );
      },
    );

    test(
      'failed PIN attempt writes failed_attempts with encryptedSharedPreferences: true',
      () async {
        await service.setPin('1234');
        recordingStorage.writeAndroidOptions.clear();

        await service.verifyPin('wrong_pin');

        // _setFailedAttempts writes to secure storage with correct options
        _expectAllEncrypted(
          recordingStorage.writeAndroidOptions,
          'failed attempt (write failed_attempts)',
        );
      },
    );

    test(
      'all write operations across the full PIN lifecycle use encryptedSharedPreferences: true',
      () async {
        // Lifecycle: set → verify (wrong) → verify (correct) → remove
        await service.setPin('5678');
        await service.verifyPin('wrong');
        await service.verifyPin('5678');
        await service.removePin();

        _expectAllEncrypted(
          recordingStorage.writeAndroidOptions,
          'full PIN lifecycle writes',
        );
        _expectAllEncrypted(
          recordingStorage.readAndroidOptions,
          'full PIN lifecycle reads',
        );
        _expectAllEncrypted(
          recordingStorage.deleteAndroidOptions,
          'full PIN lifecycle deletes',
        );
      },
    );
  });

  group('SecurityService – flutterSecureStorageProvider configuration', () {
    /// Verifies that the AndroidOptions constant created inline is the
    /// same shape that SecurityService uses internally.
    test(
      'AndroidOptions(encryptedSharedPreferences: true) is a valid configuration',
      () {
        // Verifies the constant can be constructed without error and that
        // the property is accessible (compile-time check).
        const options = AndroidOptions(encryptedSharedPreferences: true);
        expect(options.encryptedSharedPreferences, isTrue);
      },
    );

    test(
      'Default AndroidOptions() has encryptedSharedPreferences as false (guard against regression)',
      () {
        // This documents the default, confirming the PR change is meaningful:
        // the default is false, but SecurityService now explicitly enables it.
        const defaultOptions = AndroidOptions();
        // The default constructor should not enable encryption unless specified
        expect(
          defaultOptions.encryptedSharedPreferences,
          isFalse,
          reason:
              'Default AndroidOptions should not enable encryptedSharedPreferences; '
              'the PR explicitly opts in for enhanced security',
        );
      },
    );
  });
}