import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Asks a guest whether to back up their data and sign in to a Google
/// account that already exists. Returns true if they chose to continue.
Future<bool> showBackupMergeDialog(BuildContext context) async {
  final l10n = AppLocalizations.of(context);

  final confirmed = await showDialog<bool>(
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
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.backupAndSignIn),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Backs up the guest's data, signs in to Google and merges the backup into
/// that account, showing progress and the result.
///
/// The work runs in [guestBackupMergeServiceProvider], because the sign-in
/// rebuilds the router and can dispose [context] before it finishes. Only
/// app-level objects captured up front are used afterwards.
///
/// Returns true if the guest data now lives in the Google account.
Future<bool> backupAndMergeGuestData(
  BuildContext context,
  WidgetRef ref,
) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);
  final service = ref.read(guestBackupMergeServiceProvider);

  final loading = DialogRoute<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );
  navigator.push(loading);
  void hideLoading() {
    if (loading.isActive) loading.navigator?.removeRoute(loading);
  }

  final GuestMergeOutcome outcome;
  try {
    outcome = await service.backupAndSignIn();
  } catch (e, st) {
    hideLoading();
    // Backup or sign-in failed before the session changed: the guest is
    // still signed in with all of their data.
    ErrorHandler.handle(
      e,
      st,
      context: context.mounted ? context : null,
      showFeedback: true,
    );
    return false;
  }
  hideLoading();

  switch (outcome) {
    case GuestMergeCancelled():
      return false;
    case GuestMergeSucceeded():
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.guestDataMerged),
            backgroundColor: AppColors.successLight,
          ),
        );
      }
      return true;
    case GuestMergeImportFailed(:final backup):
      await _offerBackup(navigator, messenger, l10n, service, backup);
      return false;
  }
}

/// Lets the user save the only full copy of their guest data.
Future<void> _offerBackup(
  NavigatorState navigator,
  ScaffoldMessengerState messenger,
  AppLocalizations l10n,
  GuestBackupMergeService service,
  Uint8List backup,
) async {
  Future<void> share(BuildContext? context) async {
    try {
      await service.shareBackup(backup);
    } catch (e, st) {
      ErrorHandler.handle(
        e,
        st,
        context: context != null && context.mounted ? context : null,
        showFeedback: true,
      );
    }
  }

  if (!navigator.mounted) {
    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.guestMergeImportFailedMessage),
        duration: const Duration(minutes: 1),
        action: SnackBarAction(
          label: l10n.shareBackup,
          onPressed: () => share(null),
        ),
      ),
    );
    return;
  }

  await showDialog<void>(
    context: navigator.context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.guestMergeImportFailedTitle),
      content: Text(l10n.guestMergeImportFailedMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.close),
        ),
        FilledButton(
          onPressed: () async {
            await share(dialogContext);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: Text(l10n.shareBackup),
        ),
      ],
    ),
  );
}
