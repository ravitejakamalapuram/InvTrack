/// Data management screen for import/export and developer options.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/bulk_import/presentation/screens/bulk_import_screen.dart';
import 'package:inv_tracker/features/settings/presentation/providers/export_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/seed_data_provider.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';

/// Screen for data import/export operations.
class DataManagementScreen extends ConsumerWidget {
  const DataManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exportState = ref.watch(exportStateProvider);
    final seedState = ref.watch(seedDataStateProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Data Management', style: AppTypography.h3),
      ),
      body: ListView(
        children: [
          SizedBox(height: AppSpacing.sm),

          // Export section
          SettingsSection(
            title: 'Export',
            footer: 'Download your data in various formats',
            children: [
              SettingsNavTile(
                icon: Icons.download,
                iconColor: AppColors.successLight,
                title: 'Export as CSV',
                subtitle: 'Download all investments',
                trailing: exportState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: () async {
                  await ref.read(exportStateProvider.notifier).exportCsv();
                  final state = ref.read(exportStateProvider);
                  if (state.hasError && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Export failed: ${state.error}')),
                    );
                  } else {
                    ref.read(analyticsServiceProvider).logExportGenerated(format: 'csv');
                  }
                },
              ),
            ],
          ),

          // Import section
          SettingsSection(
            title: 'Import',
            footer: 'Add investments from external sources',
            children: [
              SettingsNavTile(
                icon: Icons.upload_file,
                iconColor: Colors.blue,
                title: 'Import from CSV',
                subtitle: 'Use our template format',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const BulkImportScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          // Developer options (debug only)
          if (kDebugMode) ...[
            SettingsSection(
              title: 'Developer',
              footer: 'Options for testing and development',
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
          ],

          // Storage info
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.storage, color: Colors.orange, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'All data is stored locally on your device. Export regularly to keep a backup.',
                      style: AppTypography.small.copyWith(
                        color: isDark ? Colors.white70 : AppColors.neutral700Light,
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

  Future<void> _handleSeedData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seed Demo Data?'),
        content: const Text(
          'This will add 8 sample investments with realistic cash flows. '
          'Use this for app store screenshots.\n\n'
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
            content: Text('Seeded ${result.investments} investments'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

