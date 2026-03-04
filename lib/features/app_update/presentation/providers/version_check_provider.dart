import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/features/app_update/data/services/version_check_service.dart';
import 'package:inv_tracker/features/app_update/domain/entities/app_version_entity.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

/// Provider for version check service
final versionCheckServiceProvider = Provider<VersionCheckService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return VersionCheckService(firestore);
});

/// State for version check
class VersionCheckState {
  final AppVersionEntity? latestVersion;
  final String currentVersion;
  final int currentBuildNumber;
  final bool isLoading;
  final bool hasChecked;
  final DateTime? lastCheckedAt;
  final bool updateDismissed;

  const VersionCheckState({
    this.latestVersion,
    required this.currentVersion,
    required this.currentBuildNumber,
    this.isLoading = false,
    this.hasChecked = false,
    this.lastCheckedAt,
    this.updateDismissed = false,
  });

  bool get hasUpdate =>
      latestVersion != null &&
      latestVersion!.isOutdated(currentVersion, currentBuildNumber) &&
      latestVersion!.isReleased(); // Only show if released on Play Store

  bool get requiresForceUpdate =>
      latestVersion != null &&
      latestVersion!.requiresForceUpdate(currentVersion, currentBuildNumber) &&
      latestVersion!.isReleased(); // Only force if released on Play Store

  bool get shouldShowUpdateDialog =>
      hasUpdate && !updateDismissed && !requiresForceUpdate;

  VersionCheckState copyWith({
    AppVersionEntity? latestVersion,
    String? currentVersion,
    int? currentBuildNumber,
    bool? isLoading,
    bool? hasChecked,
    DateTime? lastCheckedAt,
    bool? updateDismissed,
  }) {
    return VersionCheckState(
      latestVersion: latestVersion ?? this.latestVersion,
      currentVersion: currentVersion ?? this.currentVersion,
      currentBuildNumber: currentBuildNumber ?? this.currentBuildNumber,
      isLoading: isLoading ?? this.isLoading,
      hasChecked: hasChecked ?? this.hasChecked,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      updateDismissed: updateDismissed ?? this.updateDismissed,
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
  late final SharedPreferences _prefs;

  static const String _lastCheckedKey = 'version_last_checked';
  static const String _dismissedVersionKey = 'version_dismissed';

  @override
  VersionCheckState build() {
    _service = ref.watch(versionCheckServiceProvider);
    _prefs = ref.watch(sharedPreferencesProvider);

    _initialize();

    return VersionCheckState(currentVersion: '0.0.0', currentBuildNumber: 0);
  }

  Future<void> _initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final lastChecked = _prefs.getString(_lastCheckedKey);
      final dismissedVersion = _prefs.getString(_dismissedVersionKey);

      state = state.copyWith(
        currentVersion: packageInfo.version,
        currentBuildNumber: int.tryParse(packageInfo.buildNumber) ?? 0,
        lastCheckedAt: lastChecked != null
            ? DateTime.tryParse(lastChecked)
            : null,
        updateDismissed: dismissedVersion == packageInfo.version,
      );

      // Auto-check on initialization if not checked in last 24 hours
      if (_shouldAutoCheck()) {
        await checkForUpdates();
      }
    } catch (e) {
      LoggerService.error('Error initializing version check', error: e);
    }
  }

  bool _shouldAutoCheck() {
    if (state.lastCheckedAt == null) return true;
    final hoursSinceCheck = DateTime.now()
        .difference(state.lastCheckedAt!)
        .inHours;
    return hoursSinceCheck >= 24;
  }

  /// Check for updates from remote
  Future<void> checkForUpdates() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true);

    try {
      final latestVersion = await _service.fetchLatestVersion();
      final now = DateTime.now();

      await _prefs.setString(_lastCheckedKey, now.toIso8601String());

      state = state.copyWith(
        latestVersion: latestVersion,
        isLoading: false,
        hasChecked: true,
        lastCheckedAt: now,
      );

      LoggerService.info('Version check complete', metadata: {
        'latestVersion': latestVersion?.latestVersion,
      });
    } catch (e) {
      LoggerService.error('Error checking for updates', error: e);
      state = state.copyWith(isLoading: false, hasChecked: true);
    }
  }

  /// Dismiss update notification for current version
  Future<void> dismissUpdate() async {
    await _prefs.setString(_dismissedVersionKey, state.currentVersion);
    state = state.copyWith(updateDismissed: true);
  }

  /// Reset dismissed state (for testing or manual check)
  Future<void> resetDismissed() async {
    await _prefs.remove(_dismissedVersionKey);
    state = state.copyWith(updateDismissed: false);
  }
}
