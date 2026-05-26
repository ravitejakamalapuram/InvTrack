import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Initializes in-app update check on app start
///
/// Strategy:
/// - High priority updates (4-5): Show immediate update (blocking)
/// - Low priority updates (0-3): Show flexible update dialog (non-blocking)
///
/// Note: Only works on Android via Google Play
class InAppUpdateInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const InAppUpdateInitializer({required this.child, super.key});

  /// Shows the update ready installation dialog
  static void showUpdateReadyDialog(
    BuildContext context,
    WidgetRef ref, {
    required VoidCallback onDismiss,
  }) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      barrierDismissible: false, // User must choose
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.updateReady),
        content: Text(l10n.updateReadyMessage),
        actions: [
          TextButton(
            onPressed: () {
              onDismiss();
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () async {
              onDismiss();
              Navigator.of(dialogContext).pop();
              await ref.read(inAppUpdateProvider.notifier).completeFlexibleUpdate();
            },
            child: Text(l10n.restart),
          ),
        ],
      ),
    );
  }

  @override
  ConsumerState<InAppUpdateInitializer> createState() =>
      _InAppUpdateInitializerState();
}

class _InAppUpdateInitializerState
    extends ConsumerState<InAppUpdateInitializer> {
  bool _hasChecked = false;
  bool _isInstallDialogShowing = false;

  @override
  void initState() {
    super.initState();
    // Check for updates after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  Future<void> _checkForUpdates() async {
    if (_hasChecked || !mounted) return;
    _hasChecked = true;

    try {
      await ref.read(inAppUpdateProvider.notifier).checkForUpdate();

      if (!mounted) return;

      final state = ref.read(inAppUpdateProvider);

      if (state.isUpdateDownloaded) {
        return;
      }

      if (!state.hasUpdate) {
        LoggerService.debug('No update available');
        return;
      }

      // High priority updates: Use immediate update (blocking)
      if (state.isHighPriority && state.immediateUpdateAllowed) {
        LoggerService.info('Starting immediate update for high priority');
        await ref.read(inAppUpdateProvider.notifier).startImmediateUpdate();
        return;
      }

      // Low priority updates: Show flexible update dialog
      if (state.flexibleUpdateAllowed) {
        LoggerService.info('Showing flexible update dialog');
        _showFlexibleUpdateDialog();
      }
    } catch (e, st) {
      LoggerService.error('Update check failed', error: e, stackTrace: st);
    }
  }

  void _showFlexibleUpdateDialog() {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !mounted) return;

    final l10n = Localizations.of<AppLocalizations>(navContext, AppLocalizations);

    if (l10n == null) {
      LoggerService.warn('AppLocalizations not found in context for InAppUpdateInitializer');
    }

    showDialog(
      context: navContext,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n?.updateAvailable ?? 'Update Available'),
        content: Text(l10n?.updatePromptMessage ?? 'A new version of InvTrack is available. Would you like to update now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n?.later ?? 'Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(inAppUpdateProvider.notifier).startFlexibleUpdate();

              final updatedNavContext = rootNavigatorKey.currentContext;
              if (updatedNavContext == null || !mounted) return;

              // Check if update started successfully
              final state = ref.read(inAppUpdateProvider);
              if (state.error == null) {
                // Show snackbar about background download only on success
                ScaffoldMessenger.of(updatedNavContext).showSnackBar(
                  SnackBar(
                    content: Text(l10n?.downloadingUpdateBackground ?? 'Downloading update in background...'),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: Text(l10n?.update ?? 'Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for flexible update completion
    ref.listen<InAppUpdateState>(inAppUpdateProvider, (previous, next) {
      if (!mounted) return;

      // If flexible update finished downloading, prompt to install
      if (next.isUpdateDownloaded && previous?.isUpdateDownloaded != true) {
        _showInstallDialog();
      }
    });

    return widget.child;
  }

  void _showInstallDialog() {
    if (_isInstallDialogShowing) return;

    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !mounted) return;

    _isInstallDialogShowing = true;

    InAppUpdateInitializer.showUpdateReadyDialog(
      navContext,
      ref,
      onDismiss: () {
        _isInstallDialogShowing = false;
      },
    );
  }
}
