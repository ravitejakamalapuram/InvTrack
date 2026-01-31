/// Entity representing app version information from remote config
class AppVersionEntity {
  final String latestVersion;
  final int latestBuildNumber;
  final String minimumVersion;
  final int minimumBuildNumber;
  final bool forceUpdate;
  final String? updateMessage;
  final String? whatsNew;
  final String? downloadUrl;
  final DateTime? releaseDate; // When the update becomes available on Play Store

  const AppVersionEntity({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.minimumVersion,
    required this.minimumBuildNumber,
    this.forceUpdate = false,
    this.updateMessage,
    this.whatsNew,
    this.downloadUrl,
    this.releaseDate,
  });

  /// Check if current version is outdated
  bool isOutdated(String currentVersion, int currentBuildNumber) {
    return currentBuildNumber < latestBuildNumber;
  }

  /// Check if current version requires force update
  bool requiresForceUpdate(String currentVersion, int currentBuildNumber) {
    return forceUpdate && currentBuildNumber < minimumBuildNumber;
  }

  /// Check if the update is available on Play Store yet
  /// Returns true if releaseDate is null (backward compatibility) or if release date has passed
  bool isReleased() {
    if (releaseDate == null) return true; // No release date = show immediately
    return DateTime.now().isAfter(releaseDate!);
  }

  factory AppVersionEntity.fromMap(Map<String, dynamic> map) {
    DateTime? releaseDate;
    if (map['releaseDate'] != null) {
      // Support both Timestamp and String formats
      final releaseDateValue = map['releaseDate'];
      if (releaseDateValue is String) {
        releaseDate = DateTime.tryParse(releaseDateValue);
      } else if (releaseDateValue is int) {
        // Firestore Timestamp in milliseconds
        releaseDate = DateTime.fromMillisecondsSinceEpoch(releaseDateValue);
      }
    }

    return AppVersionEntity(
      latestVersion: map['latestVersion'] as String,
      latestBuildNumber: (map['latestBuildNumber'] as num).toInt(),
      minimumVersion: map['minimumVersion'] as String,
      minimumBuildNumber: (map['minimumBuildNumber'] as num).toInt(),
      forceUpdate: map['forceUpdate'] as bool? ?? false,
      updateMessage: map['updateMessage'] as String?,
      whatsNew: map['whatsNew'] as String?,
      downloadUrl: map['downloadUrl'] as String?,
      releaseDate: releaseDate,
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
      'releaseDate': releaseDate?.toIso8601String(),
    };
  }
}

