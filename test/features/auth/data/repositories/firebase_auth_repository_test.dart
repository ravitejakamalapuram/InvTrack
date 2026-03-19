import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockAuthCredential extends Mock implements AuthCredential {}

void main() {
  late FirebaseAuthRepository repository;
  late MockFirebaseAuth mockFirebaseAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockGoogleSignInAccount;
  late MockGoogleSignInAuthentication mockGoogleSignInAuthentication;
  late MockUserCredential mockUserCredential;
  late MockUser mockUser;

  setUp(() {
    mockFirebaseAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    mockGoogleSignInAccount = MockGoogleSignInAccount();
    mockGoogleSignInAuthentication = MockGoogleSignInAuthentication();
    mockUserCredential = MockUserCredential();
    mockUser = MockUser();

    repository = FirebaseAuthRepository(
      firebaseAuth: mockFirebaseAuth,
      googleSignIn: mockGoogleSignIn,
    );

    // Register fallback values for mocktail
    registerFallbackValue(MockAuthCredential());
  });

  group('FirebaseAuthRepository - Google Sign-In Fix Tests', () {
    test(
      'signInWithGoogle uses only idToken (no authorizationForScopes)',
      () async {
        // Arrange
        const testEmail = 'test@example.com';
        const testIdToken = 'test-id-token-12345';
        const testUid = 'test-uid-12345';

        // Mock GoogleSignIn.authenticate() to return GoogleSignInAccount
        // No scopeHint parameter - identity-only mode
        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleSignInAccount);

        // Mock GoogleSignInAccount properties
        when(() => mockGoogleSignInAccount.email).thenReturn(testEmail);
        when(
          () => mockGoogleSignInAccount.authentication,
        ).thenReturn(mockGoogleSignInAuthentication);

        // Mock GoogleSignInAuthentication to provide only idToken
        when(
          () => mockGoogleSignInAuthentication.idToken,
        ).thenReturn(testIdToken);

        // Mock FirebaseAuth.signInWithCredential
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => mockUserCredential);

        // Mock UserCredential and User
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn(testUid);
        when(() => mockUser.email).thenReturn(testEmail);
        when(() => mockUser.displayName).thenReturn('Test User');
        when(() => mockUser.photoURL).thenReturn(null);
        when(() => mockUser.isAnonymous).thenReturn(false);

        // Act
        final result = await repository.signInWithGoogle();

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testUid);
        expect(result.email, testEmail);

        // Verify authenticate was called with NO scopeHint (identity-only mode)
        verify(() => mockGoogleSignIn.authenticate()).called(1);

        // Verify authentication property was accessed (not authorizationForScopes)
        verify(() => mockGoogleSignInAccount.authentication).called(1);

        // Verify idToken was used (called twice: once for null check, once for credential)
        verify(() => mockGoogleSignInAuthentication.idToken).called(2);

        // Verify Firebase sign-in was called
        verify(() => mockFirebaseAuth.signInWithCredential(any())).called(1);

        // CRITICAL: Verify authorizationClient was NEVER accessed
        // (This would be the hanging call we fixed)
        verifyNever(() => mockGoogleSignInAccount.authorizationClient);
      },
    );

    test('signInWithGoogle handles GoogleSignInException.canceled', () async {
      // Arrange
      when(() => mockGoogleSignIn.authenticate()).thenThrow(
        const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
      );

      // Act
      final result = await repository.signInWithGoogle();

      // Assert
      expect(result, isNull);
      verify(() => mockGoogleSignIn.authenticate()).called(1);
      verifyNever(() => mockFirebaseAuth.signInWithCredential(any()));
    });

    test(
      'signInWithGoogle rethrows non-canceled GoogleSignInException',
      () async {
        // Arrange
        // Use 'interrupted' code (valid GoogleSignInExceptionCode value)
        when(() => mockGoogleSignIn.authenticate()).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.interrupted,
          ),
        );

        // Act & Assert
        // The implementation converts GoogleSignInException to Exception with user-friendly message
        expect(() => repository.signInWithGoogle(), throwsA(isA<Exception>()));
      },
    );

    test('signInWithGoogle rethrows generic exceptions', () async {
      // Arrange
      when(
        () => mockGoogleSignIn.authenticate(),
      ).thenThrow(Exception('Network error'));

      // Act & Assert
      expect(() => repository.signInWithGoogle(), throwsA(isA<Exception>()));
    });

    test(
      'signInWithGoogle returns null when user is null in credential',
      () async {
        // Arrange
        when(
          () =>
              mockGoogleSignIn.authenticate(scopeHint: any(named: 'scopeHint')),
        ).thenAnswer((_) async => mockGoogleSignInAccount);
        when(
          () => mockGoogleSignInAccount.email,
        ).thenReturn('test@example.com');
        when(
          () => mockGoogleSignInAccount.authentication,
        ).thenReturn(mockGoogleSignInAuthentication);
        when(
          () => mockGoogleSignInAuthentication.idToken,
        ).thenReturn('test-token');
        when(
          () => mockFirebaseAuth.signInWithCredential(any()),
        ).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserCredential.user).thenReturn(null);

        // Act
        final result = await repository.signInWithGoogle();

        // Assert
        expect(result, isNull);
      },
    );
  });

  group('FirebaseAuthRepository - reauthenticateWithGoogle Fix Tests', () {
    test(
      'reauthenticateWithGoogle uses only idToken (no authorizationForScopes)',
      () async {
        // Arrange
        const testEmail = 'test@example.com';
        const testIdToken = 'test-id-token-12345';
        const testUid = 'test-uid-12345';

        // Mock current user
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn(testUid);
        when(() => mockUser.email).thenReturn(testEmail);

        // Mock GoogleSignIn.signOut
        when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});

        // Mock GoogleSignIn.authenticate
        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleSignInAccount);

        // Mock GoogleSignInAccount
        when(
          () => mockGoogleSignInAccount.authentication,
        ).thenReturn(mockGoogleSignInAuthentication);

        // Mock GoogleSignInAuthentication to provide only idToken
        when(
          () => mockGoogleSignInAuthentication.idToken,
        ).thenReturn(testIdToken);

        // Mock User.reauthenticateWithCredential
        when(
          () => mockUser.reauthenticateWithCredential(any()),
        ).thenAnswer((_) async => mockUserCredential);

        // Act
        final result = await repository.reauthenticateWithGoogle();

        // Assert
        expect(result, isTrue);

        // Verify sign out was called first
        verify(() => mockGoogleSignIn.signOut()).called(1);

        // Verify authenticate was called
        verify(() => mockGoogleSignIn.authenticate()).called(1);

        // Verify authentication property was accessed
        verify(() => mockGoogleSignInAccount.authentication).called(1);

        // Verify idToken was used
        verify(() => mockGoogleSignInAuthentication.idToken).called(1);

        // Verify reauthentication was called
        verify(() => mockUser.reauthenticateWithCredential(any())).called(1);

        // CRITICAL: Verify authorizationClient was NEVER accessed
        verifyNever(() => mockGoogleSignInAccount.authorizationClient);
      },
    );

    test(
      'reauthenticateWithGoogle returns false when no current user',
      () async {
        // Arrange
        when(() => mockFirebaseAuth.currentUser).thenReturn(null);

        // Act
        final result = await repository.reauthenticateWithGoogle();

        // Assert
        expect(result, isFalse);
        verifyNever(() => mockGoogleSignIn.signOut());
        verifyNever(
          () =>
              mockGoogleSignIn.authenticate(scopeHint: any(named: 'scopeHint')),
        );
      },
    );

    test('reauthenticateWithGoogle handles exceptions', () async {
      // Arrange
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});
      when(
        () => mockGoogleSignIn.authenticate(scopeHint: any(named: 'scopeHint')),
      ).thenThrow(Exception('Re-auth failed'));

      // Act & Assert
      expect(
        () => repository.reauthenticateWithGoogle(),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('FirebaseAuthRepository - Other Methods', () {
    test('signOut calls both GoogleSignIn and FirebaseAuth signOut', () async {
      // Arrange
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});
      when(() => mockFirebaseAuth.signOut()).thenAnswer((_) async {});

      // Act
      await repository.signOut();

      // Assert
      verify(() => mockGoogleSignIn.signOut()).called(1);
      verify(() => mockFirebaseAuth.signOut()).called(1);
    });

    test('getAuthToken returns token from current user', () async {
      // Arrange
      const testToken = 'test-auth-token-12345';
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => testToken);

      // Act
      final result = await repository.getAuthToken();

      // Assert
      expect(result, testToken);
      verify(() => mockUser.getIdToken()).called(1);
    });

    test('getAuthToken returns null when no current user', () async {
      // Arrange
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      // Act
      final result = await repository.getAuthToken();

      // Assert
      expect(result, isNull);
      verify(() => mockFirebaseAuth.currentUser).called(1);
    });

    test('currentUser returns mapped entity when user exists', () {
      // Arrange
      const testUid = 'test-uid';
      const testEmail = 'test@example.com';
      when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.uid).thenReturn(testUid);
      when(() => mockUser.email).thenReturn(testEmail);
      when(() => mockUser.displayName).thenReturn('Test User');
      when(() => mockUser.photoURL).thenReturn(null);
      when(() => mockUser.isAnonymous).thenReturn(false);

      // Act
      final result = repository.currentUser;

      // Assert
      expect(result, isNotNull);
      expect(result!.id, testUid);
      expect(result.email, testEmail);
    });

    test('currentUser returns null when no user exists', () {
      // Arrange
      when(() => mockFirebaseAuth.currentUser).thenReturn(null);

      // Act
      final result = repository.currentUser;

      // Assert
      expect(result, isNull);
    });
  });

  group('FirebaseAuthRepository - linkAnonymousToGoogle Tests', () {
    test(
      'linkAnonymousToGoogle succeeds: links credential, preserves UID',
      () async {
        // Arrange
        const testUid = 'anon-uid-12345';
        const testEmail = 'user@example.com';
        const testIdToken = 'test-id-token-abc';

        // Current user is anonymous
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn(testUid);
        when(() => mockUser.isAnonymous).thenReturn(true);

        // Google sign-in returns account
        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleSignInAccount);
        when(() => mockGoogleSignInAccount.email).thenReturn(testEmail);
        when(
          () => mockGoogleSignInAccount.authentication,
        ).thenReturn(mockGoogleSignInAuthentication);
        when(
          () => mockGoogleSignInAuthentication.idToken,
        ).thenReturn(testIdToken);

        // linkWithCredential returns linked user (same UID)
        when(
          () => mockUser.linkWithCredential(any()),
        ).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockUser.email).thenReturn(testEmail);
        when(() => mockUser.displayName).thenReturn('Test User');
        when(() => mockUser.photoURL).thenReturn(null);

        // Act
        final result = await repository.linkAnonymousToGoogle();

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testUid); // UID preserved
        expect(result.isAnonymous, isFalse);
        expect(result.email, testEmail);

        // Verify linkWithCredential was called (not signInWithCredential)
        verify(() => mockUser.linkWithCredential(any())).called(1);
        verifyNever(() => mockFirebaseAuth.signInWithCredential(any()));

        // Verify authenticate and authentication were called
        verify(() => mockGoogleSignIn.authenticate()).called(1);
        verify(() => mockGoogleSignInAccount.authentication).called(1);
      },
    );

    test(
      'linkAnonymousToGoogle throws AuthException when no current user',
      () async {
        // Arrange
        when(() => mockFirebaseAuth.currentUser).thenReturn(null);

        // Act & Assert
        await expectLater(
          repository.linkAnonymousToGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.userMessage,
              'userMessage',
              contains('No user is currently signed in'),
            ),
          ),
        );

        verifyNever(() => mockGoogleSignIn.authenticate());
      },
    );

    test(
      'linkAnonymousToGoogle throws AuthException when user is not anonymous',
      () async {
        // Arrange
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.isAnonymous).thenReturn(false);
        when(() => mockUser.uid).thenReturn('google-uid-456');

        // Act & Assert
        await expectLater(
          repository.linkAnonymousToGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.userMessage,
              'userMessage',
              contains('already linked to Google'),
            ),
          ),
        );

        verifyNever(() => mockGoogleSignIn.authenticate());
      },
    );

    test(
      'linkAnonymousToGoogle throws AuthException for credential-already-in-use',
      () async {
        // Arrange
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.isAnonymous).thenReturn(true);
        when(() => mockUser.uid).thenReturn('anon-uid-123');

        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleSignInAccount);
        when(() => mockGoogleSignInAccount.email).thenReturn('g@g.com');
        when(
          () => mockGoogleSignInAccount.authentication,
        ).thenReturn(mockGoogleSignInAuthentication);
        when(
          () => mockGoogleSignInAuthentication.idToken,
        ).thenReturn('token');
        when(
          () => mockUser.linkWithCredential(any()),
        ).thenThrow(
          FirebaseAuthException(code: 'credential-already-in-use'),
        );

        // Act & Assert
        await expectLater(
          repository.linkAnonymousToGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.userMessage,
              'userMessage',
              contains('already registered'),
            ),
          ),
        );
      },
    );

    test(
      'linkAnonymousToGoogle throws AuthException for provider-already-linked',
      () async {
        // Arrange
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.isAnonymous).thenReturn(true);
        when(() => mockUser.uid).thenReturn('anon-uid-123');

        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleSignInAccount);
        when(() => mockGoogleSignInAccount.email).thenReturn('g@g.com');
        when(
          () => mockGoogleSignInAccount.authentication,
        ).thenReturn(mockGoogleSignInAuthentication);
        when(
          () => mockGoogleSignInAuthentication.idToken,
        ).thenReturn('token');
        when(
          () => mockUser.linkWithCredential(any()),
        ).thenThrow(
          FirebaseAuthException(code: 'provider-already-linked'),
        );

        // Act & Assert
        await expectLater(
          repository.linkAnonymousToGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.userMessage,
              'userMessage',
              contains('already linked to Google'),
            ),
          ),
        );
      },
    );

    test(
      'linkAnonymousToGoogle throws AuthException for invalid-credential',
      () async {
        // Arrange
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.isAnonymous).thenReturn(true);
        when(() => mockUser.uid).thenReturn('anon-uid-123');

        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleSignInAccount);
        when(() => mockGoogleSignInAccount.email).thenReturn('g@g.com');
        when(
          () => mockGoogleSignInAccount.authentication,
        ).thenReturn(mockGoogleSignInAuthentication);
        when(
          () => mockGoogleSignInAuthentication.idToken,
        ).thenReturn('token');
        when(
          () => mockUser.linkWithCredential(any()),
        ).thenThrow(
          FirebaseAuthException(code: 'invalid-credential'),
        );

        // Act & Assert
        await expectLater(
          repository.linkAnonymousToGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.userMessage,
              'userMessage',
              contains('Invalid Google credentials'),
            ),
          ),
        );
      },
    );

    test(
      'linkAnonymousToGoogle throws AuthException.signInCancelled on user cancellation',
      () async {
        // Arrange
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.isAnonymous).thenReturn(true);
        when(() => mockUser.uid).thenReturn('anon-uid-123');

        when(() => mockGoogleSignIn.authenticate()).thenThrow(
          const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
        );

        // Act & Assert
        await expectLater(
          repository.linkAnonymousToGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.userMessage,
              'userMessage',
              contains('cancelled'),
            ),
          ),
        );

        // No linkWithCredential should be called
        verifyNever(() => mockUser.linkWithCredential(any()));
      },
    );

    test(
      'linkAnonymousToGoogle throws AuthException for other GoogleSignInException',
      () async {
        // Arrange
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.isAnonymous).thenReturn(true);
        when(() => mockUser.uid).thenReturn('anon-uid-123');

        when(() => mockGoogleSignIn.authenticate()).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.interrupted,
          ),
        );

        // Act & Assert
        await expectLater(
          repository.linkAnonymousToGoogle(),
          throwsA(isA<AuthException>()),
        );
      },
    );

    test(
      'linkAnonymousToGoogle cleans up Google Sign-In state on unexpected error',
      () async {
        // Arrange
        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.isAnonymous).thenReturn(true);
        when(() => mockUser.uid).thenReturn('anon-uid-123');

        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleSignInAccount);
        when(() => mockGoogleSignInAccount.email).thenReturn('g@g.com');
        when(
          () => mockGoogleSignInAccount.authentication,
        ).thenReturn(mockGoogleSignInAuthentication);
        when(
          () => mockGoogleSignInAuthentication.idToken,
        ).thenReturn('token');
        // Throw a non-FirebaseAuthException, non-GoogleSignInException
        when(
          () => mockUser.linkWithCredential(any()),
        ).thenThrow(Exception('Unexpected error'));

        when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async {});

        // Act & Assert
        await expectLater(
          repository.linkAnonymousToGoogle(),
          throwsA(
            isA<AuthException>().having(
              (e) => e.userMessage,
              'userMessage',
              contains('unexpected error'),
            ),
          ),
        );

        // Verify Google Sign-In cleanup was called
        verify(() => mockGoogleSignIn.signOut()).called(1);
      },
    );

    test(
      'linkAnonymousToGoogle uses linkWithCredential, not signInWithCredential',
      () async {
        // Regression test: ensure we use linkWithCredential (preserve UID)
        // and NOT signInWithCredential (would create new session)
        const testUid = 'preserved-anon-uid';

        when(() => mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn(testUid);
        when(() => mockUser.isAnonymous).thenReturn(true);

        when(
          () => mockGoogleSignIn.authenticate(),
        ).thenAnswer((_) async => mockGoogleSignInAccount);
        when(() => mockGoogleSignInAccount.email).thenReturn('u@g.com');
        when(
          () => mockGoogleSignInAccount.authentication,
        ).thenReturn(mockGoogleSignInAuthentication);
        when(
          () => mockGoogleSignInAuthentication.idToken,
        ).thenReturn('id-token');

        when(
          () => mockUser.linkWithCredential(any()),
        ).thenAnswer((_) async => mockUserCredential);
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockUser.email).thenReturn('u@g.com');
        when(() => mockUser.displayName).thenReturn(null);
        when(() => mockUser.photoURL).thenReturn(null);

        await repository.linkAnonymousToGoogle();

        // CRITICAL: must use linkWithCredential, not signInWithCredential
        verify(() => mockUser.linkWithCredential(any())).called(1);
        verifyNever(() => mockFirebaseAuth.signInWithCredential(any()));
      },
    );
  });

  group('FirebaseAuthRepository - Anonymous Sign-In Tests', () {
    test(
      'signInAnonymously succeeds and returns UserEntity with isAnonymous=true',
      () async {
        // Arrange
        const testUid = 'anonymous-uid-12345';

        // Mock FirebaseAuth.signInAnonymously
        when(
          () => mockFirebaseAuth.signInAnonymously(),
        ).thenAnswer((_) async => mockUserCredential);

        // Mock UserCredential and User
        when(() => mockUserCredential.user).thenReturn(mockUser);
        when(() => mockUser.uid).thenReturn(testUid);
        when(() => mockUser.email).thenReturn('');
        when(() => mockUser.displayName).thenReturn(null);
        when(() => mockUser.photoURL).thenReturn(null);
        when(() => mockUser.isAnonymous).thenReturn(true);

        // Act
        final result = await repository.signInAnonymously();

        // Assert
        expect(result, isNotNull);
        expect(result!.id, testUid);
        expect(result.isAnonymous, isTrue);
        expect(result.email, '');

        // Verify signInAnonymously was called
        verify(() => mockFirebaseAuth.signInAnonymously()).called(1);
      },
    );

    test('signInAnonymously returns null when user is null', () async {
      // Arrange
      when(
        () => mockFirebaseAuth.signInAnonymously(),
      ).thenAnswer((_) async => mockUserCredential);

      when(() => mockUserCredential.user).thenReturn(null);

      // Act
      final result = await repository.signInAnonymously();

      // Assert
      expect(result, isNull);
    });

    test(
      'signInAnonymously throws AuthException.signInFailed on FirebaseAuthException',
      () async {
        // Arrange
        final firebaseException = FirebaseAuthException(
          code: 'network-request-failed',
          message: 'Network error',
        );

        when(
          () => mockFirebaseAuth.signInAnonymously(),
        ).thenThrow(firebaseException);

        // Act & Assert
        expect(() => repository.signInAnonymously(), throwsA(isA<Exception>()));

        verify(() => mockFirebaseAuth.signInAnonymously()).called(1);
      },
    );

    test(
      'signInAnonymously throws AuthException.signInFailed on generic exception',
      () async {
        // Arrange
        when(
          () => mockFirebaseAuth.signInAnonymously(),
        ).thenThrow(Exception('Generic error'));

        // Act & Assert
        expect(() => repository.signInAnonymously(), throwsA(isA<Exception>()));

        verify(() => mockFirebaseAuth.signInAnonymously()).called(1);
      },
    );
  });
}