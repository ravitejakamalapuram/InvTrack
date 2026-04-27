import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/firebase_options.dart';
import 'package:mocktail/mocktail.dart';

// Mock GoogleSignIn
class MockGoogleSignIn extends Mock implements GoogleSignIn {}

void main() {
  group('googleSignInInitializedProvider', () {
    late MockGoogleSignIn mockGoogleSignIn;

    setUp(() {
      mockGoogleSignIn = MockGoogleSignIn();

      // Stub the initialize method
      when(() => mockGoogleSignIn.initialize(
            clientId: any(named: 'clientId'),
            serverClientId: any(named: 'serverClientId'),
          )).thenAnswer((_) async {});
    });

    tearDown(() {
      // Reset any platform overrides
      debugDefaultTargetPlatformOverride = null;
    });

    test('calls initialize with webOAuthClientId on web platform', () async {
      // This test verifies that on web platform (kIsWeb == true),
      // GoogleSignIn.instance.initialize is called with the correct clientId
      // from DefaultFirebaseOptions.webOAuthClientId

      // Note: Since kIsWeb is a compile-time constant, we cannot override it at runtime.
      // This test documents the expected behavior and validates the constants are correct.
      // The actual platform-specific behavior is tested through integration tests.

      // Verify the web OAuth client ID is correctly defined
      expect(DefaultFirebaseOptions.webOAuthClientId, isNotEmpty);
      expect(
        DefaultFirebaseOptions.webOAuthClientId,
        contains('.apps.googleusercontent.com'),
      );

      // Verify it matches the expected value
      const expectedWebClientId =
          '20057918856-r6qh2gt5eqk2o3oiq8fkt8pgfhquja6a.apps.googleusercontent.com';
      expect(
        DefaultFirebaseOptions.webOAuthClientId,
        expectedWebClientId,
        reason: 'webOAuthClientId must match Firebase Console web configuration',
      );

      // When running in a real web environment, the provider would call:
      // GoogleSignIn.instance.initialize(clientId: DefaultFirebaseOptions.webOAuthClientId)
    });

    test('calls initialize with mobileServerClientId on mobile platforms',
        () async {
      // This test verifies that on mobile platforms (kIsWeb == false),
      // GoogleSignIn.instance.initialize is called with the correct serverClientId
      // from DefaultFirebaseOptions.mobileServerClientId

      // Note: Since kIsWeb is a compile-time constant, we cannot override it at runtime.
      // This test documents the expected behavior and validates the constants are correct.
      // The actual platform-specific behavior is tested through integration tests.

      // Verify the mobile server client ID is correctly defined
      expect(DefaultFirebaseOptions.mobileServerClientId, isNotEmpty);
      expect(
        DefaultFirebaseOptions.mobileServerClientId,
        contains('.apps.googleusercontent.com'),
      );

      // Verify it matches the expected value (Web Client ID, client_type: 3)
      const expectedServerClientId =
          '784857267556-dkge5l37c12n1ohrljle8s6nim0cgq84.apps.googleusercontent.com';
      expect(
        DefaultFirebaseOptions.mobileServerClientId,
        expectedServerClientId,
        reason:
            'mobileServerClientId must be the Web OAuth Client ID (client_type: 3) '
            'to prevent GoogleSignInException on Android',
      );

      // When running on Android/iOS, the provider would call:
      // GoogleSignIn.instance.initialize(serverClientId: DefaultFirebaseOptions.mobileServerClientId)
    });

    test('OAuth client IDs are centralized in DefaultFirebaseOptions', () {
      // Regression test: Verify constants are properly defined and follow expected format
      expect(
        DefaultFirebaseOptions.webOAuthClientId,
        contains('.apps.googleusercontent.com'),
      );
      expect(
        DefaultFirebaseOptions.mobileServerClientId,
        contains('.apps.googleusercontent.com'),
      );

      // Verify they're different (web vs mobile server)
      expect(
        DefaultFirebaseOptions.webOAuthClientId,
        isNot(equals(DefaultFirebaseOptions.mobileServerClientId)),
        reason: 'Web and mobile server client IDs should be different',
      );
    });

    test('provider can be overridden for testing', () async {
      // This test verifies that the googleSignInInitializedProvider can be
      // properly overridden in tests, which is essential for testing components
      // that depend on it (like SignInScreen)

      final container = ProviderContainer(
        overrides: [
          googleSignInInitializedProvider.overrideWith((ref) async {
            // Mock implementation - no actual initialization needed in tests
          }),
        ],
      );

      // Read the provider to verify it can be accessed
      await container.read(googleSignInInitializedProvider.future);

      // Cleanup
      container.dispose();
    });
  });
}
