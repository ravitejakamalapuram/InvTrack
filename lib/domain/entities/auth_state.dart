import 'package:inv_tracker/domain/entities/user.dart';

/// Represents the authentication status of the app.
enum AuthStatus {
  /// Initial state before auth check is complete.
  initial,

  /// Currently checking authentication status.
  loading,

  /// User is authenticated.
  authenticated,

  /// User is not authenticated.
  unauthenticated,

  /// Authentication error occurred.
  error,
}

/// Represents the complete authentication state of the app.
///
/// This immutable state object contains the current auth status,
/// the authenticated user (if any), and any error message.
class AuthState {
  /// Current authentication status.
  final AuthStatus status;

  /// The authenticated user, if any.
  final User? user;

  /// Error message, if status is [AuthStatus.error].
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  /// Initial state before any auth operations.
  const AuthState.initial()
      : status = AuthStatus.initial,
        user = null,
        errorMessage = null;

  /// Loading state during auth operations.
  const AuthState.loading()
      : status = AuthStatus.loading,
        user = null,
        errorMessage = null;

  /// Authenticated state with a user.
  AuthState.authenticated(User this.user)
      : status = AuthStatus.authenticated,
        errorMessage = null;

  /// Unauthenticated state (signed out).
  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        user = null,
        errorMessage = null;

  /// Error state with message.
  AuthState.error(String this.errorMessage)
      : status = AuthStatus.error,
        user = null;

  /// Whether the user is currently authenticated.
  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  /// Whether authentication is in progress.
  bool get isLoading => status == AuthStatus.loading;

  /// Whether there's an error.
  bool get hasError => status == AuthStatus.error;

  /// Creates a copy with the given fields replaced.
  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AuthState &&
        other.status == status &&
        other.user == user &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => status.hashCode ^ user.hashCode ^ errorMessage.hashCode;

  @override
  String toString() {
    return 'AuthState(status: $status, user: $user, error: $errorMessage)';
  }
}

