/// Debug settings screen with developer tools and diagnostics.
///
/// This screen is only accessible when debug mode is enabled.
/// It provides tools for:
/// - Managing sample data
/// - Viewing app diagnostics
/// - Toggling debug mode on/off
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/providers/debug_mode_provider.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/core/theme/app_typography.dart';
import 'package:inv_tracker/features/settings/presentation/providers/sample_data_provider.dart';
import 'package:inv_tracker/features/settings/presentation/providers/seed_data_provider.dart';
import 'package:inv_tracker/features/settings/presentation/screens/about_screen.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Debug settings screen with developer tools.
class DebugSettingsScreen extends ConsumerWidget {
  const DebugSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isDebugEnabled = ref.watch(debugModeProvider);
    final seedState = ref.watch(seedDataStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.debugSettings, style: AppTypography.h3),
      ),
      body: ListView(
        children: [
          // Debug Mode Toggle
          SettingsSection(
            title: l10n.debugMode,
            children: [
              SettingsToggleTile(
                icon: Icons.bug_report,
                iconColor: Colors.orange,
                title: l10n.enableDebugMode,
                subtitle: l10n.debugModeDescription,
                value: isDebugEnabled,
                onChanged: (value) async {
                  await ref.read(debugModeProvider.notifier).setEnabled(value);
                  if (!value && context.mounted) {
                    // If debug mode is disabled, pop back to settings
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),

          // Sample Data Management
          SettingsSection(
            title: l10n.sampleData,
            children: [
              SettingsNavTile(
                icon: Icons.dataset,
                iconColor: Colors.teal,
                title: l10n.seedDemoData,
                subtitle: l10n.addSampleInvestments,
                trailing: seedState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
                onTap: () {
                  if (!seedState.isLoading) {
                    _handleSeedData(context, ref);
                  }
                },
              ),
              SettingsNavTile(
                icon: Icons.delete_outline,
                iconColor: AppColors.errorLight,
                title: l10n.clearSampleData,
                subtitle: l10n.deleteSampleInvestments,
                onTap: () => _handleClearSampleData(context, ref),
              ),
            ],
          ),

          // Diagnostics
          SettingsSection(
            title: l10n.diagnostics,
            children: [
              SettingsNavTile(
                icon: Icons.info_outline,
                iconColor: Colors.blue,
                title: l10n.appInfo,
                subtitle: l10n.viewAppInformation,
                onTap: () => _showAppInfo(context),
              ),
            ],
          ),

          SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  /// Handle seeding sample data
  Future<void> _handleSeedData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(seedDataStateProvider.notifier);

    try {
      final result = await notifier.seedData();

      if (context.mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.sampleDataSeeded),
            backgroundColor: AppColors.successLight,
          ),
        );
      }
    } catch (e, st) {
      // Log error for diagnostics
      LoggerService.error(
        'Error seeding sample data',
        error: e,
        stackTrace: st,
        metadata: {'screen': 'DebugSettings'},
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorOccurred),
            backgroundColor: AppColors.errorLight,
          ),
        );
      }
    }
  }

  /// Handle clearing sample data
  Future<void> _handleClearSampleData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final sampleDataState = ref.read(sampleDataModeProvider);

    // Check if there's any sample data to clear
    if (sampleDataState.sampleInvestmentIds.isEmpty &&
        sampleDataState.sampleGoalIds.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.noSampleDataToClear),
            backgroundColor: AppColors.neutral500Light,
          ),
        );
      }
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearSampleData),
        content: Text(l10n.confirmClearSampleData),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorLight),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(sampleDataModeProvider.notifier).clearSampleData();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.sampleDataCleared),
              backgroundColor: AppColors.successLight,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorOccurred),
              backgroundColor: AppColors.errorLight,
            ),
          );
        }
      }
    }
  }

  /// Show app info dialog
  void _showAppInfo(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) {
          final packageInfoAsync = ref.watch(packageInfoProvider);

          return AlertDialog(
            title: Text(l10n.appInfo),
            content: packageInfoAsync.when(
              data: (packageInfo) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(l10n.appVersion, packageInfo.version),
                  _buildInfoRow(l10n.buildNumber, packageInfo.buildNumber),
                  _buildInfoRow(l10n.platform, Theme.of(context).platform.name),
                ],
              ),
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Text('Error: $error'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium),
          Text(value, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

