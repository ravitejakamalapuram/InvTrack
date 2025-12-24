import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';

/// Provider for the GoogleSignIn instance.
/// Used for authentication only - Firebase Auth handles the actual auth state.
/// Note: serverClientId is only supported on Android/iOS, not on Web.
/// On Web, the clientId is configured via meta tag in index.html.
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  // Web uses clientId from meta tag in index.html, serverClientId is not supported
  if (kIsWeb) {
    return GoogleSignIn(
      scopes: ['email'],
      // Web client ID - must match the one in index.html meta tag
      clientId: '20057918856-r6qh2gt5eqk2o3oiq8fkt8pgfhquja6a.apps.googleusercontent.com',
    );
  }

  // Android/iOS use serverClientId for Firebase Auth
  return GoogleSignIn(
    scopes: ['email'],
    // Web client ID from google-services.json (client_type: 3)
    // Required for Firebase Auth to work correctly on Android
    serverClientId: '784857267556-dkge5l37c12n1ohrljle8s6nim0cgq84.apps.googleusercontent.com',
  );
});

/// Provider for FirebaseAuth instance.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for the AuthRepository using Firebase Auth.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final firebaseAuth = ref.watch(firebaseAuthProvider);
  final googleSignIn = ref.watch(googleSignInProvider);
  return FirebaseAuthRepository(
    firebaseAuth: firebaseAuth,
    googleSignIn: googleSignIn,
  );
});

/// Stream provider for the current user state.
final authStateProvider = StreamProvider<UserEntity?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});
