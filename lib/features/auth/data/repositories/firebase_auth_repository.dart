import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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
      if (kDebugMode) {
        debugPrint('FirebaseAuth: Starting Google Sign-In...');
      }

      // Use authenticate() in google_sign_in v7
      // Note: initialize() must be called before authenticate() - handled by googleSignInInitializedProvider
      final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);

      if (kDebugMode) {
        debugPrint('FirebaseAuth: Got Google user');
      }

      // Get Google auth credentials using the new API
      // In v7, authentication provides idToken, and we get accessToken through authorization
      final googleAuth = googleUser.authentication;
      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(['email']);

      final credential = GoogleAuthProvider.credential(
        accessToken: authorization?.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      if (kDebugMode) {
        debugPrint('FirebaseAuth: Signing in to Firebase...');
      }
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      if (kDebugMode) {
        debugPrint('FirebaseAuth: Signed in successfully');
      }
      return userCredential.user != null
          ? _mapFirebaseUserToEntity(userCredential.user!)
          : null;
    } on GoogleSignInException catch (e) {
      if (kDebugMode) {
        debugPrint('FirebaseAuth: GoogleSignInException - code: ${e.code}');
      }
      if (e.code == GoogleSignInExceptionCode.canceled) {
        if (kDebugMode) {
          debugPrint('FirebaseAuth: User cancelled sign-in');
        }
        return null;
      }
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('FirebaseAuth: Error - $e');
        // Do not log stack trace in production to prevent leakage of internal structure
        debugPrint('FirebaseAuth: StackTrace - $stackTrace');
      }
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
      if (kDebugMode) {
        debugPrint('FirebaseAuth: Re-authenticating with Google...');
      }

      final user = _firebaseAuth.currentUser;
      if (user == null) {
        if (kDebugMode) {
          debugPrint('FirebaseAuth: No current user for re-authentication');
        }
        return false;
      }

      // Sign out first to force fresh authentication
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);
      final googleAuth = googleUser.authentication;
      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(['email']);

      final credential = GoogleAuthProvider.credential(
        accessToken: authorization?.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
      if (kDebugMode) {
        debugPrint('FirebaseAuth: Re-authentication successful');
      }
      return true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        if (kDebugMode) {
          debugPrint('FirebaseAuth: User cancelled re-authentication');
        }
        return false;
      }
      if (kDebugMode) {
        debugPrint(
          'FirebaseAuth: GoogleSignInException during reauth - ${e.code}',
        );
      }
      rethrow;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('FirebaseAuth: Re-authentication error - $e');
        debugPrint('FirebaseAuth: StackTrace - $stackTrace');
      }
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

    if (kDebugMode) {
      debugPrint('FirebaseAuth: Deleting user account...');
    }

    try {
      // Sign out from Google first
      await _googleSignIn.signOut();

      // Delete the Firebase Auth account
      await user.delete();

      if (kDebugMode) {
        debugPrint('FirebaseAuth: Account deleted successfully');
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (kDebugMode) {
          debugPrint('FirebaseAuth: Re-authentication required for deletion');
        }
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
