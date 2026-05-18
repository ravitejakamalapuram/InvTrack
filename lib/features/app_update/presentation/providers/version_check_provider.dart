import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/app_update/data/services/version_check_service.dart';
import 'package:inv_tracker/features/app_update/domain/entities/app_version_entity.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Provider for version check service
final versionCheckServiceProvider = Provider<VersionCheckService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return VersionCheckService(firestore);
});

/// State for version check
///
/// Simplified: no persistent dismissal, only session-based.
/// If user dismisses dialog, it won't show again until app restarts.
class VersionCheckState {
  final AppVersionEntity? latestVersion;
  final String currentVersion;
  final int currentBuildNumber;
  final bool isLoading;
  final bool hasChecked;
  final bool dismissedThisSession; // Session-based, resets on app restart

  const VersionCheckState({
    this.latestVersion,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.isLoading = false,
    this.hasChecked = false,
    this.dismissedThisSession = false,
  });

  /// Check if update is available (simple build number check)
  bool get hasUpdate =>
      latestVersion != null &&
      latestVersion!.isOutdated(currentBuildNumber);

  /// Check if force update required
  bool get requiresForceUpdate =>
      latestVersion != null &&
      latestVersion!.requiresForceUpdate(currentBuildNumber);

  /// Should show dialog? (not dismissed this session + update available)
  bool get shouldShowUpdateDialog {
    return hasUpdate && !dismissedThisSession && !requiresForceUpdate;
  }

  VersionCheckState copyWith({
    AppVersionEntity? latestVersion,
    String? currentVersion,
    int? currentBuildNumber,
    bool? isLoading,
    bool? hasChecked,
    bool? dismissedThisSession,
  }) {
    return VersionCheckState(
      latestVersion: latestVersion ?? this.latestVersion,
      currentVersion: currentVersion ?? this.currentVersion,
      currentBuildNumber: currentBuildNumber ?? this.currentBuildNumber,
      isLoading: isLoading ?? this.isLoading,
      hasChecked: hasChecked ?? this.hasChecked,
      dismissedThisSession: dismissedThisSession ?? this.dismissedThisSession,
    );
  }
}

/// Provider for version check state
final versionCheckProvider =
    NotifierProvider<VersionCheckNotifier, VersionCheckState>(
      VersionCheckNotifier.new,
    );

class VersionCheckNotifier extends Notifier<VersionCheckState> {
  late final VersionCheckService _service;

  @override
  VersionCheckState build() {
    _service = ref.watch(versionCheckServiceProvider);

    _initialize();

    return VersionCheckState(currentVersion: '0.0.0', currentBuildNumber: 0);
  }

  Future<void> _initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      state = state.copyWith(
        currentVersion: packageInfo.version,
        currentBuildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
      );
    } catch (e) {
      LoggerService.error('Error initializing version check', error: e);
    }
  }

  /// Check for updates from remote
  /// This is called:
  /// 1. On app start (via VersionCheckInitializer)
  /// 2. Manually from Settings screen
  ///
  /// Uses two-track system:
  /// - Beta users check version_info_beta
  /// - Production users check version_info
  Future<void> checkForUpdates() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      // Detect if this is a beta build
      final packageInfo = await PackageInfo.fromPlatform();
      final isBetaUser = _isBetaBuild(packageInfo);

      // Fetch appropriate version document
      final latestVersion = await _service.fetchLatestVersion(isBetaUser: isBetaUser);

      state = state.copyWith(
        latestVersion: latestVersion,
        isLoading: false,
        hasChecked: true,
      );

      if (latestVersion != null) {
        final isOutdated = latestVersion.isOutdated(state.currentBuildNumber);

        LoggerService.info(
          'Version check complete',
          metadata: {
            'isBetaUser': isBetaUser,
            'currentVersion': state.currentVersion,
            'currentBuildNumber': state.currentBuildNumber,
            'latestVersion': latestVersion.latestVersion,
            'latestBuildNumber': latestVersion.latestBuildNumber,
            'isOutdated': isOutdated,
            'shouldShowDialog': state.shouldShowUpdateDialog,
          },
        );
      } else {
        LoggerService.debug('No version info available from Firestore');
      }
    } catch (e, st) {
      LoggerService.error('Error checking for updates', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false, hasChecked: true);
    }
  }

  /// Detect if user is running a beta build
  ///
  /// Beta builds have different package name:
  /// - Production: com.invtracker.inv_tracker
  /// - Beta: com.invtracker.inv_tracker.beta
  bool _isBetaBuild(PackageInfo packageInfo) {
    return packageInfo.packageName.endsWith('.beta');
  }

  /// Dismiss update notification for this session only
  /// Dialog will show again on next app restart
  void dismissUpdate() {
    state = state.copyWith(dismissedThisSession: true);
    LoggerService.debug('Update dismissed for this session');
  }
}
