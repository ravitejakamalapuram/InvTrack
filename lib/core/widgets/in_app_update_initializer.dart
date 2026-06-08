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

  @override
  ConsumerState<InAppUpdateInitializer> createState() =>
      _InAppUpdateInitializerState();
}

class _InAppUpdateInitializerState
    extends ConsumerState<InAppUpdateInitializer>
    with WidgetsBindingObserver {
  bool _hasChecked = false;
  bool _hasDeferredUpdate = false;
  bool _hasDeferredInstall = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check for updates after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LoggerService.info('App resumed, checking update status');
      _checkForUpdates(isResume: true);
    }
  }

  Future<void> _checkForUpdates({bool isResume = false}) async {
    if (!isResume) {
      if (_hasChecked) return;
      _hasChecked = true;
    }

    if (!mounted) return;

    // Avoid duplicate checks if already checking
    if (ref.read(inAppUpdateProvider).isChecking) return;

    try {
      await ref.read(inAppUpdateProvider.notifier).checkForUpdate();

      if (!mounted) return;

      final state = ref.read(inAppUpdateProvider);

      // Check if update is already downloaded
      if (state.isDownloaded) {
        if (!_hasDeferredInstall) {
          LoggerService.info('Showing install dialog (update already downloaded)');
          _showInstallDialog();
        } else {
          LoggerService.debug('Update is downloaded but prompt was deferred by user');
        }
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
      if (state.flexibleUpdateAllowed && !_hasDeferredUpdate) {
        LoggerService.info('Showing flexible update dialog');
        _showFlexibleUpdateDialog();
      }
    } catch (e, st) {
      LoggerService.error('Update check failed', error: e, stackTrace: st);
    }
  }

  Future<BuildContext?> _getValidDialogContext() async {
    for (int i = 0; i < 10; i++) {
      if (!mounted) return null;
      // 1. Try local widget context if it is mounted and has a Navigator ancestor
      if (Navigator.maybeOf(context) != null) {
        return context;
      }
      // 2. Try root navigator's overlay context, which is inside the Navigator
      final overlayContext = rootNavigatorKey.currentState?.overlay?.context;
      if (overlayContext != null && overlayContext.mounted) {
        return overlayContext;
      }
      // 3. Fallback to root navigator's own context
      final rootContext = rootNavigatorKey.currentContext;
      if (rootContext != null && rootContext.mounted) {
        return rootContext;
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return null;
  }

  Future<void> _showFlexibleUpdateDialog() async {
    final dialogContext = await _getValidDialogContext();
    if (dialogContext == null || !dialogContext.mounted) {
      LoggerService.warn('Cannot show flexible update dialog: navigator context is null or unmounted');
      return;
    }

    final l10n = Localizations.of<AppLocalizations>(dialogContext, AppLocalizations);

    if (l10n == null) {
      LoggerService.warn('AppLocalizations not found in context for InAppUpdateInitializer');
    }

    showDialog(
      context: dialogContext,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n?.updateAvailable ?? 'Update Available'),
        content: Text(l10n?.updatePromptMessage ?? 'A new version of InvTrack is available. Would you like to update now?'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _hasDeferredUpdate = true;
              });
              Navigator.of(dialogCtx).pop();
            },
            child: Text(l10n?.later ?? 'Later'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref.read(inAppUpdateProvider.notifier).startFlexibleUpdate();

              if (!mounted) return;
              final checkContext = await _getValidDialogContext();
              if (checkContext == null || !checkContext.mounted) return;

              // Check if update started successfully
              final state = ref.read(inAppUpdateProvider);
              if (state.error == null) {
                // Show snackbar about background download only on success
                ScaffoldMessenger.of(checkContext).showSnackBar(
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

  Future<void> _showInstallDialog() async {
    final dialogContext = await _getValidDialogContext();
    if (dialogContext == null || !dialogContext.mounted) {
      LoggerService.warn('Cannot show install dialog: navigator context is null or unmounted');
      return;
    }

    final l10n = Localizations.of<AppLocalizations>(dialogContext, AppLocalizations);
    if (l10n == null) {
      LoggerService.warn('AppLocalizations not found in context for install dialog');
      return;
    }

    showDialog(
      context: dialogContext,
      barrierDismissible: false, // User must choose
      builder: (dialogCtx) => AlertDialog(
        title: Text(l10n.inAppUpdateInstallTitle),
        content: Text(l10n.inAppUpdateInstallMessage),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _hasDeferredInstall = true;
              });
              Navigator.of(dialogCtx).pop();
            },
            child: Text(l10n.later),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
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
