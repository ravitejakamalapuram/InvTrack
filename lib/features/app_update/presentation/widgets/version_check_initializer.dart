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

  /// Show update dialog with safe context handling
  ///
  /// Uses a retry mechanism to ensure navigator context is available
  /// before showing the dialog. Prevents crashes when app is still initializing.
  void _showUpdateDialog(AppVersionEntity versionInfo, {bool forceUpdate = false}) {
    if (!mounted) return;

    _hasShownDialog = true;

    // Wait for Navigator to be fully ready (increased from 500ms to 1000ms)
    // This prevents crashes during app initialization/update
    _dialogTimer = Timer(const Duration(milliseconds: 1000), () {
      _attemptShowDialog(versionInfo, forceUpdate, retryCount: 0);
    });
  }

  /// Attempt to show dialog with retry mechanism
  ///
  /// Retries up to 3 times if navigator context is not yet available.
  /// This prevents crashes when rootNavigatorKey.currentContext is null.
  void _attemptShowDialog(
    AppVersionEntity versionInfo,
    bool forceUpdate, {
    required int retryCount,
  }) {
    if (!mounted) return;

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

        Timer(Duration(milliseconds: delayMs), () {
          _attemptShowDialog(versionInfo, forceUpdate, retryCount: retryCount + 1);
        });
      } else {
        // Give up after 3 retries
        LoggerService.warn(
          'Failed to show update dialog: navigator context unavailable after 3 retries',
        );
      }
      return;
    }

    // Navigator is ready, show the dialog
    try {
      showDialog(
        context: navigatorContext,
        barrierDismissible: !forceUpdate,
        builder: (context) => UpdateDialog(
          versionInfo: versionInfo,
          forceUpdate: forceUpdate,
        ),
      );
      LoggerService.info(
        'Update dialog shown',
        metadata: {'forceUpdate': forceUpdate, 'version': versionInfo.latestVersion},
      );
    } catch (e, st) {
      // Catch any dialog-related errors to prevent crashes
      LoggerService.error(
        'Error showing update dialog',
        error: e,
        stackTrace: st,
      );
    }
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
