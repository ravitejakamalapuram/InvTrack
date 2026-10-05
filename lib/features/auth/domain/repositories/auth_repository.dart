import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  /// Stream of the current user. Emits null if no user is signed in.
  Stream<UserEntity?> get authStateChanges;

  /// The current signed-in user, or null.
  UserEntity? get currentUser;

  /// When the current user last signed in, or null if unknown. Firebase asks
  /// for a recent login before sensitive operations such as account deletion.
  DateTime? get lastSignInTime;

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

  /// Signs in to the Google account that the last [linkAnonymousToGoogle]
  /// found already registered, with the credential that link produced, so
  /// the user does not pick the account a second time.
  ///
  /// The credential is used at most once and is dropped on sign-out. Returns
  /// null when none is kept. Throws [AuthException] with
  /// [AuthExceptionCode.invalidCredential] when Firebase rejects it (an
  /// expired token, for example); [signInWithGoogle] then asks again.
  Future<UserEntity?> signInWithLinkCredential();

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
  /// Returns true if re-authentication was successful and false only when the
  /// user cancelled it (or nobody is signed in). Throws when it failed, so
  /// callers can tell a cancel from a failure.
  Future<bool> reauthenticateWithGoogle();
}
