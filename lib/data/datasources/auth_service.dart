import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/core/constants/app_constants.dart';
import 'package:inv_tracker/domain/entities/user.dart';

/// Service responsible for Google Sign-In authentication.
///
/// This service wraps the google_sign_in package (v7.x) and provides
/// a clean interface for authentication operations.
class AuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final StreamController<User?> _authStateController =
      StreamController<User?>.broadcast();

  GoogleSignInAccount? _currentAccount;
  bool _initialized = false;

  /// Initialize the auth service.
  Future<void> initialize() async {
    if (_initialized) return;

    await _googleSignIn.initialize(
      clientId: GoogleAuthConstants.webClientId,
    );

    // Listen to authentication events
    _googleSignIn.authenticationEvents.listen((event) {
      switch (event) {
        case GoogleSignInAuthenticationEventSignIn():
          _currentAccount = event.user;
          _authStateController.add(_mapGoogleUserToUser(event.user));
        case GoogleSignInAuthenticationEventSignOut():
          _currentAccount = null;
          _authStateController.add(null);
      }
    });

    _initialized = true;
  }

  /// Stream of authentication state changes.
  Stream<User?> get authStateChanges => _authStateController.stream;

  /// Gets the currently signed-in user, if any.
  User? get currentUser => _mapGoogleUserToUser(_currentAccount);

  /// Whether a user is currently signed in.
  bool get isSignedIn => _currentAccount != null;

  /// Attempts to sign in silently (without user interaction).
  Future<User?> signInSilently() async {
    try {
      await _googleSignIn.attemptLightweightAuthentication();
      // Wait a bit for the auth event to fire
      await Future.delayed(const Duration(milliseconds: 100));
      return currentUser;
    } catch (e) {
      return null;
    }
  }

  /// Initiates the Google Sign-In flow.
  Future<User> signIn() async {
    try {
      // Check if platform supports authenticate
      if (_googleSignIn.supportsAuthenticate()) {
        await _googleSignIn.authenticate();
      } else {
        // For web, we need to use a different approach
        await _googleSignIn.authenticate();
      }

      // Wait for auth event
      await Future.delayed(const Duration(milliseconds: 200));

      if (_currentAccount == null) {
        throw AuthException('Sign-in was cancelled or failed');
      }

      return _mapGoogleUserToUser(_currentAccount)!;
    } on Exception catch (e) {
      throw AuthException('Sign-in failed: ${e.toString()}');
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentAccount = null;
    _authStateController.add(null);
  }

  /// Disconnects the user's Google account from the app.
  Future<void> disconnect() async {
    await _googleSignIn.disconnect();
    _currentAccount = null;
    _authStateController.add(null);
  }

  /// Gets an access token for API calls.
  Future<String?> getAccessToken() async {
    if (_currentAccount == null) return null;

    try {
      final authorization = await _currentAccount!.authorizationClient
          .authorizationForScopes(GoogleAuthConstants.scopes);
      return authorization?.accessToken;
    } catch (e) {
      return null;
    }
  }

  /// Gets the authentication headers for API requests.
  Future<Map<String, String>?> getAuthHeaders() async {
    final token = await getAccessToken();
    if (token == null) return null;
    return {'Authorization': 'Bearer $token'};
  }

  /// Maps a GoogleSignInAccount to our User entity.
  User? _mapGoogleUserToUser(GoogleSignInAccount? googleUser) {
    if (googleUser == null) return null;

    return User(
      id: googleUser.id,
      email: googleUser.email,
      displayName: googleUser.displayName,
      photoUrl: googleUser.photoUrl,
    );
  }

  /// Dispose the service.
  void dispose() {
    _authStateController.close();
  }
}

/// Exception thrown when authentication fails.
class AuthException implements Exception {
  final String message;

  AuthException(this.message);

  @override
  String toString() => message;
}

