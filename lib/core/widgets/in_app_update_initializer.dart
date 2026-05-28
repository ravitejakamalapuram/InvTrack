import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
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

  @override
  ConsumerState<InAppUpdateInitializer> createState() =>
      _InAppUpdateInitializerState();
}

class _InAppUpdateInitializerState
    extends ConsumerState<InAppUpdateInitializer> {
  bool _hasChecked = false;

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
      if (state.flexibleUpdateAllowed && !state.isDownloaded) {
        LoggerService.info('Showing flexible update dialog');
        _showFlexibleUpdateDialog();
      }
    } catch (e, st) {
      LoggerService.error('Update check failed', error: e, stackTrace: st);
    }
  }

  void _showFlexibleUpdateDialog() {
    if (!mounted) return;

    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);

    if (l10n == null) {
      LoggerService.warn('AppLocalizations not found in context for InAppUpdateInitializer');
    }

    showDialog(
      context: context,
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

              if (!mounted) return;

              // Check if update started successfully
              final state = ref.read(inAppUpdateProvider);
              if (state.error == null) {
                // Show snackbar about background download only on success
                ScaffoldMessenger.of(context).showSnackBar(
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
      if (next.isDownloaded && previous?.isDownloaded != true) {
        _showInstallDialog();
      }
    });

    return widget.child;
  }

  void _showInstallDialog() {
    if (!mounted) return;

    final l10n = Localizations.of<AppLocalizations>(context, AppLocalizations);
    if (l10n == null) {
      LoggerService.warn('AppLocalizations not found in context for install dialog');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false, // User must choose
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.inAppUpdateInstallTitle),
        content: Text(l10n.inAppUpdateInstallMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await ref.read(inAppUpdateProvider.notifier).completeFlexibleUpdate();
              // App will restart
            },
            child: Text(l10n.inAppUpdateInstallButton),
          ),
        ],
      ),
    );
  }
}
