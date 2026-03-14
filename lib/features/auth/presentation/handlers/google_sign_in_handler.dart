import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/auth/domain/usecases/link_account_usecase.dart';
import 'package:inv_tracker/features/auth/presentation/dialogs/backup_merge_dialog.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';

/// Provider for LinkAccountUseCase
final linkAccountUseCaseProvider = Provider<LinkAccountUseCase>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return LinkAccountUseCase(authRepo);
});

/// Handles Google Sign-In with account linking for anonymous users.
///
/// This handler:
/// 1. Checks if user is anonymous
/// 2. Attempts to link anonymous account to Google
/// 3. If linking fails (Google account exists), shows backup & merge dialog
/// 4. Handles all error cases with proper user feedback
class GoogleSignInHandler {
  final WidgetRef ref;
  final BuildContext context;

  GoogleSignInHandler({
    required this.ref,
    required this.context,
  });

  /// Handles the Google Sign-In flow with account linking.
  ///
  /// Returns true if sign-in/linking succeeded, false otherwise.
  Future<bool> handleSignIn() async {
    try {
      LoggerService.info('Starting Google Sign-In with account linking');

      final linkUseCase = ref.read(linkAccountUseCaseProvider);
      final result = await linkUseCase.execute();

      return switch (result) {
        LinkAccountSuccess() => _handleSuccess(result),
        LinkAccountAccountExists() => await _handleAccountExists(),
        LinkAccountNotAnonymous() => _handleNotAnonymous(),
        LinkAccountFailure() => _handleFailure(result),
      };
    } catch (e, st) {
      LoggerService.error(
        'Google Sign-In handler failed',
        error: e,
        stackTrace: st,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }

      return false;
    }
  }

  bool _handleSuccess(LinkAccountSuccess result) {
    LoggerService.info(
      'Account linking succeeded',
      metadata: {'anonymous': false},
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account linked successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }

    return true;
  }

  Future<bool> _handleAccountExists() async {
    LoggerService.info('Google account already exists, showing backup dialog');

    if (!context.mounted) return false;

    // Show backup & merge dialog
    final result = await showBackupMergeDialog(context, ref);

    return result ?? false;
  }

  bool _handleNotAnonymous() {
    LoggerService.debug('User is not anonymous, no linking needed');
    return true; // Already signed in
  }

  bool _handleFailure(LinkAccountFailure result) {
    LoggerService.error('Account linking failed', error: result.message);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Linking failed: ${result.message}'),
          backgroundColor: Colors.red,
        ),
      );
    }

    return false;
  }
}

