import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart' show AppUpdateResult;
import 'package:inv_tracker/core/providers/in_app_update_provider.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/l10n/generated/app_localizations.dart';

/// Initializes in-app update check on app start
///
/// Strategy:
/// - Installed version 60+ days behind: immediate update (blocking)
/// - Otherwise: flexible update dialog (non-blocking)
/// - At most one automatic prompt per 3 days; Play errors are logged only
///
/// Note: Only works on Android via Google Play
class InAppUpdateInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const InAppUpdateInitializer({required this.child, super.key});

  @override
  ConsumerState<InAppUpdateInitializer> createState() =>
      _InAppUpdateInitializerState();
}

class _InAppUpdateInitializerState extends ConsumerState<InAppUpdateInitializer>
    with WidgetsBindingObserver {
  bool _hasChecked = false;
  bool _hasDeferredUpdate = false;
  bool _hasDeferredInstall = false;
  // True while a flexible dialog attempt is in flight or its dialog is open.
  bool _flexibleDialogPending = false;

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
          LoggerService.info(
            'Showing install dialog (update already downloaded)',
          );
          _showInstallDialog();
        } else {
          LoggerService.debug(
            'Update is downloaded but prompt was deferred by user',
          );
        }
        return;
      }

      if (!state.hasUpdate) {
        LoggerService.debug('No update available');
        return;
      }

      final notifier = ref.read(inAppUpdateProvider.notifier);
      final now = DateTime.now();
      if (!notifier.shouldPromptNow(now)) {
        LoggerService.debug(
          'Update prompt skipped: prompted within the last 3 days',
        );
        return;
      }

      switch (state.autoUpdateMode) {
        case AutoUpdateMode.immediate:
          LoggerService.info('Starting immediate update for stale install');
          final result = await notifier.startImmediateUpdate();
          // A failed start was never shown to the user, so do not throttle.
          if (result != AppUpdateResult.inAppUpdateFailed) {
            await notifier.markPrompted(now);
          }
        case AutoUpdateMode.flexible:
          if (!_hasDeferredUpdate && !_flexibleDialogPending) {
            LoggerService.info('Showing flexible update dialog');
            _flexibleDialogPending = true;
            _showFlexibleUpdateDialog();
          }
        case AutoUpdateMode.none:
          break;
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
    try {
      await _openFlexibleUpdateDialog();
    } finally {
      _flexibleDialogPending = false;
    }
  }

  Future<void> _openFlexibleUpdateDialog() async {
    final dialogContext = await _getValidDialogContext();
    if (dialogContext == null || !dialogContext.mounted) {
      LoggerService.warn(
        'Cannot show flexible update dialog: navigator context is null or unmounted',
      );
      return;
    }

    final l10n = Localizations.of<AppLocalizations>(
      dialogContext,
      AppLocalizations,
    );

    // FIX: Crash "Null check operator used on a null value" - Crashlytics issue c8f980cd37a050d99b236193ef9ea583
    // If localizations not found, use fallback English strings instead of crashing
    final titleText = l10n?.updateAvailable ?? 'Update Available';
    final contentText =
        l10n?.updatePromptMessage ??
        'A new version of InvTrack is available. Would you like to update now?';
    final laterText = l10n?.later ?? 'Later';
    final updateText = l10n?.update ?? 'Update';

    if (l10n == null) {
      LoggerService.warn(
        'AppLocalizations not found in context for InAppUpdateInitializer - using fallback text',
        metadata: {'context_type': dialogContext.runtimeType.toString()},
      );
    }

    // Throttle only once the dialog can really be shown. Await the write so
    // it lands before the dialog; a failed write is logged, not shown.
    try {
      await ref.read(inAppUpdateProvider.notifier).markPrompted(DateTime.now());
    } catch (e, st) {
      LoggerService.warn(
        'Could not save update prompt time',
        error: e,
        stackTrace: st,
      );
    }
    if (!dialogContext.mounted) return;

    // Awaiting keeps the pending flag set until the dialog is dismissed.
    await showDialog<void>(
      context: dialogContext,
      barrierDismissible: true,
      builder: (dialogCtx) => AlertDialog(
        title: Text(titleText),
        content: Text(contentText),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _hasDeferredUpdate = true;
              });
              Navigator.of(dialogCtx).pop();
            },
            child: Text(laterText),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              await ref
                  .read(inAppUpdateProvider.notifier)
                  .startFlexibleUpdate();

              if (!mounted) return;
              final checkContext = await _getValidDialogContext();
              if (checkContext == null || !checkContext.mounted) return;

              // Check if update started successfully
              final state = ref.read(inAppUpdateProvider);
              if (state.error == null) {
                // Get fresh l10n from checkContext
                final checkL10n = Localizations.of<AppLocalizations>(
                  checkContext,
                  AppLocalizations,
                );
                if (checkL10n == null) return;

                // Show snackbar about background download only on success
                ScaffoldMessenger.of(checkContext).showSnackBar(
                  SnackBar(
                    content: Text(checkL10n.downloadingUpdateBackground),
                    duration: const Duration(seconds: 3),
                  ),
                );
              }
            },
            child: Text(updateText),
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
      LoggerService.warn(
        'Cannot show install dialog: navigator context is null or unmounted',
      );
      return;
    }

    final l10n = Localizations.of<AppLocalizations>(
      dialogContext,
      AppLocalizations,
    );
    if (l10n == null) {
      LoggerService.warn(
        'AppLocalizations not found in context for install dialog',
      );
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
              await ref
                  .read(inAppUpdateProvider.notifier)
                  .completeFlexibleUpdate();
              // App will restart
            },
            child: Text(l10n.inAppUpdateInstallButton),
          ),
        ],
      ),
    );
  }
}
