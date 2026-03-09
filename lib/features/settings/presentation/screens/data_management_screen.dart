/// Unified data and account management screen.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/bulk_import_screen.dart';
import 'package:inv_tracker/features/fire_number/presentation/providers/fire_notifier.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/security/presentation/providers/security_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/export_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/seed_data_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/features/user_profile/presentation/providers/user_profile_provider.dart';
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
    final seedState = ref.watch(seedDataStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataAndAccount, style: AppTypography.h3)),
      body: ListView(
        children: [
          SizedBox(height: AppSpacing.sm),

          // Export section
          SettingsSection(
            title: 'Export',
            children: [
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
            ],
          ),

          // Developer options (debug only)
          if (kDebugMode)
            SettingsSection(
              title: 'Developer',
              children: [
                SettingsNavTile(
                  icon: Icons.dataset,
                  iconColor: Colors.teal,
                  title: 'Seed Demo Data',
                  subtitle: 'Add sample investments',
                  trailing: seedState.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: () => _handleSeedData(context, ref),
                ),
              ],
            ),

          // Danger zone
          SettingsSection(
            title: 'Danger Zone',
            children: [
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
      final result = await FilePicker.platform.pickFiles(
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

  Future<void> _handleSeedData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.seedDemoData),
          content: Text(l10n.seedDemoDataMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.seedData),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final result = await ref.read(seedDataStateProvider.notifier).seedData();
      if (context.mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Seeded ${result.investments} investments & ${result.goals} goals',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    // Capture context-dependent objects before any async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // First confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(context);
        return AlertDialog(
          title: Text(l10n.deleteAccount),
          content: Text(l10n.deleteAccountMessage),
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
              child: Text(l10n.deleteEverything),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    // Second confirmation with text input
    final confirmText = await showDialog<String>(
      // ignore: use_build_context_synchronously - Context is checked via mounted guard above (line 466)
      context: context,
      builder: (dialogContext) => _DeleteConfirmationDialog(),
    );

    if (confirmText != 'DELETE' || !mounted) return;

    // Proceed with deletion
    setState(() => _isDeleting = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);

      // Delete all Firestore data first (before any auth operations)
      await _deleteAllUserData();

      // Try to delete the Firebase Auth account
      try {
        await authRepo.deleteAccount();
      } on FirebaseAuthException catch (e) {
        // If requires-recent-login, try to re-authenticate and retry
        if (e.code == 'requires-recent-login') {
          LoggerService.info(
            'Account deletion requires recent login, attempting re-auth',
          );

          try {
            final reauthenticated = await authRepo.reauthenticateWithGoogle();
            if (reauthenticated) {
              // Retry deletion after re-authentication
              await authRepo.deleteAccount();
            } else {
              // User cancelled re-auth
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(l10n.accountDeletionCancelled),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              // Data is already deleted, sign out the user
              await authRepo.signOut();
              return;
            }
          } catch (reauthError) {
            LoggerService.error('Re-authentication failed', error: reauthError);
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Text(
                    'Re-authentication failed. Your data has been deleted. Please sign out.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            // Data is already deleted, sign out the user
            await authRepo.signOut();
            return;
          }
        } else {
          rethrow;
        }
      }

      // Log analytics
      ref.read(analyticsServiceProvider).setUserId(null);

      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(l10n.accountDeletedSuccessfully),
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
            content: Text(l10n.error(e.toString())),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _deleteAllUserData() async {
    // Get current user ID
    final authState = ref.read(authStateProvider);
    final user = authState.value;
    if (user == null) {
      throw StateError('User not authenticated');
    }

    // Delete all investments (which cascades to cash flows and documents)
    final investmentRepo = ref.read(investmentRepositoryProvider);
    final investments = await investmentRepo.getAllInvestments();
    final archivedInvestments = await investmentRepo
        .watchArchivedInvestments()
        .first;

    for (final inv in [...investments, ...archivedInvestments]) {
      if (inv.isArchived) {
        await investmentRepo.deleteArchivedInvestment(inv.id);
      } else {
        await investmentRepo.deleteInvestment(inv.id);
      }
    }

    // Delete all goals
    final goalRepo = ref.read(goalRepositoryProvider);
    final goals = await goalRepo.getAllGoals();
    final archivedGoals = await goalRepo.watchArchivedGoals().first;

    for (final goal in [...goals, ...archivedGoals]) {
      if (goal.isArchived) {
        await goalRepo.deleteArchivedGoal(goal.id);
      } else {
        await goalRepo.deleteGoal(goal.id);
      }
    }

    // Delete user profile (Rule 18: Data Lifecycle)
    final userProfileRepo = ref.read(userProfileRepositoryProvider(user.id));
    await userProfileRepo.deleteProfile();

    // Delete FIRE settings (Rule 18: Data Lifecycle)
    await ref.read(fireSettingsNotifierProvider.notifier).resetSettings();

    // Delete exchange rate cache (Rule 18: Data Lifecycle - Multi-Currency Support)
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final exchangeRatesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('exchangeRates');

      final snapshot = await exchangeRatesRef.get();
      for (final doc in snapshot.docs) {
        await doc.reference.delete();
      }
    }

    // Clear sample data mode preferences (Rule 18: Data Lifecycle)
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('sample_data_mode_active');
    await prefs.remove('sample_data_investment_ids');
    await prefs.remove('sample_data_goal_ids');
    await prefs.remove(
      'last_live_cache_refresh',
    ); // Multi-currency cache refresh timestamp
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
            decoration: const InputDecoration(
              hintText: 'DELETE',
              border: OutlineInputBorder(),
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
