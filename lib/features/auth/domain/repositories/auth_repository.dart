import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  /// Stream of the current user. Emits null if no user is signed in.
  Stream<UserEntity?> get authStateChanges;

  /// The current signed-in user, or null.
  UserEntity? get currentUser;

  /// Signs in with Google.
  Future<UserEntity?> signInWithGoogle();

  /// Signs in as a guest.
  Future<UserEntity?> signInAsGuest();

  /// Signs out.
  Future<void> signOut();

  /// Retrieves the current authentication token (e.g., for API calls).
  Future<String?> getAuthToken();
}
