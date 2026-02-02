import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('setPin stores salted hashed PIN', () async {
      const pin = '1234';
      await service.setPin(pin);

      final storedValue = fakeSecureStorage.storage['user_pin'];
      expect(storedValue, contains(':'));

      final parts = storedValue!.split(':');
      expect(parts.length, equals(2));

      final salt = parts[0];
      final hash = parts[1];

      // Verify salt is base64
      expect(() => base64.decode(salt), returnsNormally);

      // Verify hash is SHA-256 (64 chars hex)
      expect(hash.length, equals(64));

      // Verify hash calculation
      final expectedHash = sha256.convert(utf8.encode(pin + salt)).toString();
      expect(hash, equals(expectedHash));
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

    test('verifyPin upgrades legacy plaintext PIN to salted hash', () async {
      // Setup: Manually store a plaintext PIN (legacy state)
      const plaintextPin = '1234';
      await fakeSecureStorage.write(key: 'user_pin', value: plaintextPin);

      // Verify: Authenticate with the correct PIN
      final result = await service.verifyPin(plaintextPin);
      expect(result, isTrue);

      // Check: Storage should now be salted hashed
      final storedValue = fakeSecureStorage.storage['user_pin'];
      expect(storedValue, contains(':'));

      final parts = storedValue!.split(':');
      final salt = parts[0];
      final hash = parts[1];

      final expectedHash = sha256
          .convert(utf8.encode(plaintextPin + salt))
          .toString();
      expect(hash, equals(expectedHash));
    });

    test('verifyPin upgrades legacy unsalted hash to salted hash', () async {
      // Setup: Manually store an unsalted hash (v1 state)
      const pin = '1234';
      final unsaltedHash = sha256.convert(utf8.encode(pin)).toString();
      await fakeSecureStorage.write(key: 'user_pin', value: unsaltedHash);

      // Verify: Authenticate with the correct PIN
      final result = await service.verifyPin(pin);
      expect(result, isTrue);

      // Check: Storage should now be salted hashed
      final storedValue = fakeSecureStorage.storage['user_pin'];
      expect(storedValue, contains(':'));

      final parts = storedValue!.split(':');
      final salt = parts[0];
      final hash = parts[1];

      final expectedHash = sha256.convert(utf8.encode(pin + salt)).toString();
      expect(hash, equals(expectedHash));
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
    test('verifyPin increments failed attempts on incorrect PIN', () async {
      await service.setPin('1234');

      await service.verifyPin('5678'); // 1st attempt
      await service.verifyPin('5678'); // 2nd attempt

      final failedAttempts = prefs.getInt('pin_failed_attempts');
      expect(failedAttempts, equals(2));
    });

    test('verifyPin resets failed attempts on correct PIN', () async {
      await service.setPin('1234');

      await service.verifyPin('5678'); // 1st attempt
      await service.verifyPin('5678'); // 2nd attempt

      expect(prefs.getInt('pin_failed_attempts'), equals(2));

      await service.verifyPin('1234'); // Correct PIN

      expect(prefs.containsKey('pin_failed_attempts'), isFalse);
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
      // Note: Since we can't easily mock DateTime.now() inside the service without dependency injection,
      // we can manually modify the stored timestamp to be in the past.
      final lockoutTimeStillLocked = DateTime.now().subtract(
        const Duration(seconds: 899),
      );
      await prefs.setInt(
        'pin_lockout_timestamp',
        lockoutTimeStillLocked.millisecondsSinceEpoch,
      );
      expect(await service.getLockoutRemainingSeconds(), isNotNull);

      // Simulate time passing (901 seconds later - unlocked)
      final lockoutTimeUnlocked = DateTime.now().subtract(
        const Duration(seconds: 901),
      );
      await prefs.setInt(
        'pin_lockout_timestamp',
        lockoutTimeUnlocked.millisecondsSinceEpoch,
      );

      // Verify lockout is expired
      expect(await service.getLockoutRemainingSeconds(), isNull);

      // Correct PIN should now work
      final result = await service.verifyPin('1234');
      expect(result, isTrue);
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
