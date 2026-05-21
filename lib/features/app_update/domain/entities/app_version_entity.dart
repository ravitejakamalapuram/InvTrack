/// Entity representing app version information from remote config
///
/// Simplified version - no beta mode filtering, no release dates.
/// Industry-standard approach: if a version exists in Firestore, show it to everyone.
class AppVersionEntity {
  final String latestVersion;
  final int latestBuildNumber;
  final String minimumVersion;
  final int minimumBuildNumber;
  final bool forceUpdate;
  final String? updateMessage;
  final String? whatsNew;
  final String? downloadUrl;

  const AppVersionEntity({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minimumVersion,
    required this.minimumBuildNumber,
    this.forceUpdate = false,
    this.updateMessage,
    this.whatsNew,
    this.downloadUrl,
  });

  /// Check if current version is outdated (simple build number comparison)
  bool isOutdated(int currentBuildNumber) {
    return currentBuildNumber < latestBuildNumber;
  }

  /// Check if current version requires force update
  bool requiresForceUpdate(int currentBuildNumber) {
    return forceUpdate && currentBuildNumber < minimumBuildNumber;
  }

  factory AppVersionEntity.fromMap(Map<String, dynamic> map) {
    // BUG FIX: Add null safety to prevent type cast errors
    // Fixes Crashlytics issue #bb7c3c13ee4b93cf38267bcd7d60ffb7 (16 events)
    return AppVersionEntity(
      latestVersion: map['latestVersion'] as String? ?? '1.0.0',
      latestBuildNumber: (map['latestBuildNumber'] as num?)?.toInt() ?? 1,
      minimumVersion: map['minimumVersion'] as String? ?? '1.0.0',
      minimumBuildNumber: (map['minimumBuildNumber'] as num?)?.toInt() ?? 1,
      forceUpdate: map['forceUpdate'] as bool? ?? false,
      updateMessage: map['updateMessage'] as String?,
      whatsNew: map['whatsNew'] as String?,
      downloadUrl: map['downloadUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latestVersion': latestVersion,
      'latestBuildNumber': latestBuildNumber,
      'minimumVersion': minimumVersion,
      'minimumBuildNumber': minimumBuildNumber,
      'forceUpdate': forceUpdate,
      'updateMessage': updateMessage,
      'whatsNew': whatsNew,
      'downloadUrl': downloadUrl,
    };
  }
}
