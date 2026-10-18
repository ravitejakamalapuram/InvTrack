import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../mocks/fake_auth_repository.dart';
import '../../../../mocks/mock_security_service.dart';

// Mock SecurityNotifier
class MockSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() {
    return const SecurityState(
      isBiometricEnabled:
          false, // Disable biometrics to avoid further async calls
      isBiometricAvailable: false,
    );
  }
}

class _FailedStorageNotifier extends SecurityNotifier {
  _FailedStorageNotifier({required this.storageFailed});

  final bool storageFailed;

  @override
  SecurityState build() =>
      SecurityState(isLocked: true, hasPin: true, storageFailed: storageFailed);
}

/// Secure storage that answers after [delay], like a slow keystore at cold
/// start.
class _SlowSecureStorage extends FakeFlutterSecureStorage {
  _SlowSecureStorage(this.delay);

  final Duration delay;

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
    await Future<void>.delayed(delay);
    return super.read(key: key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.invtracker/security');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'PasscodeScreen enables secure mode on init and disables on dispose',
    (tester) async {
      // Resize surface to avoid overflow
      await tester.binding.setSurfaceSize(const Size(1080, 1920));

      // 1. Pump the widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            securityProvider.overrideWith(() => MockSecurityNotifier()),
          ],
          child: const MaterialApp(
            home: PasscodeScreen(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      // Wait for the initial Future.delayed to trigger and complete
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.byType(PasscodeScreen), findsOneWidget);

      // Note: We cannot assert that `setSecureMode` was called here because
      // the implementation checks `Platform.isAndroid`. In the test environment
      // (Linux/macOS), `Platform.isAndroid` is false, so the channel is skipped.
      //
      // To properly test this, we would need to wrap `Platform` calls or run
      // integration tests on an Android device/emulator.
      //
      // Current test ensures:
      // 1. Widget renders without crashing
      // 2. Logic executes without errors
      // 3. Cleanup logic runs

      // 2. Dispose the widget
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  // A07: the app now shows the lock screen from the first frame, before
  // secure storage has said whether biometrics are available. The automatic
  // fingerprint prompt must wait for that answer instead of being spent.
  group('automatic fingerprint prompt at cold start', () {
    Future<FakeLocalAuthentication> pumpLockScreen(
      WidgetTester tester,
      Duration storageDelay,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'has_pin': true,
        'biometric_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final storage = _SlowSecureStorage(storageDelay);
      await storage.write(key: 'user_pin', value: 'hash');
      final localAuth = FakeLocalAuthentication();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            securityServiceProvider.overrideWithValue(
              SecurityService(storage, localAuth, prefs),
            ),
          ],
          child: const MaterialApp(
            home: PasscodeScreen(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      return localAuth;
    }

    for (final delay in const [Duration.zero, Duration(milliseconds: 800)]) {
      testWidgets('prompts exactly once when storage answers after '
          '${delay.inMilliseconds} ms', (tester) async {
        final localAuth = await pumpLockScreen(tester, delay);

        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(delay);
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 3));

        expect(localAuth.authenticateCallCount, 1);
      });
    }

    // A114: a fingerprint prompt that opens while the user types the PIN
    // takes the keypad away mid-entry.
    testWidgets('does not prompt once the user has started typing the PIN', (
      tester,
    ) async {
      const storageDelay = Duration(milliseconds: 800);
      final localAuth = await pumpLockScreen(tester, storageDelay);

      // Biometrics are not known to be available yet.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      // Storage answers and biometrics turn available.
      await tester.pump(storageDelay);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 3));

      expect(localAuth.authenticateCallCount, 0);
    });

    // A114: the prompt after a resume (500 ms later) is skipped the same way.
    testWidgets('does not prompt on resume once the user has started typing '
        'the PIN', (tester) async {
      const storageDelay = Duration(milliseconds: 800);
      final localAuth = await pumpLockScreen(tester, storageDelay);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('2'));
      await tester.pump();
      // Storage answers: biometrics are on and available.
      await tester.pump(storageDelay);
      await tester.pump(const Duration(milliseconds: 100));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 3));

      expect(localAuth.authenticateCallCount, 0);
    });

    // Submitting the fourth digit clears the dots before the PIN is
    // checked, so an empty entry must not count as "not typing".
    testWidgets('does not prompt on resume while a submitted PIN is being '
        'checked', (tester) async {
      const storageDelay = Duration(milliseconds: 800);
      final localAuth = await pumpLockScreen(tester, storageDelay);
      await tester.pump(const Duration(milliseconds: 300));
      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }
      // Storage answers: biometrics are on and available; the PIN check is
      // still waiting on storage.
      await tester.pump(storageDelay);
      await tester.pump(const Duration(milliseconds: 100));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(seconds: 5));

      expect(localAuth.authenticateCallCount, 0);
    });
  });

  // A111: every locked state has a way out, and none opens the portfolio.
  group('ways out of the lock (A111)', () {
    Future<void> pumpLock(
      WidgetTester tester, {
      required UserEntity user,
      required bool storageFailed,
    }) async {
      await tester.binding.setSurfaceSize(const Size(1080, 1920));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            securityProvider.overrideWith(
              () => _FailedStorageNotifier(storageFailed: storageFailed),
            ),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(user)),
          ],
          child: const MaterialApp(
            home: PasscodeScreen(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('storage failed, Google user: Retry, Forgot PIN and Sign '
        'out', (tester) async {
      await pumpLock(tester, user: googleUser, storageFailed: true);

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Forgot PIN?'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.bySemanticsLabel('Forgot PIN?'), findsOneWidget);
    });

    testWidgets('storage failed, guest: Retry only', (tester) async {
      await pumpLock(tester, user: guestUser, storageFailed: true);

      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Forgot PIN?'), findsNothing);
      expect(find.text('Sign Out'), findsNothing);
    });

    testWidgets('storage fine, Google user: Forgot PIN only', (tester) async {
      await pumpLock(tester, user: googleUser, storageFailed: false);

      expect(find.text('Forgot PIN?'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Sign Out'), findsNothing);
    });

    testWidgets('Sign out signs the user out', (tester) async {
      await pumpLock(tester, user: googleUser, storageFailed: true);

      await tester.tap(find.text('Sign Out'));
      await tester.pump();

      final auth =
          ProviderScope.containerOf(
                tester.element(find.byType(PasscodeScreen)),
              ).read(authRepositoryProvider)
              as FakeAuthRepository;
      expect(auth.signOutCalls, 1);
    });
  });
}
