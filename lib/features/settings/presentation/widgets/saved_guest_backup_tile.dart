import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Offers the guest backups kept on this device after a guest-to-Google
/// merge that did not move everything, so they stay reachable after the
/// merge prompt is gone or the app restarts. Shows nothing when there are
/// none.
class SavedGuestBackupTile extends ConsumerWidget {
  const SavedGuestBackupTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backups = ref.watch(savedGuestBackupsProvider).value ?? const [];
    if (backups.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final service = ref.read(guestBackupMergeServiceProvider);

    return ListTile(
      leading: const Icon(Icons.restore_page, color: AppColors.warningLight),
      title: Text(l10n.savedGuestBackupTitle),
      subtitle: Text(l10n.savedGuestBackupSubtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: l10n.shareBackup,
            onPressed: () => _run(context, service.shareSavedBackups),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.deleteGuestBackup,
            onPressed: () => _confirmDelete(context, service),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    GuestBackupMergeService service,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteGuestBackupTitle),
        content: Text(l10n.deleteGuestBackupMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorLight,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(context, service.deleteSavedBackups);
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e, st) {
      ErrorHandler.handle(
        e,
        st,
        context: context.mounted ? context : null,
        showFeedback: true,
      );
    }
  }
}
