/// Crashlytics testing settings section for debug mode.
///
/// This widget provides UI controls for testing Crashlytics integration:
/// - Toggle to enable/disable Crashlytics in debug builds
/// - Button to send test non-fatal errors
/// - Button to trigger test fatal crashes
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/theme/app_colors.dart';
import 'package:inv_tracker/core/theme/app_spacing.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_section.dart';
import 'package:inv_tracker/features/settings/presentation/widgets/settings_tile.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Crashlytics testing section widget
class CrashlyticsSettingsSection extends ConsumerWidget {
  const CrashlyticsSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final crashlyticsService = ref.watch(crashlyticsServiceProvider);
    final isEnabled = crashlyticsService.isCrashlyticsCollectionEnabled;
    final debugModeEnabled = ref.watch(crashlyticsDebugModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SettingsSection(
      title: l10n.crashlyticsTestingTitle,
      children: [
        // BUG FIX: Info banner explaining Crashlytics status
        if (kDebugMode) _buildInfoBanner(context, l10n, isEnabled, isDark),

        // Toggle Crashlytics in debug mode
        SettingsToggleTile(
          icon: Icons.bug_report,
          iconColor: Colors.red,
          title: l10n.enableCrashlyticsInDebugTitle,
          subtitle: isEnabled
              ? l10n.crashlyticsEnabledSubtitle
              : l10n.crashlyticsDisabledSubtitle,
          value: debugModeEnabled,
          onChanged: (value) => _handleToggle(context, ref, value),
        ),

        // Test non-fatal error
        SettingsNavTile(
          icon: Icons.error_outline,
          iconColor: Colors.orange,
          title: l10n.testNonFatalTitle,
          subtitle: l10n.testNonFatalSubtitle,
          onTap: () => _handleTestNonFatalError(context, ref),
        ),

        // Test fatal crash
        SettingsNavTile(
          icon: Icons.warning_amber,
          iconColor: Colors.red,
          title: l10n.testFatalTitle,
          subtitle: l10n.testFatalSubtitle,
          onTap: () => _handleTestCrash(context, ref),
        ),
      ],
    );
  }

  /// Handle toggle change with atomic state update
  Future<void> _handleToggle(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    try {
      // Update static field first for immediate effect
      CrashlyticsService.enableInDebugMode = value;

      // Update provider (persists to SharedPreferences atomically)
      await ref.read(crashlyticsDebugModeProvider.notifier).setEnabled(value);

      // Re-initialize with new setting
      final updatedService = ref.read(crashlyticsServiceProvider);
      await updatedService.initialize();

      if (context.mounted) {
        final l10n = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? l10n.crashlyticsEnabledSnack
                  : l10n.crashlyticsDisabledSnack,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, st) {
      // Revert both static field and provider on error
      CrashlyticsService.enableInDebugMode = !value;
      try {
        await ref
            .read(crashlyticsDebugModeProvider.notifier)
            .setEnabled(!value);
      } catch (_) {
        // Ignore revert errors to preserve original exception
      }

      if (context.mounted) {
        ErrorHandler.handle(e, st, context: context, showFeedback: true);
      }
    }
  }

  /// Handle testing non-fatal error
  Future<void> _handleTestNonFatalError(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final crashlyticsService = ref.read(crashlyticsServiceProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.testNonFatalDialogTitle),
        content: Text(l10n.testNonFatalDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.sendTestError),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await crashlyticsService.testNonFatalError();

        if (context.mounted) {
          final l10n = AppLocalizations.of(context);
          final isActuallyEnabled = !kDebugMode || CrashlyticsService.enableInDebugMode;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isActuallyEnabled
                    ? l10n.testErrorSentSuccess
                    : l10n.crashlyticsDisabledWarning,
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } catch (e, st) {
        if (context.mounted) {
          ErrorHandler.handle(e, st, context: context, showFeedback: true);
        }
      }
    }
  }

  /// Handle testing fatal crash
  Future<void> _handleTestCrash(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context);
    final crashlyticsService = ref.read(crashlyticsServiceProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: AppColors.errorLight),
            const SizedBox(width: 8),
            Text(l10n.testFatalDialogTitle),
          ],
        ),
        content: Text(l10n.testFatalDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.errorLight,
            ),
            child: Text(l10n.crashNow),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Future.delayed(const Duration(seconds: 1));
      crashlyticsService.testCrash();
    }
  }

  /// Build info banner explaining Crashlytics status
  ///
  /// BUG FIX: Added to make it obvious that Crashlytics is working in production
  /// but disabled in debug mode by default (which is expected behavior).
  Widget _buildInfoBanner(
    BuildContext context,
    AppLocalizations l10n,
    bool isEnabled,
    bool isDark,
  ) {
    final backgroundColor = isDark
        ? (isEnabled ? Colors.green.shade900 : Colors.orange.shade900)
        : (isEnabled ? Colors.green.shade50 : Colors.orange.shade50);
    final textColor = isDark
        ? (isEnabled ? Colors.green.shade200 : Colors.orange.shade200)
        : (isEnabled ? Colors.green.shade800 : Colors.orange.shade800);
    final iconColor = isDark
        ? (isEnabled ? Colors.green.shade300 : Colors.orange.shade300)
        : (isEnabled ? Colors.green.shade700 : Colors.orange.shade700);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isEnabled ? Icons.check_circle : Icons.info_outline,
            color: iconColor,
            size: 24,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEnabled
                      ? l10n.crashlyticsActiveInDebugTitle
                      : l10n.crashlyticsInactiveInDebugTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  isEnabled
                      ? l10n.crashlyticsActiveInDebugMessage
                      : l10n.crashlyticsInactiveInDebugMessage,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
                if (!isEnabled) ...[
                  SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.crashlyticsWorksInReleaseNote,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
