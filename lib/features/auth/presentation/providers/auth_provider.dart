import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';

/// Provider for the GoogleSignIn instance.
/// Uses the singleton pattern as required by google_sign_in v7.
/// Initialize must be called before use (done in FirebaseAuthRepository).
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

/// Provider to track if GoogleSignIn has been initialized
final googleSignInInitializedProvider = FutureProvider<void>((ref) async {
  if (kIsWeb) {
    await GoogleSignIn.instance.initialize(
      clientId:
          '20057918856-r6qh2gt5eqk2o3oiq8fkt8pgfhquja6a.apps.googleusercontent.com',
    );
  } else {
    // Android/iOS: MUST pass serverClientId (Web Client ID) for google_sign_in v7+
    // This is the Web OAuth Client ID from google-services.json (client_type: 3)
    // Required to fix GoogleSignInException: "serverClientId must be provided on Android"
    // See: https://github.com/flutter/flutter/issues/172073
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '784857267556-dkge5l37c12n1ohrljle8s6nim0cgq84.apps.googleusercontent.com',
    );
  }
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
