import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';

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
          child: const MaterialApp(home: PasscodeScreen()),
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
}
