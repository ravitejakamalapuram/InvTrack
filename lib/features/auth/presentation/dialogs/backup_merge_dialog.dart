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

  DialogRoute<void>? loading;
  void showLoading() {
    if (!navigator.mounted) return;
    loading = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    navigator.push(loading!);
  }

  void hideLoading() {
    final route = loading;
    if (route != null && route.isActive) route.navigator?.removeRoute(route);
    loading = null;
  }

  // Asked before the sign-in, while the guest can still stop and keep
  // everything.
  Future<bool> confirmDetailsNotMoved(_) async {
    hideLoading();
    if (!navigator.mounted) return false;
    final goAhead = await showDialog<bool>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.guestMergeDetailsWillNotMoveTitle),
        content: Text(l10n.guestMergeDetailsWillNotMoveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.guestMergeSignInWithoutDetails),
          ),
        ],
      ),
    );
    if (goAhead == true) showLoading();
    return goAhead == true;
  }

  showLoading();
  final GuestMergeOutcome outcome;
  try {
    outcome = await service.backupAndSignIn(
      confirmDetailsNotMoved: confirmDetailsNotMoved,
    );
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
    case GuestMergeImportFailed(:final backupPath):
      await _offerBackup(
        navigator,
        messenger,
        service,
        backupPath,
        title: l10n.guestMergeImportFailedTitle,
        message: l10n.guestMergeImportFailedMessage,
        l10n: l10n,
      );
      return false;
    case GuestMergeDetailsNotMoved():
      await _showNotice(
        navigator,
        messenger,
        title: l10n.guestMergeDetailsNotMovedTitle,
        message: l10n.guestMergeDetailsNotMovedMessage,
        l10n: l10n,
      );
      return false;
  }
}

/// Tells the user what the merge left behind, in a dialog, or in a snackbar
/// if the sign-in already replaced the screen.
Future<void> _showNotice(
  NavigatorState navigator,
  ScaffoldMessengerState messenger, {
  required String title,
  required String message,
  required AppLocalizations l10n,
}) async {
  if (!navigator.mounted) {
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 30)),
      );
    }
    return;
  }
  await showDialog<void>(
    context: navigator.context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.ok),
        ),
      ],
    ),
  );
}

/// Tells the user what was not moved and offers the backup kept on the
/// device. Closing this keeps the backup; it can be shared or deleted later
/// in Settings > Data & Account.
Future<void> _offerBackup(
  NavigatorState navigator,
  ScaffoldMessengerState messenger,
  GuestBackupMergeService service,
  String backupPath, {
  required String title,
  required String message,
  required AppLocalizations l10n,
}) async {
  Future<void> share(BuildContext? context) async {
    try {
      await service.shareBackup(backupPath);
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
        content: Text(message),
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
      title: Text(title),
      content: Text(message),
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
