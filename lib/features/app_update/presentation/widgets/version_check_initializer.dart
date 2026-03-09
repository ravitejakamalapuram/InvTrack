import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/router/app_router.dart';
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
  Timer? _retryTimer;

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
    _retryTimer?.cancel();
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

    // Trigger the version check
    await ref.read(versionCheckProvider.notifier).checkForUpdates();

    if (!mounted) return;

    final versionState = ref.read(versionCheckProvider);

    // Show dialog if update is available and not dismissed
    if (versionState.shouldShowUpdateDialog && !_hasShownDialog) {
      _showUpdateDialog(versionState.latestVersion!);
    } else if (versionState.requiresForceUpdate && !_hasShownDialog) {
      _showUpdateDialog(versionState.latestVersion!, forceUpdate: true);
    }
  }

  void _showUpdateDialog(dynamic versionInfo, {bool forceUpdate = false}) {
    if (!mounted) return;

    _hasShownDialog = true;

    // Wait for Navigator to be ready
    _dialogTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      final navigatorContext = rootNavigatorKey.currentContext;
      if (navigatorContext == null) {
        // Navigator still not ready, try one more time
        _retryTimer = Timer(const Duration(milliseconds: 500), () {
          if (!mounted) return;

          final retryContext = rootNavigatorKey.currentContext;
          if (retryContext != null) {
            showDialog(
              context: retryContext,
              barrierDismissible: !forceUpdate,
              builder: (context) => UpdateDialog(
                versionInfo: versionInfo,
                forceUpdate: forceUpdate,
              ),
            );
          }
        });
        return;
      }

      showDialog(
        context: navigatorContext,
        barrierDismissible: !forceUpdate,
        builder: (context) =>
            UpdateDialog(versionInfo: versionInfo, forceUpdate: forceUpdate),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Listen to version check state changes
    ref.listen<VersionCheckState>(versionCheckProvider, (previous, next) {
      if (!mounted || _hasShownDialog) return;

      // Show dialog when update becomes available
      if (next.shouldShowUpdateDialog) {
        _showUpdateDialog(next.latestVersion!);
      } else if (next.requiresForceUpdate) {
        _showUpdateDialog(next.latestVersion!, forceUpdate: true);
      }
    });

    return widget.child;
  }
}
