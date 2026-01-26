import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockAnalyticsService extends Mock implements AnalyticsService {}
class MockCrashlyticsService extends Mock implements CrashlyticsService {}

void main() {
  late MockAuthRepository mockAuthRepository;
  late MockAnalyticsService mockAnalyticsService;
  late MockCrashlyticsService mockCrashlyticsService;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockAnalyticsService = MockAnalyticsService();
    mockCrashlyticsService = MockCrashlyticsService();
  });

  testWidgets('Google Sign In button has correct semantics', (tester) async {
    // Setup long running sign in
    when(() => mockAuthRepository.signInWithGoogle()).thenAnswer((_) async {
      await Future.delayed(const Duration(seconds: 2));
      return null;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepository),
          analyticsServiceProvider.overrideWithValue(mockAnalyticsService),
          crashlyticsServiceProvider.overrideWithValue(mockCrashlyticsService),
          googleSignInInitializedProvider.overrideWith((ref) => Future.value()),
        ],
        child: const MaterialApp(
          home: SignInScreen(),
        ),
      ),
    );

    // Wait for entrance animations (1500ms).
    // We cannot use pumpAndSettle because of the infinite floating/glow animations.
    await tester.pump(const Duration(milliseconds: 2000));

    // Verify initial state
    final buttonFinder = find.text('Continue with Google');
    expect(buttonFinder, findsOneWidget);

    // Verify semantics BEFORE fix (optional, but good to know)
    // Currently, the text is just text. The button is the InkWell.
    // The InkWell doesn't have the label 'Continue with Google' attached to its node directly,
    // although Flutter's accessibility tree usually merges text inside buttons.
    // But checking for 'Signing in with Google...' when loading is the key addition.

    // Tap the button
    await tester.tap(buttonFinder);
    await tester.pump(); // Start the loading state (setState)

    // Verify loading indicator appears
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Verify semantics during loading
    // This expectation is for the NEW behavior we want to implement.
    expect(find.bySemanticsLabel('Signing in with Google'), findsOneWidget);

    // Finish the pending timer from the mock
    await tester.pump(const Duration(seconds: 2));
  });
}
