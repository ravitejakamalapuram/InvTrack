import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/data/datasources/auth_service.dart';
import 'package:inv_tracker/domain/entities/auth_state.dart';
import 'package:inv_tracker/domain/entities/user.dart';

/// Provider for the AuthService singleton.
final authServiceProvider = Provider<AuthService>((ref) {
  final service = AuthService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider for the current authentication state.
///
/// This is the main provider to use for checking auth status
/// and accessing the current user.
final authStateProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

/// Provider for quick access to the current user.
///
/// Returns null if not authenticated.
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.user;
});

/// Provider to check if user is authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.isAuthenticated;
});

/// Notifier that manages authentication state.
///
/// Handles sign-in, sign-out, and listens to auth state changes.
class AuthNotifier extends Notifier<AuthState> {
  late final AuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  @override
  AuthState build() {
    _authService = ref.watch(authServiceProvider);

    // Initialize on first build
    Future.microtask(_init);

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return const AuthState.initial();
  }

  /// Initializes the auth state by checking for existing session.
  Future<void> _init() async {
    state = const AuthState.loading();

    try {
      // Initialize the auth service first
      await _authService.initialize();

      // Listen to auth state changes
      _authSubscription = _authService.authStateChanges.listen((user) {
        if (user != null) {
          state = AuthState.authenticated(user);
        } else {
          state = const AuthState.unauthenticated();
        }
      });

      // Try to restore previous session
      final user = await _authService.signInSilently();
      if (user != null) {
        state = AuthState.authenticated(user);
      } else {
        state = const AuthState.unauthenticated();
      }
    } catch (e) {
      state = const AuthState.unauthenticated();
    }
  }

  /// Signs in the user with Google.
  Future<void> signIn() async {
    state = const AuthState.loading();

    try {
      final user = await _authService.signIn();
      state = AuthState.authenticated(user);
    } on AuthException catch (e) {
      state = AuthState.error(e.message);
    } catch (e) {
      state = AuthState.error('An unexpected error occurred');
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    state = const AuthState.loading();

    try {
      await _authService.signOut();
      state = const AuthState.unauthenticated();
    } catch (e) {
      state = AuthState.error('Failed to sign out');
    }
  }

  /// Clears any error state.
  void clearError() {
    if (state.hasError) {
      state = const AuthState.unauthenticated();
    }
  }
}

