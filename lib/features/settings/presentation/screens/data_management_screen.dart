/// Unified data and account management screen.
library;

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/bulk_import_screen.dart';
import 'package:inv_tracker/features/goals/presentation/providers/goals_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_export_provider.dart';
import 'package:inv_tracker/features/settings/data/providers/data_import_provider.dart';
import 'package:inv_tracker/features/settings/data/services/data_import_service.dart';
import 'package:inv_tracker/features/settings/presentation/providers/export_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/seed_data_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';

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
    final exportState = ref.watch(exportStateProvider);
    final zipExportState = ref.watch(zipExportStateProvider);
    final zipImportState = ref.watch(zipImportStateProvider);
    final seedState = ref.watch(seedDataStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text('Data & Account', style: AppTypography.h3)),
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
                subtitle:
                    _isDeleting ? 'Deleting...' : 'Permanently delete all data',
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
                  Icon(Icons.warning_amber,
                      color: AppColors.errorLight, size: 20),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${state.error}')),
      );
    } else {
      ref.read(analyticsServiceProvider).logExportGenerated(format: 'csv');
    }
  }

  Future<void> _handleZipExport(BuildContext context, WidgetRef ref) async {
    await ref.read(zipExportStateProvider.notifier).exportAsZip();
    final state = ref.read(zipExportStateProvider);
    if (state.hasError && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: ${state.error}'),
          backgroundColor: AppColors.errorLight,
        ),
      );
    } else if (context.mounted) {
      ref.read(analyticsServiceProvider).logExportGenerated(format: 'zip');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export ready! Choose where to save.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleZipImport(BuildContext context, WidgetRef ref) async {
    // Show strategy selection dialog
    final strategy = await showDialog<ImportStrategy>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Strategy'),
        content: const Text(
          'Choose how to handle existing data:\n\n'
          '• Merge: Add new data, skip duplicates\n'
          '• Replace: Delete all existing data first',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, ImportStrategy.merge),
            child: const Text('Merge'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, ImportStrategy.replace),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorLight,
            ),
            child: const Text('Replace'),
          ),
        ],
      ),
    );

    if (strategy == null || !context.mounted) return;

    // If replace, show extra confirmation
    if (strategy == ImportStrategy.replace) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace All Data?'),
          content: const Text(
            'This will DELETE all existing investments, goals, and documents '
            'before importing the backup.\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.errorLight,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Replace All'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;
    }

    // Pick ZIP file
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

    if (!context.mounted) return;

    // Import the ZIP
    try {
      final importResult = await ref
          .read(zipImportStateProvider.notifier)
          .importFromZip(result.files.first.bytes!, strategy);

      if (context.mounted) {
        if (importResult.hasErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Import completed with errors: ${importResult.errors.first}'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    }
  }

  Future<void> _handleSeedData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seed Demo Data?'),
        content: const Text(
          'This will add 10 sample investments with realistic cash flows '
          'and 5 goals at different progress levels.\n\n'
          'Perfect for app store screenshots!\n\n'
          'Note: Existing data will NOT be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Seed Data'),
          ),
        ],
      ),
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
    // Capture context-dependent objects before any async gap
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // First confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete:\n\n'
          '• All your investments\n'
          '• All cash flow records\n'
          '• All goals\n'
          '• All attached documents\n'
          '• Your account\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorLight,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Second confirmation with text input
    final confirmText = await showDialog<String>(
      // ignore: use_build_context_synchronously
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
          debugPrint('Account deletion requires recent login, attempting re-auth...');

          try {
            final reauthenticated = await authRepo.reauthenticateWithGoogle();
            if (reauthenticated) {
              // Retry deletion after re-authentication
              await authRepo.deleteAccount();
            } else {
              // User cancelled re-auth
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Account deletion cancelled'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
              // Data is already deleted, sign out the user
              await authRepo.signOut();
              return;
            }
          } catch (reauthError) {
            debugPrint('Re-authentication failed: $reauthError');
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
          const SnackBar(
            content: Text('Account deleted successfully'),
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
            content: Text('Failed to delete account: ${e.message}'),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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
    // Delete all investments (which cascades to cash flows and documents)
    final investmentRepo = ref.read(investmentRepositoryProvider);
    final investments = await investmentRepo.getAllInvestments();
    final archivedInvestments =
        await investmentRepo.watchArchivedInvestments().first;

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
    return AlertDialog(
      title: const Text('Final Confirmation'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Type DELETE to confirm:'),
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _isValid ? AppColors.errorLight : Colors.grey,
          ),
          onPressed: _isValid ? () => Navigator.pop(context, 'DELETE') : null,
          child: const Text('Delete My Account'),
        ),
      ],
    );
  }
}
