import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:inv_tracker/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';

/// Provider for the GoogleSignIn instance.
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: [
      'email',
      'https://www.googleapis.com/auth/drive.file', // Required for Drive sync
      'https://www.googleapis.com/auth/spreadsheets', // Required for Sheets sync
    ],
  );
});

/// Provider for the AuthRepository.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final googleSignIn = ref.watch(googleSignInProvider);
  return AuthRepositoryImpl(googleSignIn);
});

/// Stream provider for the current user state.
final authStateProvider = StreamProvider<UserEntity?>((ref) {
  final authRepository = ref.watch(authRepositoryProvider);
  return authRepository.authStateChanges;
});
