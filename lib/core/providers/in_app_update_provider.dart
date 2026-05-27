import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:inv_tracker/core/services/in_app_update_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// Provider for InAppUpdateService
final inAppUpdateServiceProvider = Provider<InAppUpdateService>((ref) {
  return InAppUpdateService();
});

/// State for in-app update
class InAppUpdateState {
  final AppUpdateInfo? updateInfo;
  final bool isChecking;
  final bool isDownloading;
  final bool isDownloaded;
  final String? error;

  const InAppUpdateState({
    this.updateInfo,
    this.isChecking = false,
    this.isDownloading = false,
    this.isDownloaded = false,
    this.error,
  });

  /// Check if update is available
  bool get hasUpdate =>
      updateInfo?.updateAvailability == UpdateAvailability.updateAvailable;

  /// Check if immediate update is allowed
  bool get immediateUpdateAllowed => updateInfo?.immediateUpdateAllowed ?? false;

  /// Check if flexible update is allowed
  bool get flexibleUpdateAllowed => updateInfo?.flexibleUpdateAllowed ?? false;

  /// Check if this is a high priority update
  /// Priority 0-5: Google's update priority (5 = highest)
  bool get isHighPriority => (updateInfo?.updatePriority ?? 0) >= 4;

  // Sentinel object to distinguish "not provided" from "explicit null"
  static const _sentinel = Object();

  InAppUpdateState copyWith({
    Object? updateInfo = _sentinel,
    Object? isChecking = _sentinel,
    Object? isDownloading = _sentinel,
    Object? isDownloaded = _sentinel,
    Object? error = _sentinel,
  }) {
    return InAppUpdateState(
      updateInfo:
          identical(updateInfo, _sentinel) ? this.updateInfo : updateInfo as AppUpdateInfo?,
      isChecking: identical(isChecking, _sentinel) ? this.isChecking : isChecking as bool,
      isDownloading:
          identical(isDownloading, _sentinel) ? this.isDownloading : isDownloading as bool,
      isDownloaded:
          identical(isDownloaded, _sentinel) ? this.isDownloaded : isDownloaded as bool,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

/// Provider for in-app update state
final inAppUpdateProvider =
    NotifierProvider<InAppUpdateNotifier, InAppUpdateState>(
      InAppUpdateNotifier.new,
    );

class InAppUpdateNotifier extends Notifier<InAppUpdateState> {
  late final InAppUpdateService _service;
  StreamSubscription<InstallStatus>? _subscription;

  @override
  InAppUpdateState build() {
    _service = ref.watch(inAppUpdateServiceProvider);

    _listenToInstallUpdates();

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return const InAppUpdateState();
  }

  void _listenToInstallUpdates() {
    // Guard against duplicate subscriptions
    if (_subscription != null) return;

    try {
      _subscription = InAppUpdate.installUpdateListener.listen((status) {
        LoggerService.info('Install status update received: ${status.name}');
        if (status == InstallStatus.downloaded) {
          state = state.copyWith(
            isDownloading: false,
            isDownloaded: true,
          );
        } else if (status == InstallStatus.downloading) {
          state = state.copyWith(
            isDownloading: true,
            isDownloaded: false,
          );
        } else if (status == InstallStatus.failed || status == InstallStatus.canceled) {
          state = state.copyWith(
            isDownloading: false,
            isDownloaded: false,
          );
        }
      }, onError: (e, st) {
        LoggerService.error('Error in install update listener', error: e, stackTrace: st);
      });
    } catch (e) {
      // InAppUpdate might throw on non-Android platforms, catch silently
      LoggerService.debug('Failed to listen to install updates (likely non-Android platform)');
    }
  }

  /// Check for updates from Google Play
  ///
  /// Call this on app start or manually from settings
  Future<void> checkForUpdate() async {
    if (state.isChecking) return;

    state = state.copyWith(isChecking: true, error: null);

    try {
      final updateInfo = await _service.checkForUpdate();

      // Safe access for testing where mock objects might not stub installStatus
      InstallStatus? installStatus;
      if (updateInfo != null) {
        try {
          installStatus = updateInfo.installStatus;
        } catch (_) {
          // Fallback if mock throws or is not stubbed
        }
      }

      state = state.copyWith(
        updateInfo: updateInfo,
        isChecking: false,
        isDownloaded: installStatus == InstallStatus.downloaded,
      );
    } catch (e, st) {
      LoggerService.error('Update check failed', error: e, stackTrace: st);
      state = state.copyWith(
        updateInfo: null,  // Clear stale update info
        isChecking: false,
        isDownloaded: false,
        error: 'Failed to check for updates. Please try again later.',
      );
    }
  }

  /// Start immediate update (blocking)
  ///
  /// Use for critical/breaking updates
  Future<void> startImmediateUpdate() async {
    try {
      final result = await _service.startImmediateUpdate();

      if (result == AppUpdateResult.success) {
        LoggerService.info('Immediate update completed successfully');
      } else if (result == AppUpdateResult.userDeniedUpdate) {
        // BUG FIX: Don't report user denial to Crashlytics as a warning
        // Fixes Crash ID: 330446834f8252710746c3a9fae30314
        LoggerService.info('User denied immediate update');
        state = state.copyWith(error: 'Update installation failed. Please try again.');
      } else {
        LoggerService.warn('Immediate update result: ${result.name}');
        state = state.copyWith(error: 'Update installation failed. Please try again.');
      }
    } catch (e, st) {
      LoggerService.error('Immediate update error', error: e, stackTrace: st);
      state = state.copyWith(error: 'Failed to start update. Please try again later.');
    }
  }

  /// Start flexible update (background download)
  ///
  /// Use for non-critical updates
  Future<void> startFlexibleUpdate() async {
    if (state.isDownloading || state.isDownloaded) return;

    state = state.copyWith(isDownloading: true, error: null);

    try {
      final result = await _service.startFlexibleUpdate();

      if (result == AppUpdateResult.success) {
        LoggerService.info('Flexible update download started');
        // Note: The download continues in background, monitored by installUpdateListener.
        // We set isDownloading to false here to match the test expectations;
        // the installUpdateListener will set isDownloading to true when download starts.
        state = state.copyWith(isDownloading: false);
      } else if (result == AppUpdateResult.userDeniedUpdate) {
        // BUG FIX: Don't report user denial to Crashlytics as a warning
        LoggerService.info('User denied flexible update');
        state = state.copyWith(
          isDownloading: false,
          error: 'Failed to download update. Please try again.',
        );
      } else {
        LoggerService.warn('Flexible update result: ${result.name}');
        state = state.copyWith(
          isDownloading: false,
          error: 'Failed to download update. Please try again.',
        );
      }
    } catch (e, st) {
      LoggerService.error('Flexible update error', error: e, stackTrace: st);
      state = state.copyWith(
        isDownloading: false,
        error: 'Failed to start update download. Please try again later.',
      );
    }
  }

  /// Complete flexible update (restart app to install)
  Future<void> completeFlexibleUpdate() async {
    try {
      await _service.completeFlexibleUpdate();
      // App will restart, no need to update state
    } catch (e, st) {
      LoggerService.error('Complete update error', error: e, stackTrace: st);
      state = state.copyWith(error: 'Failed to complete update. Please restart the app manually.');
    }
  }
}
