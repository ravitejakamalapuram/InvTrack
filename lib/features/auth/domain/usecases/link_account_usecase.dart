import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';

/// Use case for linking an anonymous account to a Google account.
///
/// This handles the business logic for account linking, including:
/// - Attempting to link anonymous account to Google credential
/// - Handling linking failures (e.g., Google account already exists)
/// - Returning appropriate results for UI to handle
class LinkAccountUseCase {
  final AuthRepository _authRepository;

  LinkAccountUseCase(this._authRepository);

  /// Attempts to link the current anonymous account to a Google account.
  ///
  /// Returns:
  /// - [LinkAccountResult.success] if linking succeeded
  /// - [LinkAccountResult.accountExists] if Google account already exists
  /// - [LinkAccountResult.notAnonymous] if current user is not anonymous
  /// - [LinkAccountResult.failure] for other errors
  Future<LinkAccountResult> execute() async {
    final currentUser = _authRepository.currentUser;

    // Check if user is anonymous
    if (currentUser == null || !currentUser.isAnonymous) {
      return LinkAccountResult.notAnonymous();
    }

    try {
      // Attempt to sign in with Google and link
      final linkedUser = await _authRepository.signInWithGoogle();

      if (linkedUser != null && !linkedUser.isAnonymous) {
        return LinkAccountResult.success(linkedUser);
      } else {
        return LinkAccountResult.failure('Linking failed: user is still anonymous');
      }
    } catch (e) {
      // Check if error is due to account already existing
      if (e.toString().contains('credential-already-in-use') ||
          e.toString().contains('account-exists-with-different-credential')) {
        return LinkAccountResult.accountExists();
      }

      return LinkAccountResult.failure(e.toString());
    }
  }
}

/// Result of account linking operation
sealed class LinkAccountResult {
  const LinkAccountResult();

  /// Linking succeeded, account is now linked to Google
  factory LinkAccountResult.success(UserEntity user) = LinkAccountSuccess;

  /// Google account already exists, cannot link
  factory LinkAccountResult.accountExists() = LinkAccountAccountExists;

  /// Current user is not anonymous, cannot link
  factory LinkAccountResult.notAnonymous() = LinkAccountNotAnonymous;

  /// Linking failed for other reasons
  factory LinkAccountResult.failure(String message) = LinkAccountFailure;
}

class LinkAccountSuccess extends LinkAccountResult {
  final UserEntity user;
  const LinkAccountSuccess(this.user);
}

class LinkAccountAccountExists extends LinkAccountResult {
  const LinkAccountAccountExists();
}

class LinkAccountNotAnonymous extends LinkAccountResult {
  const LinkAccountNotAnonymous();
}

class LinkAccountFailure extends LinkAccountResult {
  final String message;
  const LinkAccountFailure(this.message);
}

