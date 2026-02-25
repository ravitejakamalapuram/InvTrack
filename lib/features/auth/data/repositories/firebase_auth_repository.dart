import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

      // Use authenticate() in google_sign_in v7
      // Note: initialize() must be called before authenticate() - handled by googleSignInInitializedProvider
      final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);

      LoggerService.debug('Got Google user');

      // Get Google auth credentials
      // In google_sign_in v7, authentication only provides idToken
      // For Firebase Auth, idToken is sufficient (accessToken is optional)
      final googleAuth = googleUser.authentication;

      LoggerService.debug('Got authentication tokens');

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      LoggerService.info('Signing in to Firebase with Google credentials');
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      LoggerService.info('Google Sign-In successful', metadata: {
        'userId': userCredential.user?.uid,
      });
      return userCredential.user != null
          ? _mapFirebaseUserToEntity(userCredential.user!)
          : null;
    } on GoogleSignInException catch (e) {
      LoggerService.warn(
        'GoogleSignInException during sign-in',
        metadata: {'code': e.code.toString()},
      );
      if (e.code == GoogleSignInExceptionCode.canceled) {
        LoggerService.info('User cancelled Google Sign-In');
        return null;
      }
      rethrow;
    } catch (e, stackTrace) {
      LoggerService.error(
        'Google Sign-In failed',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
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

      final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);
      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
      LoggerService.info('Re-authentication successful', metadata: {
        'userId': user.uid,
      });
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        LoggerService.info('User cancelled re-authentication');
        return false;
      }
      LoggerService.warn(
        'GoogleSignInException during re-authentication',
        metadata: {'code': e.code.toString()},
      );
      rethrow;
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

    LoggerService.info('Deleting user account', metadata: {
      'userId': user.uid,
    });

    try {
      // Sign out from Google first
      await _googleSignIn.signOut();

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

  UserEntity _mapFirebaseUserToEntity(User firebaseUser) {
    return UserEntity(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
  }
}
