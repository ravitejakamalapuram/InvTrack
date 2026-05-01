import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/core/config/google_sign_in_config.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
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
///
/// BUG FIX (2026-05-01): Added comprehensive error handling and logging
/// to prevent silent initialization failures that caused Crashlytics issue #9dfdf1143e4d5e88cbfe9a9d91440e44
final googleSignInInitializedProvider = FutureProvider<void>((ref) async {
  try {
    if (kIsWeb) {
      await GoogleSignIn.instance.initialize(
        clientId: GoogleSignInConfig.webClientId,
      );
    } else {
      // Android/iOS: MUST pass serverClientId (Web Client ID) for google_sign_in v7+
      // This is the Web OAuth Client ID from google-services.json (client_type: 3)
      // Required to fix GoogleSignInException: "serverClientId must be provided on Android"
      // See: https://github.com/flutter/flutter/issues/172073

      // Validate configuration before initialization
      if (GoogleSignInConfig.androidServerClientId.isEmpty) {
        throw StateError(
          'GoogleSignInConfig.androidServerClientId is empty. '
          'This should be the Web OAuth Client ID from google-services.json (client_type: 3).',
        );
      }

      await GoogleSignIn.instance.initialize(
        serverClientId: GoogleSignInConfig.androidServerClientId,
      );
    }
  } catch (e, st) {
    // BUGFIX (2026-05-01): Use LoggerService instead of print() to comply with security rules
    // Log initialization failure for debugging
    LoggerService.error(
      'GoogleSignIn initialization failed',
      error: e,
      stackTrace: st,
      metadata: {
        'platform': defaultTargetPlatform.toString(),
        'serverClientId': GoogleSignInConfig.androidServerClientId,
      },
    );
    rethrow; // Re-throw to mark provider as failed
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
