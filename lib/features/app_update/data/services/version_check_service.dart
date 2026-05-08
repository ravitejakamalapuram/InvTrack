import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:inv_tracker/core/error/error_handler.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
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
  ///   - releaseDate: Timestamp (optional - if null, shows immediately)
  ///
  /// BUG FIX: Added better logging to diagnose why popup doesn't show
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
        // BUG FIX: More helpful log message for missing document
        LoggerService.warn(
          'Version info document does not exist in Firestore. '
          'Create document at: app_config/version_info with required fields. '
          'See version_check_service.dart for document structure.',
        );
        return null;
      }

      final data = doc.data();
      if (data == null) {
        LoggerService.warn('Version info data is null');
        return null;
      }

      // BUG FIX: Log retrieved version info for debugging
      LoggerService.debug(
        'Version info fetched from Firestore',
        metadata: {
          'latestVersion': data['latestVersion'],
          'latestBuildNumber': data['latestBuildNumber'],
          'releaseDate': data['releaseDate']?.toString(),
        },
      );

      return AppVersionEntity.fromMap(data);
    } catch (e, st) {
      // Map exception to AppException to properly classify transient errors
      final appException = ErrorHandler.mapException(e, st);

      // Only log to Crashlytics if it's a reportable error
      // Transient network errors (unavailable, timeout) have shouldReport = false
      if (appException.shouldReport) {
        LoggerService.error(
          'Error fetching version info',
          error: e,
          stackTrace: st,
        );
      } else {
        // Just log as warning for transient errors (no Crashlytics spam)
        LoggerService.warn('Version check failed (transient)', error: e);
      }

      return null;
    }
  }

  /// BUG FIX: Helper to initialize version_info document in Firestore
  ///
  /// This should be called ONCE from Firebase Console or a debug tool
  /// to set up the version checking system.
  ///
  /// Example usage in Firestore console:
  /// ```
  /// Collection: app_config
  /// Document ID: version_info
  /// Fields:
  ///   latestVersion (string): "3.23.0"
  ///   latestBuildNumber (number): 55
  ///   minimumVersion (string): "3.20.0"
  ///   minimumBuildNumber (number): 50
  ///   forceUpdate (boolean): false
  ///   updateMessage (string): "New features available!"
  ///   whatsNew (string): "- Portfolio Health Score\n- Multi-currency support"
  ///   downloadUrl (string): "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker"
  ///   releaseDate (timestamp): null (or set to future date if not yet released)
  /// ```
  Future<void> initializeVersionDocument({
    required String latestVersion,
    required int latestBuildNumber,
    required String minimumVersion,
    required int minimumBuildNumber,
    bool forceUpdate = false,
    String? updateMessage,
    String? whatsNew,
    String? downloadUrl,
    DateTime? releaseDate,
  }) async {
    try {
      final data = {
        'latestVersion': latestVersion,
        'latestBuildNumber': latestBuildNumber,
        'minimumVersion': minimumVersion,
        'minimumBuildNumber': minimumBuildNumber,
        'forceUpdate': forceUpdate,
        'updateMessage': updateMessage,
        'whatsNew': whatsNew,
        'downloadUrl': downloadUrl,
        'releaseDate': releaseDate != null
            ? Timestamp.fromDate(releaseDate)
            : null,
      };

      await _firestore
          .collection('app_config')
          .doc('version_info')
          .set(data, SetOptions(merge: true));

      LoggerService.info(
        'Version info document initialized',
        metadata: {'version': latestVersion, 'buildNumber': latestBuildNumber},
      );
    } catch (e, st) {
      LoggerService.error(
        'Error initializing version document',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}
