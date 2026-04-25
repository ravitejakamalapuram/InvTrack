import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/app_update/domain/entities/app_version_entity.dart';
import 'package:inv_tracker/features/app_update/presentation/providers/version_check_provider.dart';
import 'package:inv_tracker/features/app_update/presentation/widgets/update_dialog.dart';

/// Widget that initializes version checking and shows update dialog when needed
class VersionCheckInitializer extends ConsumerStatefulWidget {
  final Widget child;

  const VersionCheckInitializer({super.key, required this.child});

  @override
  ConsumerState<VersionCheckInitializer> createState() =>
      _VersionCheckInitializerState();
}

class _VersionCheckInitializerState
    extends ConsumerState<VersionCheckInitializer> {
  bool _hasShownDialog = false;
  Timer? _checkTimer;
  Timer? _dialogTimer;
  Timer? _retryTimer; // Track retry timer to cancel on dispose

  @override
  void initState() {
    super.initState();
    // Check for updates after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _dialogTimer?.cancel();
    _retryTimer?.cancel(); // Cancel retry timer to prevent memory leaks
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    // Wait a bit for the app to settle
    final completer = Completer<void>();
    _checkTimer = Timer(const Duration(seconds: 2), () {
      completer.complete();
    });
    await completer.future;

    if (!mounted) return;

    // Trigger the version check with error handling
    try {
      await ref.read(versionCheckProvider.notifier).checkForUpdates();
    } catch (e, st) {
      LoggerService.error(
        'Error during version check',
        error: e,
        stackTrace: st,
      );
      return; // Exit gracefully on error
    }

    if (!mounted) return;

    final versionState = ref.read(versionCheckProvider);
    final latestVersion = versionState.latestVersion;

    // Null safety: Only show dialog if latestVersion is available
    if (latestVersion == null) {
      LoggerService.debug('Version check completed but no latestVersion available');
      return;
    }

    // Show dialog if update is available and not dismissed
    if (versionState.shouldShowUpdateDialog && !_hasShownDialog) {
      _showUpdateDialog(latestVersion);
    } else if (versionState.requiresForceUpdate && !_hasShownDialog) {
      _showUpdateDialog(latestVersion, forceUpdate: true);
    }
  }

  /// Present the update dialog and set _hasShownDialog on success
  ///
  /// Centralized dialog display with error handling.
  /// Sets _hasShownDialog = true ONLY on successful dialog display.
  void _presentDialog(
    BuildContext context,
    AppVersionEntity versionInfo,
    bool forceUpdate,
  ) {
    try {
      showDialog(
        context: context,
        barrierDismissible: !forceUpdate,
        builder: (ctx) => UpdateDialog(
          versionInfo: versionInfo,
          forceUpdate: forceUpdate,
        ),
      );

      // SUCCESS: Set flag AFTER dialog is shown
      _hasShownDialog = true;

      LoggerService.info(
        'Update dialog shown',
        metadata: {'forceUpdate': forceUpdate, 'version': versionInfo.latestVersion},
      );
    } catch (e, st) {
      // Catch any dialog-related errors to prevent crashes
      // Do NOT set _hasShownDialog on error - allow retry
      LoggerService.error(
        'Error showing update dialog',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Show update dialog with safe context handling
  ///
  /// Uses a retry mechanism to ensure navigator context is available
  /// before showing the dialog. Prevents crashes when app is still initializing.
  void _showUpdateDialog(AppVersionEntity versionInfo, {bool forceUpdate = false}) {
    if (!mounted) return;

    // NOTE: _hasShownDialog is NOT set here - it's set AFTER dialog shows successfully
    // This prevents permanent suppression if all retries fail

    // Wait for Navigator to be fully ready (increased from 500ms to 1000ms)
    // This prevents crashes during app initialization/update
    // Cancel ALL existing timers to prevent duplicate dialogs and overlapping retry chains
    _dialogTimer?.cancel();
    _retryTimer?.cancel(); // CRITICAL: Cancel retry timer to prevent race conditions
    _dialogTimer = Timer(const Duration(milliseconds: 1000), () {
      _attemptShowDialog(versionInfo, forceUpdate, retryCount: 0);
    });
  }

  /// Attempt to show dialog with retry mechanism
  ///
  /// Retries up to 3 times with exponential backoff (500ms, 1000ms, 2000ms),
  /// then one final retry after 5 seconds for slow cold starts.
  /// This prevents crashes when rootNavigatorKey.currentContext is null.
  /// Sets _hasShownDialog ONLY after successful dialog display.
  void _attemptShowDialog(
    AppVersionEntity versionInfo,
    bool forceUpdate, {
    required int retryCount,
  }) {
    if (!mounted) return;

    // Defense-in-depth: Bail early if dialog already shown
    // (prevents duplicate dialogs from any stale timers)
    if (_hasShownDialog) return;

    final navigatorContext = rootNavigatorKey.currentContext;

    if (navigatorContext == null) {
      // Navigator not ready yet
      if (retryCount < 3) {
        // Retry after delay (exponential backoff: 500ms, 1000ms, 2000ms)
        final delayMs = 500 * (1 << retryCount); // 500ms * 2^retryCount
        LoggerService.debug(
          'Navigator context not ready, retrying...',
          metadata: {'retryCount': retryCount, 'delayMs': delayMs},
        );

        // Cancel existing retry timer before creating new one
        _retryTimer?.cancel();
        _retryTimer = Timer(Duration(milliseconds: delayMs), () {
          _attemptShowDialog(versionInfo, forceUpdate, retryCount: retryCount + 1);
        });
      } else {
        // After 3 fast retries, schedule one final retry after 5 seconds
        // This handles slow cold starts without blocking future attempts
        LoggerService.debug(
          'Navigator context unavailable after 3 retries, scheduling final retry in 5s...',
        );

        _retryTimer?.cancel();
        _retryTimer = Timer(const Duration(seconds: 5), () {
          if (!mounted || _hasShownDialog) return;

          final context = rootNavigatorKey.currentContext;
          if (context != null) {
            // SUCCESS: Navigator ready after extended delay
            _presentDialog(context, versionInfo, forceUpdate);
          } else {
            // PERMANENT FAILURE: Log and allow future ref.listen to retry
            LoggerService.warn(
              'Failed to show update dialog: navigator context unavailable after final retry (9.5s total)',
            );
          }
        });
      }
      return;
    }

    // Navigator is ready, show the dialog
    _presentDialog(navigatorContext, versionInfo, forceUpdate);
  }

  @override
  Widget build(BuildContext context) {
    // Listen to version check state changes
    // Using safe null handling to prevent crashes if latestVersion is null
    ref.listen<VersionCheckState>(versionCheckProvider, (previous, next) {
      if (!mounted || _hasShownDialog) return;

      // Null safety: Only show dialog if latestVersion is available
      final latestVersion = next.latestVersion;
      if (latestVersion == null) {
        LoggerService.debug('Version check completed but latestVersion is null');
        return;
      }

      // Show dialog when update becomes available
      if (next.shouldShowUpdateDialog) {
        _showUpdateDialog(latestVersion);
      } else if (next.requiresForceUpdate) {
        _showUpdateDialog(latestVersion, forceUpdate: true);
      }
    });

    return widget.child;
  }
}
