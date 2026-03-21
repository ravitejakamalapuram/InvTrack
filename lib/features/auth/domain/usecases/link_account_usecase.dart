import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/features/auth/domain/entities/user_entity.dart';
import 'package:inv_tracker/features/auth/domain/repositories/auth_repository.dart';

/// Use case for linking an anonymous account to a Google account.
///
/// This handles the business logic for account linking, including:
/// - Attempting to link anonymous account to Google credential using Firebase linkWithCredential
/// - Handling linking failures (e.g., Google account already exists)
/// - Returning appropriate results for UI to handle
///
/// IMPORTANT: This uses Firebase's linkWithCredential() API to preserve the anonymous UID
/// and all associated Firestore data. It does NOT create a new user session.
class LinkAccountUseCase {
  final AuthRepository _authRepository;

  LinkAccountUseCase(this._authRepository);

  /// Attempts to link the current anonymous account to a Google account.
  ///
  /// Returns:
  /// - [LinkAccountResult.success] if linking succeeded (UID preserved)
  /// - [LinkAccountResult.accountExists] if Google account already exists
  /// - [LinkAccountResult.notAnonymous] if current user is not anonymous
  /// - [LinkAccountResult.cancelled] if user cancelled Google Sign-In
  /// - [LinkAccountResult.failure] for other errors
  Future<LinkAccountResult> execute() async {
    final currentUser = _authRepository.currentUser;

    // Check if user is anonymous
    if (currentUser == null || !currentUser.isAnonymous) {
      return LinkAccountResult.notAnonymous();
    }

    try {
      // Use Firebase linkWithCredential to preserve UID and data
      final linkedUser = await _authRepository.linkAnonymousToGoogle();

      if (linkedUser != null && !linkedUser.isAnonymous) {
        return LinkAccountResult.success(linkedUser);
      } else {
        return LinkAccountResult.failure(
          'Linking failed: user is still anonymous',
        );
      }
    } on AuthException catch (e) {
      // Handle specific auth exceptions using error codes
      switch (e.code) {
        case AuthExceptionCode.credentialAlreadyInUse:
          return LinkAccountResult.accountExists();
        case AuthExceptionCode.cancelled:
          return LinkAccountResult.cancelled();
        default:
          return LinkAccountResult.failure(e.userMessage);
      }
    } catch (e) {
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

  /// User cancelled Google Sign-In
  factory LinkAccountResult.cancelled() = LinkAccountCancelled;

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

class LinkAccountCancelled extends LinkAccountResult {
  const LinkAccountCancelled();
}

class LinkAccountFailure extends LinkAccountResult {
  final String message;
  const LinkAccountFailure(this.message);
}
