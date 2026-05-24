import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

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
      if (state.flexibleUpdateAllowed) {
        LoggerService.info('Showing flexible update dialog');
        _showFlexibleUpdateDialog();
      }
    } catch (e, st) {
      LoggerService.error('Update check failed', error: e, stackTrace: st);
    }
  }

  void _showFlexibleUpdateDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Update Available'),
        content: const Text(
          'A new version of InvTracker is available. Would you like to update now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(inAppUpdateProvider.notifier).startFlexibleUpdate();

              if (!mounted) return;

              // Show snackbar about background download
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Downloading update in background...'),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            child: const Text('Update'),
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
      if (previous?.isDownloading == true &&
          next.isDownloading == false &&
          next.error == null) {
        _showInstallDialog();
      }
    });

    return widget.child;
  }

  void _showInstallDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false, // User must choose
      builder: (context) => AlertDialog(
        title: const Text('Update Ready'),
        content: const Text(
          'Update has been downloaded. Restart the app to install?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await ref.read(inAppUpdateProvider.notifier).completeFlexibleUpdate();
              // App will restart
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }
}
