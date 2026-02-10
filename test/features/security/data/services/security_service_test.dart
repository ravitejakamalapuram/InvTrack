import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/utils/security_utils.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/mock_security_service.dart';

void main() {
  late FakeFlutterSecureStorage fakeSecureStorage;
  late FakeLocalAuthentication fakeLocalAuth;
  late SharedPreferences prefs;
  late SecurityService service;

  setUp(() async {
    fakeSecureStorage = FakeFlutterSecureStorage();
    fakeLocalAuth = FakeLocalAuthentication();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = SecurityService(fakeSecureStorage, fakeLocalAuth, prefs);
  });

  tearDown(() {
    fakeSecureStorage.reset();
    fakeLocalAuth.reset();
  });

  group('SecurityService - PIN Management', () {
    test('hasPin returns false when no PIN is set', () async {
      final result = await service.hasPin();
      expect(result, isFalse);
    });

    test('hasPin returns true after PIN is set', () async {
      await service.setPin('1234');
      final result = await service.hasPin();
      expect(result, isTrue);
    });

    test('setPin stores PBKDF2 hashed PIN (v3)', () async {
      const pin = '1234';
      await service.setPin(pin);

      final storedValue = fakeSecureStorage.storage['user_pin'];
      expect(storedValue, contains(':'));

      final parts = storedValue!.split(':');
      expect(parts.length, equals(3));

      final salt = parts[0];
      final iterations = int.parse(parts[1]);
      final hash = parts[2];

      // Verify salt is base64
      expect(() => base64.decode(salt), returnsNormally);

      // Verify iterations
      expect(iterations, equals(10000));

      // Verify hash is base64
      expect(() => base64.decode(hash), returnsNormally);

      // Verify correctness
      expect(SecurityUtils.verifyPin(pin, storedValue), isTrue);
    });

    test('verifyPin returns true for correct PIN (hashed storage)', () async {
      await service.setPin('1234');
      final result = await service.verifyPin('1234');
      expect(result, isTrue);
    });

    test('verifyPin returns false for incorrect PIN', () async {
      await service.setPin('1234');
      final result = await service.verifyPin('5678');
      expect(result, isFalse);
    });

    test('verifyPin upgrades legacy plaintext PIN to PBKDF2 hash', () async {
      // Setup: Manually store a plaintext PIN (legacy state)
      const plaintextPin = '1234';
      await fakeSecureStorage.write(key: 'user_pin', value: plaintextPin);

      // Verify: Authenticate with the correct PIN
      final result = await service.verifyPin(plaintextPin);
      expect(result, isTrue);

      // Check: Storage should now be PBKDF2 hashed (v3)
      final storedValue = fakeSecureStorage.storage['user_pin'];
      expect(storedValue!.split(':').length, equals(3));
      expect(SecurityUtils.verifyPin(plaintextPin, storedValue), isTrue);
    });

    test('verifyPin upgrades legacy unsalted hash to PBKDF2 hash', () async {
      // Setup: Manually store an unsalted hash (v1 state)
      const pin = '1234';
      final unsaltedHash = sha256.convert(utf8.encode(pin)).toString();
      await fakeSecureStorage.write(key: 'user_pin', value: unsaltedHash);

      // Verify: Authenticate with the correct PIN
      final result = await service.verifyPin(pin);
      expect(result, isTrue);

      // Check: Storage should now be PBKDF2 hashed (v3)
      final storedValue = fakeSecureStorage.storage['user_pin'];
      expect(storedValue!.split(':').length, equals(3));
      expect(SecurityUtils.verifyPin(pin, storedValue), isTrue);
    });

    test('verifyPin upgrades v2 salted hash to PBKDF2 hash', () async {
      // Setup: Manually store a v2 salted hash
      const pin = '1234';
      const salt = 'somesalt';
      final v2Hash = sha256.convert(utf8.encode(pin + salt)).toString();
      final storedV2 = '$salt:$v2Hash';
      await fakeSecureStorage.write(key: 'user_pin', value: storedV2);

      // Verify: Authenticate with the correct PIN
      final result = await service.verifyPin(pin);
      expect(result, isTrue);

      // Check: Storage should now be PBKDF2 hashed (v3)
      final storedValue = fakeSecureStorage.storage['user_pin'];
      expect(storedValue!.split(':').length, equals(3));
      expect(SecurityUtils.verifyPin(pin, storedValue), isTrue);
    });

    test('removePin removes the PIN and disables biometrics', () async {
      await service.setPin('1234');
      await service.setBiometricEnabled(true);
      expect(await service.hasPin(), isTrue);
      expect(service.isBiometricEnabled, isTrue);

      await service.removePin();

      expect(await service.hasPin(), isFalse);
      expect(service.isBiometricEnabled, isFalse);
    });
  });

  group('SecurityService - Rate Limiting', () {
    test('verifyPin increments failed attempts on incorrect PIN (SecureStorage)',
        () async {
      await service.setPin('1234');

      await service.verifyPin('5678'); // 1st attempt
      await service.verifyPin('5678'); // 2nd attempt

      final failedAttempts = fakeSecureStorage.storage['pin_failed_attempts'];
      expect(failedAttempts, equals('2'));
      // Ensure legacy prefs are not used/populated
      expect(prefs.containsKey('pin_failed_attempts'), isFalse);
    });

    test('verifyPin resets failed attempts on correct PIN', () async {
      await service.setPin('1234');

      await service.verifyPin('5678'); // 1st attempt
      await service.verifyPin('5678'); // 2nd attempt

      expect(fakeSecureStorage.storage['pin_failed_attempts'], equals('2'));

      await service.verifyPin('1234'); // Correct PIN

      expect(fakeSecureStorage.storage.containsKey('pin_failed_attempts'),
          isFalse);
    });

    test('verifyPin locks out after max attempts', () async {
      await service.setPin('1234');

      // Fail 4 times
      for (int i = 0; i < 4; i++) {
        await service.verifyPin('5678');
      }
      expect(await service.getLockoutRemainingSeconds(), isNull);

      // Fail 5th time -> Lockout
      await service.verifyPin('5678');

      expect(await service.getLockoutRemainingSeconds(), isNotNull);
      expect(fakeSecureStorage.storage.containsKey('pin_lockout_timestamp'),
          isTrue);

      // Even correct PIN should fail during lockout
      final result = await service.verifyPin('1234');
      expect(result, isFalse);
    });

    test('Lockout expires after duration', () async {
      await service.setPin('1234');

      // Trigger lockout
      for (int i = 0; i < 5; i++) {
        await service.verifyPin('5678');
      }

      // Verify lockout is active
      expect(await service.getLockoutRemainingSeconds(), isNotNull);

      // Simulate time passing (899 seconds later - still locked)
      final lockoutTimeStillLocked = DateTime.now().subtract(
        const Duration(seconds: 899),
      );
      await fakeSecureStorage.write(
        key: 'pin_lockout_timestamp',
        value: lockoutTimeStillLocked.millisecondsSinceEpoch.toString(),
      );
      expect(await service.getLockoutRemainingSeconds(), isNotNull);

      // Simulate time passing (901 seconds later - unlocked)
      final lockoutTimeUnlocked = DateTime.now().subtract(
        const Duration(seconds: 901),
      );
      await fakeSecureStorage.write(
        key: 'pin_lockout_timestamp',
        value: lockoutTimeUnlocked.millisecondsSinceEpoch.toString(),
      );

      // Verify lockout is expired
      expect(await service.getLockoutRemainingSeconds(), isNull);

      // Correct PIN should now work
      final result = await service.verifyPin('1234');
      expect(result, isTrue);
    });
  });

  group('SecurityService - Storage Migration', () {
    test('Migrates failed attempts from SharedPreferences to SecureStorage',
        () async {
      await service.setPin('1234');
      // Setup legacy state
      await prefs.setInt('pin_failed_attempts', 3);
      expect(fakeSecureStorage.storage.containsKey('pin_failed_attempts'),
          isFalse);

      // Calling verifyPin should read the legacy value, increment it, and store in SecureStorage
      await service.verifyPin('5678');

      // Should be 3 + 1 = 4
      expect(fakeSecureStorage.storage['pin_failed_attempts'], equals('4'));
      // Legacy should be removed
      expect(prefs.containsKey('pin_failed_attempts'), isFalse);
    });

    test('Migrates lockout timestamp from SharedPreferences to SecureStorage',
        () async {
      // Setup legacy state (locked out)
      final lockoutTime = DateTime.now().millisecondsSinceEpoch;
      await prefs.setInt('pin_lockout_timestamp', lockoutTime);
      expect(fakeSecureStorage.storage.containsKey('pin_lockout_timestamp'),
          isFalse);

      // Check lockout status
      final remaining = await service.getLockoutRemainingSeconds();
      expect(remaining, isNotNull);

      // Should have migrated to SecureStorage
      expect(fakeSecureStorage.storage['pin_lockout_timestamp'],
          equals(lockoutTime.toString()));
      // Legacy should be removed
      expect(prefs.containsKey('pin_lockout_timestamp'), isFalse);
    });
  });

  group('SecurityService - Biometrics', () {
    test(
      'isBiometricAvailable returns true when device supports biometrics',
      () async {
        fakeLocalAuth.canCheckBiometricsValue = true;
        fakeLocalAuth.isDeviceSupportedValue = true;

        final result = await service.isBiometricAvailable();

        expect(result, isTrue);
      },
    );

    test(
      'isBiometricAvailable returns false when canCheckBiometrics is false',
      () async {
        fakeLocalAuth.canCheckBiometricsValue = false;
        fakeLocalAuth.isDeviceSupportedValue = true;

        final result = await service.isBiometricAvailable();

        expect(result, isFalse);
      },
    );

    test(
      'isBiometricAvailable returns false when device is not supported',
      () async {
        fakeLocalAuth.canCheckBiometricsValue = true;
        fakeLocalAuth.isDeviceSupportedValue = false;

        final result = await service.isBiometricAvailable();

        expect(result, isFalse);
      },
    );

    test(
      'authenticateWithBiometrics returns true on successful auth',
      () async {
        fakeLocalAuth.authenticateResult = true;

        final result = await service.authenticateWithBiometrics();

        expect(result, isTrue);
        expect(fakeLocalAuth.stopAuthenticationCallCount, equals(1));
        expect(fakeLocalAuth.authenticateCallCount, equals(1));
      },
    );

    test('authenticateWithBiometrics returns false on failed auth', () async {
      fakeLocalAuth.authenticateResult = false;

      final result = await service.authenticateWithBiometrics();

      expect(result, isFalse);
    });

    test(
      'authenticateWithBiometrics returns false when biometrics not available',
      () async {
        fakeLocalAuth.canCheckBiometricsValue = false;

        final result = await service.authenticateWithBiometrics();

        expect(result, isFalse);
        // Should not call authenticate if biometrics not available
        expect(fakeLocalAuth.authenticateCallCount, equals(0));
      },
    );

    test(
      'authenticateWithBiometrics calls stopAuthentication before authenticate',
      () async {
        fakeLocalAuth.authenticateResult = true;

        await service.authenticateWithBiometrics();

        expect(fakeLocalAuth.stopAuthenticationCallCount, equals(1));
      },
    );

    test(
      'authenticateWithBiometrics returns false on PlatformException (NotAvailable)',
      () async {
        fakeLocalAuth.shouldThrowPlatformException = true;
        fakeLocalAuth.platformExceptionCode = 'NotAvailable';

        final result = await service.authenticateWithBiometrics();

        expect(result, isFalse);
      },
    );

    test(
      'authenticateWithBiometrics returns false on PlatformException (NotEnrolled)',
      () async {
        fakeLocalAuth.shouldThrowPlatformException = true;
        fakeLocalAuth.platformExceptionCode = 'NotEnrolled';

        final result = await service.authenticateWithBiometrics();

        expect(result, isFalse);
      },
    );

    test(
      'authenticateWithBiometrics returns false on PlatformException (user cancelled)',
      () async {
        fakeLocalAuth.shouldThrowPlatformException = true;
        fakeLocalAuth.platformExceptionCode = 'UserCancelled';

        final result = await service.authenticateWithBiometrics();

        expect(result, isFalse);
      },
    );

    test(
      'authenticateWithBiometrics returns false on generic exception',
      () async {
        fakeLocalAuth.shouldThrowGenericException = true;

        final result = await service.authenticateWithBiometrics();

        expect(result, isFalse);
      },
    );

    test('isBiometricEnabled returns false by default', () {
      expect(service.isBiometricEnabled, isFalse);
    });

    test('setBiometricEnabled persists the setting', () async {
      await service.setBiometricEnabled(true);
      expect(service.isBiometricEnabled, isTrue);

      await service.setBiometricEnabled(false);
      expect(service.isBiometricEnabled, isFalse);
    });
  });

  group('SecurityService - Auto Lock', () {
    test('autoLockDurationSeconds returns 0 (immediate) by default', () {
      expect(service.autoLockDurationSeconds, equals(0));
    });

    test('setAutoLockDuration persists the setting', () async {
      await service.setAutoLockDuration(60);
      expect(service.autoLockDurationSeconds, equals(60));

      await service.setAutoLockDuration(300);
      expect(service.autoLockDurationSeconds, equals(300));
    });
  });
}
