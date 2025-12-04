import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final GoogleSignIn _googleSignIn;

  AuthRepositoryImpl(this._googleSignIn);

  @override
  Stream<UserEntity?> get authStateChanges {
    return _googleSignIn.onCurrentUserChanged.map(_mapGoogleUserToEntity);
  }

  @override
  UserEntity? get currentUser => _mapGoogleUserToEntity(_googleSignIn.currentUser);

  @override
  Future<UserEntity?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      return _mapGoogleUserToEntity(googleUser);
    } catch (e) {
      // Handle error or rethrow
      // For now, we just return null or let the UI handle the error via Future
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  @override
  Future<String?> getAuthToken() async {
    final googleUser = _googleSignIn.currentUser;
    if (googleUser == null) return null;
    final auth = await googleUser.authentication;
    return auth.accessToken;
  }

  UserEntity? _mapGoogleUserToEntity(GoogleSignInAccount? googleUser) {
    if (googleUser == null) return null;
    return UserEntity(
      id: googleUser.id,
      email: googleUser.email,
      displayName: googleUser.displayName,
      photoUrl: googleUser.photoUrl,
    );
  }
}
