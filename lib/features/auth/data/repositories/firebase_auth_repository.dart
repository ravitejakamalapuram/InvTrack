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
      debugPrint('FirebaseAuth: Starting Google Sign-In...');

      // Use authenticate() in google_sign_in v7
      // Note: initialize() must be called before authenticate() - handled by googleSignInInitializedProvider
      final googleUser = await _googleSignIn.authenticate(scopeHint: ['email']);

      debugPrint('FirebaseAuth: Got Google user: ${googleUser.email}');

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
      debugPrint('FirebaseAuth: Signing in to Firebase...');
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      debugPrint('FirebaseAuth: Signed in as ${userCredential.user?.email}');
      return userCredential.user != null
          ? _mapFirebaseUserToEntity(userCredential.user!)
          : null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('FirebaseAuth: User cancelled sign-in');
        return null;
      }
      debugPrint('FirebaseAuth: GoogleSignInException - ${e.code}');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('FirebaseAuth: Error - $e');
      debugPrint('FirebaseAuth: StackTrace - $stackTrace');
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

  UserEntity _mapFirebaseUserToEntity(User firebaseUser) {
    return UserEntity(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      displayName: firebaseUser.displayName,
      photoUrl: firebaseUser.photoURL,
    );
  }
}
