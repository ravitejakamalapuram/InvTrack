import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/features/security/presentation/screens/passcode_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/security/data/services/security_service.dart';
import 'package:mocktail/mocktail.dart';

class MockSecurityService extends Mock implements SecurityService {}

// Fake notifier to bypass WidgetsBindingObserver usage in original build()
class FakeSecurityNotifier extends SecurityNotifier {
  @override
  SecurityState build() {
    return const SecurityState(
      isBiometricEnabled: true,
      isBiometricAvailable: true,
      hasPin: true,
    );
  }
}

class FakeSecurityNotifierNoBio extends SecurityNotifier {
  @override
  SecurityState build() {
    return const SecurityState(
      isBiometricEnabled: false,
      isBiometricAvailable: false,
      hasPin: true,
    );
  }
}

void main() {
  testWidgets('PasscodeScreen has accessible tooltips and semantics', (tester) async {
    // Set a larger surface size to prevent overflow in tests
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockSecurityService = MockSecurityService();
    // Comprehensive mocking to prevent missing stub errors
    when(() => mockSecurityService.getLockoutRemainingSeconds())
        .thenAnswer((_) async => null);
    when(() => mockSecurityService.authenticateWithBiometrics())
        .thenAnswer((_) async => false);
    when(() => mockSecurityService.isBiometricAvailable())
        .thenAnswer((_) async => true);
    when(() => mockSecurityService.hasPin())
        .thenAnswer((_) async => true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          securityServiceProvider.overrideWithValue(mockSecurityService),
          securityProvider.overrideWith(FakeSecurityNotifier.new),
        ],
        child: const MaterialApp(
          home: PasscodeScreen(mode: PasscodeMode.unlock),
        ),
      ),
    );
    // Allow the initial biometric auto-check timer (300ms) to run
    // Explicitly pump past the 300ms delay + buffer to ensure the callback fires
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Verify Biometric button tooltip
    expect(find.byTooltip('Authenticate with biometrics'), findsOneWidget);

    // Tap a digit to show clear/backspace buttons (entering '1')
    await tester.tap(find.text('1'));
    await tester.pump();

    // Verify Backspace tooltip
    expect(find.byTooltip('Delete last digit'), findsOneWidget);

    // Verify PIN semantics (1 digit entered)
    expect(find.bySemanticsLabel('PIN input'), findsOneWidget);

    final semantics = tester.getSemantics(find.bySemanticsLabel('PIN input'));
    expect(semantics.value, '1 of 4 digits entered');
  });

  testWidgets('PasscodeScreen shows Clear button when biometrics disabled', (tester) async {
    // Set a larger surface size to prevent overflow in tests
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final mockSecurityService = MockSecurityService();
    // Comprehensive mocking to prevent missing stub errors
    when(() => mockSecurityService.getLockoutRemainingSeconds())
        .thenAnswer((_) async => null);
    when(() => mockSecurityService.authenticateWithBiometrics())
        .thenAnswer((_) async => false);
    when(() => mockSecurityService.isBiometricAvailable())
        .thenAnswer((_) async => true);
    when(() => mockSecurityService.hasPin())
        .thenAnswer((_) async => true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          securityServiceProvider.overrideWithValue(mockSecurityService),
          securityProvider.overrideWith(FakeSecurityNotifierNoBio.new),
        ],
        child: const MaterialApp(
          home: PasscodeScreen(mode: PasscodeMode.unlock),
        ),
      ),
    );

    // Allow the initial biometric auto-check timer (300ms) to run
    // Explicitly pump past the 300ms delay + buffer to ensure the callback fires
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    // Enter a digit so Clear button is enabled
    await tester.tap(find.text('1'));
    await tester.pump();

    expect(find.byTooltip('Clear all'), findsOneWidget);
  });
}
