/// Unified data and account management screen.
library;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/guest_backup_merge_provider.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/bulk_import_screen.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:inv_tracker/features/settings/data/services/account_deletion_flow.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/deletion_request_status_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/export_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/deletion_request_banner.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/saved_guest_backup_tile.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/usd_tag_repair_undo_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Unified screen for data import/export and account management.
class DataManagementScreen extends ConsumerStatefulWidget {
  const DataManagementScreen({super.key});

  @override
  ConsumerState<DataManagementScreen> createState() =>
      _DataManagementScreenState();
}

class _DataManagementScreenState extends ConsumerState<DataManagementScreen> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final exportState = ref.watch(exportStateProvider);
    final zipExportState = ref.watch(zipExportStateProvider);
    final zipImportState = ref.watch(zipImportStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = ref.watch(authStateProvider);
    final isAnonymous = authState.value?.isAnonymous ?? false;
    final hasSavedGuestBackup =
        ref.watch(savedGuestBackupsProvider).value?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataAndAccount, style: AppTypography.h3)),
      body: ListView(
        children: [
          SizedBox(height: AppSpacing.sm),

          // Shown while a deletion request exists (A88).
          const DeletionRequestBanner(),

          // Export section
          SettingsSection(
            title: 'Export',
            children: [
              if (hasSavedGuestBackup) const SavedGuestBackupTile(),
              SettingsNavTile(
                icon: Icons.description,
                iconColor: AppColors.successLight,
                title: 'Export as CSV',
                subtitle: 'Spreadsheet format',
                trailing: exportState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: () => _handleCsvExport(context, ref),
              ),
              SettingsNavTile(
                icon: Icons.folder_zip,
                iconColor: Colors.indigo,
                title: 'Export as ZIP',
                subtitle: 'Full backup with documents',
                trailing: zipExportState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: () => _handleZipExport(context, ref),
              ),
            ],
          ),

          // Import section
          SettingsSection(
            title: 'Import',
            children: [
              SettingsNavTile(
                icon: Icons.upload_file,
                iconColor: Colors.blue,
                title: 'Import from CSV',
                subtitle: 'Add investments from file',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const BulkImportScreen(),
                    ),
                  );
                },
              ),
              SettingsNavTile(
                icon: Icons.folder_zip_outlined,
                iconColor: Colors.indigo,
                title: 'Import from ZIP',
                subtitle: 'Restore from backup',
                trailing: zipImportState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: () => _handleZipImport(context, ref),
              ),
              // Undoes the fix for imports and merges saved in US dollars.
              const UsdTagRepairUndoTile(),
            ],
          ),

          // Danger zone
          SettingsSection(
            title: 'Danger Zone',
            children: [
              if (isAnonymous)
                SettingsNavTile(
                  icon: Icons.person_remove_outlined,
                  iconColor: AppColors.warningLight,
                  title: l10n.deleteGuestData,
                  subtitle: _isDeleting
                      ? 'Deleting...'
                      : 'Delete all data and anonymous account',
                  trailing: _isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: () {
                    if (!_isDeleting) {
                      _handleDeleteGuestData(context);
                    }
                  },
                ),
              SettingsNavTile(
                icon: Icons.delete_forever,
                iconColor: AppColors.errorLight,
                title: 'Delete Account',
                subtitle: _isDeleting
                    ? 'Deleting...'
                    : 'Permanently delete all data',
                trailing: _isDeleting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: () {
                  if (!_isDeleting) {
                    _handleDeleteAccount(context);
                  }
                },
              ),
            ],
          ),

          // Delete warning
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorLight.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.errorLight.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber,
                    color: AppColors.errorLight,
                    size: 20,
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Deleting your account is permanent. All investments, goals, and documents will be lost forever.',
                      style: AppTypography.small.copyWith(
                        color: isDark
                            ? Colors.white70
                            : AppColors.neutral700Light,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Future<void> _handleCsvExport(BuildContext context, WidgetRef ref) async {
    await ref.read(exportStateProvider.notifier).exportCsv();
    final state = ref.read(exportStateProvider);
    if (state.hasError && context.mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportFailed(state.error.toString()))),
      );
    } else {
      ref.read(analyticsServiceProvider).logExportGenerated(format: 'csv');
    }
  }

  Future<void> _handleZipExport(BuildContext context, WidgetRef ref) async {
    await ref.read(zipExportStateProvider.notifier).exportAsZip();
    final state = ref.read(zipExportStateProvider);
    if (state.hasError && context.mounted) {
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.exportFailed(state.error.toString())),
          backgroundColor: AppColors.errorLight,
        ),
      );
    } else if (context.mounted) {
      final l10n = AppLocalizations.of(context);
      ref.read(analyticsServiceProvider).logExportGenerated(format: 'zip');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.exportReady),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleZipImport(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show strategy selection dialog
    final strategy = await showDialog<ImportStrategy>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.importStrategy),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'How should we handle existing data?',
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.neutral300Dark
                    : AppColors.neutral600Light,
              ),
            ),
            const SizedBox(height: 20),
            // Merge option
            _ImportOptionTile(
              icon: Icons.merge_rounded,
              iconColor: AppColors.successLight,
              title: 'Merge',
              description: 'Add new data, skip duplicates',
              onTap: () => Navigator.pop(dialogContext, ImportStrategy.merge),
            ),
            const SizedBox(height: 12),
            // Replace option
            _ImportOptionTile(
              icon: Icons.swap_horiz_rounded,
              iconColor: AppColors.warningLight,
              title: 'Replace',
              description: 'Delete existing data first',
              onTap: () => Navigator.pop(dialogContext, ImportStrategy.replace),
              isDangerous: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );

    if (strategy == null || !context.mounted) return;

    // If replace, show extra confirmation
    if (strategy == ImportStrategy.replace) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            title: Text(l10n.replaceAllData),
            content: Text(l10n.replaceAllDataMessage),
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
                child: Text(l10n.replaceAll),
              ),
            ],
          );
        },
      );

      if (confirmed != true || !context.mounted) return;
    }

    // Suspend auto-lock during file picker to prevent locking
    // when returning from the system file picker
    ref.read(securityProvider.notifier).suspendAutoLock();

    // Pick ZIP file
    PlatformFile? selectedFile;
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );

      if (result == null ||
          result.files.isEmpty ||
          result.files.first.bytes == null) {
        return;
      }
      selectedFile = result.files.first;
    } finally {
      // Resume auto-lock after file picker operation completes
      ref.read(securityProvider.notifier).resumeAutoLock();
    }

    if (!context.mounted) return;

    // Import the ZIP
    try {
      final importResult = await ref
          .read(zipImportStateProvider.notifier)
          .importFromZip(selectedFile.bytes!, strategy);

      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        if (importResult.hasErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n.importCompletedWithErrors(importResult.errors.first),
              ),
              backgroundColor: Colors.orange,
            ),
          );
        } else if (importResult.warnings.isNotEmpty) {
          // Part of the backup was skipped (a damaged optional file). Replace
          // has already deleted what that file would have replaced, so this
          // must not read as plain success. Count only: the warning texts
          // hold investment and goal names (rules 7 and 8).
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // Dark text: the theme's snackbar text is light in the light
              // theme, which is unreadable on the amber background.
              content: DefaultTextStyle.merge(
                style: const TextStyle(color: AppColors.neutral900Light),
                child: MergeSemantics(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.importedWithWarnings(importResult.warnings.length),
                      ),
                      Text(l10n.importedWithWarningsHint),
                    ],
                  ),
                ),
              ),
              backgroundColor: AppColors.warningLight,
              duration: const Duration(seconds: 8),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Imported ${importResult.investmentsImported} investments, '
                '${importResult.cashflowsImported} cashflows, '
                '${importResult.goalsImported} goals, '
                '${importResult.documentsImported} documents',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.importFailed(e.toString())),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteGuestData(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // First confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteGuestData),
        content: Text(l10n.deleteGuestDataConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.warningLight,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.deleteGuestData),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Same order as Delete Account (A78): nothing is wiped until the server
    // holds the deletion request.
    await _runAccountDeletion(l10n, scaffoldMessenger, fromGuestTile: true);
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    // Capture context-dependent objects before any async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // First confirmation dialog, with a way to keep a backup first (A93)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DeleteAccountDialog(
        exportBackup: () async =>
            ref.read(dataExportServiceProvider)?.exportAndShare(),
      ),
    );

    if (confirmed != true || !mounted) return;

    // Second confirmation with text input
    final confirmText = await showDialog<String>(
      // ignore: use_build_context_synchronously - Context is checked via mounted guard above (line 466)
      context: context,
      builder: (dialogContext) => _DeleteConfirmationDialog(),
    );

    if (confirmText != 'DELETE' || !mounted) return;

    await _runAccountDeletion(l10n, scaffoldMessenger);
  }

  /// Runs [AccountDeletionFlow] and tells the user exactly what happened.
  /// [fromGuestTile] keeps the Delete Guest Data success copy and event.
  Future<void> _runAccountDeletion(
    AppLocalizations l10n,
    ScaffoldMessengerState scaffoldMessenger, {
    bool fromGuestTile = false,
  }) async {
    // Proceed with deletion. The banner hides its Withdraw button until the
    // flow ends, on every screen.
    final inProgress = ref.read(deletionInProgressProvider.notifier)..start();
    setState(() => _isDeleting = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final isGuest = ref.read(authStateProvider).value?.isAnonymous ?? false;
      final dataDeletion = ref.read(accountDataDeletionServiceProvider);
      final prefs = ref.read(sharedPreferencesProvider);
      final deleteLocalFiles = _localFilesDeleter();

      final outcome = await AccountDeletionFlow(
        auth: authRepo,
        isAnonymous: isGuest,
        requests: ref.read(deletionRequestServiceProvider),
        prepareGoogleSignIn: () =>
            ref.read(googleSignInInitializedProvider.future),
        // Server-confirmed wipe of every users/{uid} collection, then this
        // device's copy. Throws (NetworkException when offline) if the server
        // cannot confirm; the flow then leaves the deletion to the job.
        deleteUserData: () => dataDeletion.deleteEverything(
          deleteLocalFiles: deleteLocalFiles,
          prefs: prefs,
        ),
        deleteLocalData: () => dataDeletion.deleteLocalData(
          deleteLocalFiles: deleteLocalFiles,
          prefs: prefs,
        ),
      ).run();

      if (outcome != AccountDeletionOutcome.deleted) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(switch (outcome) {
                // A guest cannot sign back in to withdraw.
                AccountDeletionOutcome.scheduled =>
                  isGuest
                      ? l10n.guestDataDeletionScheduled
                      : l10n.accountDeletionScheduledNotice,
                AccountDeletionOutcome.notDeleted =>
                  l10n.accountDeletionNotStarted,
                AccountDeletionOutcome.queued => l10n.accountDeletionQueued,
                _ => l10n.accountDeletionCancelled,
              }),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 8),
            ),
          );
        }
        // A scheduled deletion signs the user out; the sign-in notice offers
        // to withdraw the request if they come back. A queued request stays
        // signed in so Firestore can send it once the device is online.
        if (outcome == AccountDeletionOutcome.scheduled) {
          await authRepo.signOut();
        }
        return;
      }

      if (fromGuestTile) {
        await ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: 'guest_mode_data_deleted',
              parameters: {'method': 'manual'},
            );
      }

      // The user IDs are cleared when the auth state empties
      // (userIdentitySyncProvider).
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              fromGuestTile
                  ? l10n.guestDataDeleted
                  : l10n.accountDeletedSuccessfully,
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Sign out to clear auth state - this triggers automatic redirect to sign-in
      await authRepo.signOut();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              l10n.failedToDeleteAccount(e.message ?? 'Unknown error'),
            ),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 8),
            // Never show the raw exception: it can name internal state.
            content: Text(l10n.failedToDeleteAccount(l10n.pleaseTryAgainLater)),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    } finally {
      inProgress.finish();
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  /// Deletes this account's local attachment files and any guest backups it
  /// owns. Everything it needs is read now, before the flow's first await.
  Future<void> Function() _localFilesDeleter() {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      throw StateError('User not authenticated');
    }
    final documentStorageService = ref.read(documentStorageServiceProvider);
    final guestBackups = ref.read(guestBackupMergeServiceProvider);
    return () async {
      await documentStorageService.deleteAllUserDocuments();
      // Also deletes the backups an unfinished guest merge was moving into
      // this account, and what the device kept about them.
      await guestBackups.deleteBackupsForAccountDeletion(user);
    };
  }
}

/// First Delete Account dialog. "Export a backup first" shares a ZIP backup
/// and keeps the dialog open; it never files a request or deletes anything.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.exportBackup});

  final Future<void> Function() exportBackup;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  bool _exporting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await widget.exportBackup();
    } catch (e, st) {
      // Mapped here: share_plus fails with a PlatformException, which the
      // generic mapping reports as a failed sign-in. Type only, no message:
      // it can hold a file path (rule 7).
      if (mounted) {
        ErrorHandler.handle(
          DataException(
            userMessage: AppLocalizations.of(context).exportFailureMessage,
            technicalMessage: 'Backup export failed (${e.runtimeType})',
          ),
          st,
          context: context,
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.deleteAccount),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteAccountMessage),
            SizedBox(height: AppSpacing.sm),
            Text(l10n.deleteAccountBackupCaveat, style: AppTypography.small),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.pop(context, false),
          child: Text(l10n.cancel),
        ),
        TextButton.icon(
          onPressed: _exporting ? null : _export,
          icon: _exporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(l10n.deleteAccountExportFirst),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.errorLight),
          onPressed: _exporting ? null : () => Navigator.pop(context, true),
          child: Text(l10n.deleteEverything),
        ),
      ],
    );
  }
}

/// Dialog for confirming account deletion with text input
class _DeleteConfirmationDialog extends StatefulWidget {
  @override
  State<_DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  final _controller = TextEditingController();
  bool _isValid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.finalConfirmation),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.typeDeleteToConfirm),
          SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: l10n.hintDeleteConfirmation,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() => _isValid = value == 'DELETE');
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _isValid ? AppColors.errorLight : Colors.grey,
          ),
          onPressed: _isValid ? () => Navigator.pop(context, 'DELETE') : null,
          child: Text(l10n.deleteMyAccount),
        ),
      ],
    );
  }
}

/// A selectable option tile for the import strategy dialog
class _ImportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isDangerous;

  const _ImportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
    this.isDangerous = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDangerous
                  ? AppColors.warningLight.withValues(alpha: 0.5)
                  : (isDark
                        ? AppColors.neutral700Dark
                        : AppColors.neutral200Light),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? Colors.white
                            : AppColors.neutral900Light,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.neutral400Dark
                            : AppColors.neutral500Light,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark
                    ? AppColors.neutral500Dark
                    : AppColors.neutral400Light,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
