import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });
}
