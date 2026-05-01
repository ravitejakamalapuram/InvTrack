import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Shows a dialog for backing up guest data before signing in with an existing Google account.
///
/// Flow:
/// 1. User taps "Backup & Sign In"
/// 2. Create ZIP backup of anonymous data
/// 3. Sign in with Google (new session)
/// 4. Show success with import option
Future<bool?> showBackupMergeDialog(BuildContext context, WidgetRef ref) async {
  final l10n = AppLocalizations.of(context);

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.googleAccountExists),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.accountAlreadyRegistered),
          const SizedBox(height: 16),
          Text(l10n.guestDataBackupMessage),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.pop(dialogContext); // Close dialog
            await _handleBackupAndSignIn(context, ref);
          },
          child: Text(l10n.backupAndSignIn),
        ),
      ],
    ),
  );
}

Future<void> _handleBackupAndSignIn(BuildContext context, WidgetRef ref) async {
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  // Show loading
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    // 1. Create ZIP backup
    LoggerService.info('Creating ZIP backup before sign-in');
    final exportService = ref.read(dataExportServiceProvider);
    if (exportService == null) {
      throw Exception('User not authenticated');
    }
    final backupPath = await exportService.exportAsZip();

    // Track analytics
    final analytics = ref.read(analyticsServiceProvider);
    await analytics.logEvent(
      name: 'backup_created',
      parameters: {'trigger': 'account_linking_failure'},
    );

    // 2. Sign in with Google (creates new session)
    LoggerService.info('Signing in with Google after backup');
    final authRepo = ref.read(authRepositoryProvider);
    await authRepo.signInWithGoogle();

    // Track analytics
    await analytics.logEvent(
      name: 'account_link_failure',
      parameters: {'reason': 'google_account_exists'},
    );

    // Hide loading
    if (context.mounted) Navigator.pop(context);

    // 3. Show success with import option
    if (context.mounted) {
      final import = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final dialogL10n = AppLocalizations.of(dialogContext);
          return AlertDialog(
            title: Text(dialogL10n.backupCreated),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                Text(dialogL10n.guestDataBackedUp),
                const SizedBox(height: 8),
                Text(
                  dialogL10n.backupLocation(backupPath),
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Text(dialogL10n.importNowQuestion),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogL10n.later),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(dialogL10n.importNow),
              ),
            ],
          );
        },
      );

      if (import == true && context.mounted) {
        // Navigate to import screen
        context.go('/settings/data-management/import');
      }
    }
  } catch (e, st) {
    LoggerService.error('Backup and sign-in failed', error: e, stackTrace: st);

    // Hide loading
    if (context.mounted) Navigator.pop(context);

    if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(l10n.backupFailed(e.toString())),
          backgroundColor: AppColors.errorLight,
        ),
      );
    }
  }
}
