import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';
import 'package:rxdart/rxdart.dart';
import 'package:uuid/uuid.dart';

class AuthRepositoryImpl implements AuthRepository {
  final GoogleSignIn _googleSignIn;
  final FlutterSecureStorage _secureStorage;
  // Initialize with null to ensure stream emits immediately
  final _authStateController = BehaviorSubject<UserEntity?>.seeded(null);
  bool _isInitialized = false;

  static const _guestKey = 'is_guest';
  static const _guestIdKey = 'guest_user_id';

  AuthRepositoryImpl(this._googleSignIn, this._secureStorage) {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Check for guest session
    final isGuest = await _secureStorage.read(key: _guestKey);
    if (isGuest == 'true') {
      // Retrieve the stored guest ID
      final guestId = await _secureStorage.read(key: _guestIdKey);
      if (guestId != null) {
        _authStateController.add(UserEntity(
          id: guestId,
          email: 'guest@local',
          displayName: 'Guest User',
          isGuest: true,
        ));
      } else {
        // Guest flag exists but no ID - this shouldn't happen, clear and require re-login
        await _secureStorage.delete(key: _guestKey);
        debugPrint('[Auth] Guest flag without ID, clearing session');
      }
    } else {
      // Check if we have a stored database ID (returning Google user)
      final storedDbId = await _secureStorage.read(key: _guestIdKey);

      // Initial check - try silent sign in first
      try {
        final currentUser = await _googleSignIn.signInSilently();
        if (currentUser != null && storedDbId != null) {
          // Returning user with stored database ID
          _authStateController.add(_mapGoogleUserToEntity(currentUser, storedDbId));
        }
        // If null or no stored ID, the seeded null value is correct (require fresh login)
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

      debugPrint('GoogleSignIn: Starting sign-in...');
      final googleUser = await _googleSignIn.signIn();
      debugPrint('GoogleSignIn: Result - ${googleUser?.email ?? 'null (user cancelled or error)'}');

      if (googleUser == null) {
        debugPrint('GoogleSignIn: User cancelled sign-in or an error occurred');
        return null;
      }

      // Generate new UUID for database isolation (fresh start)
      // Each Google sign-in gets a new database - cloud is source of truth
      final dbId = 'user_${const Uuid().v4()}';
      debugPrint('GoogleSignIn: Generated new database ID: $dbId');
      await _secureStorage.write(key: _guestIdKey, value: dbId);

      final user = _mapGoogleUserToEntity(googleUser, dbId);
      _authStateController.add(user);
      return user;
    } catch (e, stackTrace) {
      debugPrint('GoogleSignIn: Error - $e');
      debugPrint('GoogleSignIn: StackTrace - $stackTrace');
      rethrow;
    }
  }

  @override
  Future<UserEntity?> signInAsGuest() async {
    await _googleSignIn.signOut(); // Ensure google is signed out

    // Generate a NEW unique ID for this guest session
    // This ensures each "Continue as Guest" gets a fresh, isolated database
    final guestId = 'guest_${const Uuid().v4()}';
    debugPrint('[Auth] Creating new guest session with ID: $guestId');

    await _secureStorage.write(key: _guestKey, value: 'true');
    await _secureStorage.write(key: _guestIdKey, value: guestId);

    final guestUser = UserEntity(
      id: guestId,
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
    await _secureStorage.delete(key: _guestIdKey);
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

  /// Maps Google user to UserEntity.
  /// [dbId] is the database ID (UUID) for this user session.
  UserEntity? _mapGoogleUserToEntity(GoogleSignInAccount? googleUser, String dbId) {
    if (googleUser == null) return null;
    return UserEntity(
      id: dbId, // Use dbId instead of googleUser.id for database isolation
      email: googleUser.email,
      displayName: googleUser.displayName,
      photoUrl: googleUser.photoUrl,
    );
  }
}
