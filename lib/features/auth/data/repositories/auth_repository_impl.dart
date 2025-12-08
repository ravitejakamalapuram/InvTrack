import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:rxdart/rxdart.dart';

class AuthRepositoryImpl implements AuthRepository {
  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage;
  // Initialize with null to ensure stream emits immediately
  final _authStateController = BehaviorSubject<UserEntity?>.seeded(null);
  bool _isInitialized = false;

  static const _guestKey = 'is_guest';

  AuthRepositoryImpl(this._googleSignIn, this._secureStorage) {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Check for guest session
    final isGuest = await _secureStorage.read(key: _guestKey);
    if (isGuest == 'true') {
      _authStateController.add(const UserEntity(
        id: 'guest',
        email: 'guest@local',
        displayName: 'Guest User',
        isGuest: true,
      ));
    } else {
      // Listen to Google Sign-In changes
      _googleSignIn.onCurrentUserChanged.listen((googleUser) {
        _authStateController.add(_mapGoogleUserToEntity(googleUser));
      });
      // Initial check - try silent sign in first
      try {
        final currentUser = await _googleSignIn.signInSilently();
        if (currentUser != null) {
          _authStateController.add(_mapGoogleUserToEntity(currentUser));
        }
        // If null, the seeded null value is already correct
      } catch (e) {
        // Silent sign-in failed, user needs to sign in manually
        // The seeded null value is already correct
      }
    }
  }

  @override
  Stream<UserEntity?> get authStateChanges => _authStateController.stream;

  @override
  UserEntity? get currentUser => _authStateController.valueOrNull;

  @override
  Future<UserEntity?> signInWithGoogle() async {
    try {
      // Clear guest session if exists
      await _secureStorage.delete(key: _guestKey);
      
      final googleUser = await _googleSignIn.signIn();
      final user = _mapGoogleUserToEntity(googleUser);
      _authStateController.add(user);
      return user;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserEntity?> signInAsGuest() async {
    await _googleSignIn.signOut(); // Ensure google is signed out
    await _secureStorage.write(key: _guestKey, value: 'true');
    
    const guestUser = UserEntity(
      id: 'guest',
      email: 'guest@local',
      displayName: 'Guest User',
      isGuest: true,
    );
    _authStateController.add(guestUser);
    return guestUser;
  }

  @override
  Future<void> signOut() async {
    await _secureStorage.delete(key: _guestKey);
    await _googleSignIn.signOut();
    _authStateController.add(null);
  }

  @override
  Future<String?> getAuthToken() async {
    if (currentUser?.isGuest == true) return null;
    
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
