import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  /// Stream of the current user. Emits null if no user is signed in.
  Stream<UserEntity?> get authStateChanges;

  /// The current signed-in user, or null.
  UserEntity? get currentUser;

  /// Signs in with Google.
  Future<UserEntity?> signInWithGoogle();

  /// Signs in anonymously (guest mode).
  Future<UserEntity?> signInAnonymously();

  /// Links the current anonymous account to a Google account.
  ///
  /// This preserves the anonymous user's UID and data.
  /// Throws [AuthException] if:
  /// - User is not anonymous
  /// - Google account already exists (credential-already-in-use)
  /// - Linking fails for other reasons
  Future<UserEntity?> linkAnonymousToGoogle();

  /// Signs out.
  Future<void> signOut();

  /// Retrieves the current authentication token (e.g., for API calls).
  Future<String?> getAuthToken();

  /// Deletes the current user's account.
  /// This will delete the Firebase Auth account.
  /// Note: Firestore data cleanup should be handled separately before calling this.
  /// Throws [FirebaseAuthException] if re-authentication is required.
  Future<void> deleteAccount();

  /// Re-authenticates the user with Google.
  /// Required before sensitive operations like account deletion.
  /// Returns true if re-authentication was successful.
  Future<bool> reauthenticateWithGoogle();
}
