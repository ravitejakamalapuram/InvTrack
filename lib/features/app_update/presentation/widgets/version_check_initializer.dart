import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/router/app_router.dart';
import 'package:inv_tracker/features/app_update/presentation/providers/version_check_provider.dart';
import 'package:inv_tracker/features/app_update/presentation/widgets/update_dialog.dart';

/// Widget that initializes version checking on app start
///
/// Simple, industry-standard approach:
/// 1. Checks for updates 3 seconds after app start
/// 2. Shows dialog once per session if update available
/// 3. No complex retry logic - either works or doesn't
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
  Timer? _versionCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleVersionCheck();
    });
  }

  @override
  void dispose() {
    _versionCheckTimer?.cancel();
    _versionCheckTimer = null;
    super.dispose();
  }

  void _scheduleVersionCheck() {
    _versionCheckTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      _performVersionCheck();
    });
  }

  Future<void> _performVersionCheck() async {
    try {
      await ref.read(versionCheckProvider.notifier).checkForUpdates();
      if (!mounted) return;
      final state = ref.read(versionCheckProvider);
      if (state.latestVersion == null) {
        LoggerService.debug('No version info available');
        return;
      }
      if (state.requiresForceUpdate) {
        _showUpdateDialog(forceUpdate: true);
      } else if (state.shouldShowUpdateDialog) {
        _showUpdateDialog(forceUpdate: false);
      }
    } catch (e, st) {
      LoggerService.error('Version check failed', error: e, stackTrace: st);
    }
  }

  void _showUpdateDialog({required bool forceUpdate}) {
    if (_hasShownDialog || !mounted) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      LoggerService.warn('Navigator context not available for update dialog');
      return;
    }
    final versionInfo = ref.read(versionCheckProvider).latestVersion;
    if (versionInfo == null) return;
    _hasShownDialog = true;
    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (_) => UpdateDialog(
        versionInfo: versionInfo,
        forceUpdate: forceUpdate,
      ),
    );
    LoggerService.info(
      'Update dialog shown',
      metadata: {
        'version': versionInfo.latestVersion,
        'forceUpdate': forceUpdate,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VersionCheckState>(versionCheckProvider, (previous, next) {
      if (_hasShownDialog || !mounted) return;
      if (next.latestVersion == null) return;
      if (next.requiresForceUpdate) {
        _showUpdateDialog(forceUpdate: true);
      } else if (next.shouldShowUpdateDialog) {
        _showUpdateDialog(forceUpdate: false);
      }
    });
    return widget.child;
  }
}
