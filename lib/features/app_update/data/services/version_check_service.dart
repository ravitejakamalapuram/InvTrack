import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:inv_tracker/features/app_update/domain/entities/app_version_entity.dart';

/// Service to check for app updates from Firestore
class VersionCheckService {
  final FirebaseFirestore _firestore;

  VersionCheckService(this._firestore);

  /// Fetch latest version info from Firestore
  ///
  /// Document structure in Firestore:
  /// Collection: app_config
  /// Document: version_info
  /// Fields:
  ///   - latestVersion: "3.23.0"
  ///   - latestBuildNumber: 55
  ///   - minimumVersion: "3.20.0"
  ///   - minimumBuildNumber: 50
  ///   - forceUpdate: false
  ///   - updateMessage: "New features available!"
  ///   - whatsNew: "- Feature 1\n- Feature 2"
  ///   - downloadUrl: "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker"
  Future<AppVersionEntity?> fetchLatestVersion() async {
    try {
      final doc = await _firestore
          .collection('app_config')
          .doc('version_info')
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Version check timed out'),
          );

      if (!doc.exists) {
        if (kDebugMode) {
          debugPrint('⚠️ Version info document does not exist');
        }
        return null;
      }

      final data = doc.data();
      if (data == null) {
        if (kDebugMode) {
          debugPrint('⚠️ Version info data is null');
        }
        return null;
      }

      return AppVersionEntity.fromMap(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error fetching version info: $e');
      }
      return null;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
