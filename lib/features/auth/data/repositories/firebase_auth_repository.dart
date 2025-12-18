import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';

/// Firebase Auth implementation that uses Google Sign-In for authentication
/// and Firebase Auth for state management and Firestore security
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage;

  static const _guestKey = 'is_guest';

  FirebaseAuthRepository({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
    required FlutterSecureStorage secureStorage,
  })  : _firebaseAuth = firebaseAuth,
        _googleSignIn = googleSignIn,
        _secureStorage = secureStorage;

  @override
  Stream<UserEntity?> get authStateChanges {
    return _firebaseAuth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser != null) {
        return _mapFirebaseUserToEntity(firebaseUser);
      }
      // Check for guest session
      final isGuest = await _secureStorage.read(key: _guestKey);
      if (isGuest == 'true') {
        return const UserEntity(
          id: 'guest',
          email: 'guest@local',
          displayName: 'Guest User',
          isGuest: true,
        );
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
      // Clear guest session if exists
      await _secureStorage.delete(key: _guestKey);

      debugPrint('FirebaseAuth: Starting Google Sign-In...');
      final googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        debugPrint('FirebaseAuth: User cancelled sign-in');
        return null;
      }

      debugPrint('FirebaseAuth: Got Google user: ${googleUser.email}');
      
      // Get Google auth credentials
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credentials
      debugPrint('FirebaseAuth: Signing in to Firebase...');
      final userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      debugPrint('FirebaseAuth: Signed in as ${userCredential.user?.email}');
      return userCredential.user != null 
          ? _mapFirebaseUserToEntity(userCredential.user!)
          : null;
    } catch (e, stackTrace) {
      debugPrint('FirebaseAuth: Error - $e');
      debugPrint('FirebaseAuth: StackTrace - $stackTrace');
      rethrow;
    }
  }

  @override
  Future<UserEntity?> signInAsGuest() async {
    // Sign out of Firebase and Google
    await _firebaseAuth.signOut();
    await _googleSignIn.signOut();
    
    // Set guest flag
    await _secureStorage.write(key: _guestKey, value: 'true');
    
    return const UserEntity(
      id: 'guest',
      email: 'guest@local',
      displayName: 'Guest User',
      isGuest: true,
    );
  }

  @override
  Future<void> signOut() async {
    await _secureStorage.delete(key: _guestKey);
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
      isGuest: false,
    );
  }
}

