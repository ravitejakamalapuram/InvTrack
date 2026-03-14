import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';

/// Firebase Auth implementation that uses Google Sign-In for authentication
/// and Firebase Auth for state management and Firestore security
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
  }) : _firebaseAuth = firebaseAuth,
       _googleSignIn = googleSignIn;

  @override
  Stream<UserEntity?> get authStateChanges {
    return _firebaseAuth.authStateChanges().map((firebaseUser) {
      if (firebaseUser != null) {
        return _mapFirebaseUserToEntity(firebaseUser);
      }
      return null;
    });
  }

  @override
  UserEntity? get currentUser {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      return _mapFirebaseUserToEntity(firebaseUser);
    }
    return null;
  }

  @override
  Future<UserEntity?> signInWithGoogle() async {
    try {
      LoggerService.info('Starting Google Sign-In');

      // In google_sign_in v7, for Firebase Auth we use authenticate() with NO scopes
      // This gets us the idToken without requesting OAuth access tokens
      // The key is to NOT pass any scopeHint - this makes it identity-only
      final googleUser = await _googleSignIn.authenticate();

      LoggerService.debug('Got Google user: ${googleUser.email}');

      // Get Google auth credentials
      // In google_sign_in v7, authentication property (not Future) only provides idToken
      // Firebase Auth only needs idToken, not accessToken
      final googleAuth = googleUser.authentication;

      LoggerService.debug('Got idToken: ${googleAuth.idToken != null}');

      // Create Firebase credential with idToken only
      // accessToken is not needed for Firebase Auth
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      LoggerService.info('Signing in to Firebase with Google credentials');
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      LoggerService.info(
        'Google Sign-In successful',
        metadata: {'userId': userCredential.user?.uid},
      );
      return userCredential.user != null
          ? _mapFirebaseUserToEntity(userCredential.user!)
          : null;
    } on GoogleSignInException catch (e) {
      LoggerService.error(
        'GoogleSignInException during sign-in',
        error: e,
        metadata: {
          'code': e.code.name,
          'description': e.description,
          'details': e.details.toString(),
        },
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        LoggerService.info('User cancelled Google Sign-In');
        return null;
      }
      // Map exception to user-friendly message
      throw Exception(_mapGoogleSignInException(e));
    } catch (e, stackTrace) {
      LoggerService.error(
        'Google Sign-In failed',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Map GoogleSignInException to user-friendly error message
  String _mapGoogleSignInException(GoogleSignInException exception) {
    switch (exception.code) {
      case GoogleSignInExceptionCode.canceled:
        return 'Sign-in was cancelled. Please try again if you want to continue.';
      case GoogleSignInExceptionCode.interrupted:
        return 'Sign-in was interrupted. Please try again.';
      case GoogleSignInExceptionCode.clientConfigurationError:
        return 'There is a configuration issue with Google Sign-In. Please contact support.';
      case GoogleSignInExceptionCode.providerConfigurationError:
        return 'Google Sign-In is currently unavailable. Please try again later or contact support.';
      case GoogleSignInExceptionCode.uiUnavailable:
        return 'Google Sign-In is currently unavailable. Please try again later or contact support.';
      case GoogleSignInExceptionCode.userMismatch:
        return 'There was an issue with your account. Please sign out and try again.';
      case GoogleSignInExceptionCode.unknownError:
        return 'An unexpected error occurred during Google Sign-In: ${exception.description ?? "Unknown error"}. Please try again.';
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  @override
  Future<String?> getAuthToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  @override
  Future<bool> reauthenticateWithGoogle() async {
    try {
      LoggerService.info('Re-authenticating with Google');

      final user = _firebaseAuth.currentUser;
      if (user == null) {
        LoggerService.warn('No current user for re-authentication');
        return false;
      }

      // Sign out first to force fresh authentication
      await _googleSignIn.signOut();

      // Authenticate with Google
      final googleUser = await _googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
      LoggerService.info(
        'Re-authentication successful',
        metadata: {'userId': user.uid},
      );
      return true;
    } on GoogleSignInException catch (e) {
      LoggerService.error(
        'GoogleSignInException during re-authentication',
        error: e,
        metadata: {
          'code': e.code.name,
          'description': e.description,
          'details': e.details.toString(),
        },
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        LoggerService.info('User cancelled re-authentication');
        return false;
      }
      throw Exception(_mapGoogleSignInException(e));
    } catch (e, stackTrace) {
      LoggerService.error(
        'Re-authentication failed',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-user',
        message: 'No user is currently signed in',
      );
    }

    LoggerService.info('Deleting user account', metadata: {'userId': user.uid});

    try {
      // Only sign out from Google for non-anonymous users
      if (!user.isAnonymous) {
        await _googleSignIn.signOut();
      }

      // Delete the Firebase Auth account
      await user.delete();

      LoggerService.info('Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        LoggerService.warn('Re-authentication required for account deletion');
      }
      rethrow;
    }
  }

  @override
  Future<UserEntity?> signInAnonymously() async {
    try {
      LoggerService.info('Starting Anonymous Sign-In');

      final userCredential = await _firebaseAuth.signInAnonymously();

      LoggerService.info(
        'Anonymous Sign-In successful',
        metadata: {'anonymous': true},
      );
      return userCredential.user != null
          ? _mapFirebaseUserToEntity(userCredential.user!)
          : null;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Anonymous Sign-In failed',
        error: e,
        stackTrace: stackTrace,
      );
      throw AuthException.signInFailed(
        cause: e,
        stackTrace: stackTrace,
      );
    }
  }

  UserEntity _mapFirebaseUserToEntity(User firebaseUser) {
    return UserEntity(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
      isAnonymous: firebaseUser.isAnonymous,
    );
  }
}
