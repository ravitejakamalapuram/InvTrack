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
  final String? error;

  const InAppUpdateState({
    this.updateInfo,
    this.isChecking = false,
    this.isDownloading = false,
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

  InAppUpdateState copyWith({
    AppUpdateInfo? updateInfo,
    bool? isChecking,
    bool? isDownloading,
    String? error,
  }) {
    return InAppUpdateState(
      updateInfo: updateInfo ?? this.updateInfo,
      isChecking: isChecking ?? this.isChecking,
      isDownloading: isDownloading ?? this.isDownloading,
      error: error ?? this.error,
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

  @override
  InAppUpdateState build() {
    _service = ref.watch(inAppUpdateServiceProvider);
    return const InAppUpdateState();
  }

  /// Check for updates from Google Play
  ///
  /// Call this on app start or manually from settings
  Future<void> checkForUpdate() async {
    if (state.isChecking) return;

    state = state.copyWith(isChecking: true, error: null);

    try {
      final updateInfo = await _service.checkForUpdate();

      state = state.copyWith(
        updateInfo: updateInfo,
        isChecking: false,
      );
    } catch (e, st) {
      LoggerService.error('Update check failed', error: e, stackTrace: st);
      state = state.copyWith(
        isChecking: false,
        error: e.toString(),
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
      } else {
        LoggerService.warn('Immediate update result: ${result.name}');
        state = state.copyWith(error: 'Update failed: ${result.name}');
      }
    } catch (e, st) {
      LoggerService.error('Immediate update error', error: e, stackTrace: st);
      state = state.copyWith(error: e.toString());
    }
  }

  /// Start flexible update (background download)
  ///
  /// Use for non-critical updates
  Future<void> startFlexibleUpdate() async {
    if (state.isDownloading) return;

    state = state.copyWith(isDownloading: true, error: null);

    try {
      final result = await _service.startFlexibleUpdate();

      if (result == AppUpdateResult.success) {
        LoggerService.info('Flexible update download started');
        // Note: Download progress should be monitored separately
        // Call completeFlexibleUpdate() when download finishes
      } else {
        LoggerService.warn('Flexible update result: ${result.name}');
        state = state.copyWith(
          isDownloading: false,
          error: 'Update failed: ${result.name}',
        );
      }
    } catch (e, st) {
      LoggerService.error('Flexible update error', error: e, stackTrace: st);
      state = state.copyWith(
        isDownloading: false,
        error: e.toString(),
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
      state = state.copyWith(error: e.toString());
    }
  }
}
