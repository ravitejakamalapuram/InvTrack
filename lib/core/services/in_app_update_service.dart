import 'package:in_app_update/in_app_update.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';

/// Service for handling Google Play In-App Updates
///
/// Supports two update modes:
/// - Immediate: Blocks user until update is installed (for critical updates)
/// - Flexible: Allows user to continue using app while downloading
///
/// Platform: Android only (Google Play)
class InAppUpdateService {
  /// Check if an update is available from Google Play
  ///
  /// Returns update info if available, null otherwise
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();
      
      LoggerService.info(
        'Update check complete',
        metadata: {
          'updateAvailable': updateInfo.updateAvailability == UpdateAvailability.updateAvailable,
          'immediateAllowed': updateInfo.immediateUpdateAllowed,
          'flexibleAllowed': updateInfo.flexibleUpdateAllowed,
          'availableVersionCode': updateInfo.availableVersionCode,
          'updatePriority': updateInfo.updatePriority,
        },
      );
      
      return updateInfo;
    } catch (e, st) {
      LoggerService.error('Failed to check for update', error: e, stackTrace: st);
      return null;
    }
  }

  /// Start an immediate update flow
  ///
  /// Blocks user until update is installed
  /// Use for critical/breaking updates
  Future<AppUpdateResult> startImmediateUpdate() async {
    try {
      LoggerService.info('Starting immediate update');
      
      final result = await InAppUpdate.performImmediateUpdate();
      
      LoggerService.info(
        'Immediate update result',
        metadata: {'result': result.name},
      );
      
      return result;
    } catch (e, st) {
      LoggerService.error('Immediate update failed', error: e, stackTrace: st);
      return AppUpdateResult.inAppUpdateFailed;
    }
  }

  /// Start a flexible update flow
  ///
  /// Downloads update in background, user can continue using app
  /// Call completeFlexibleUpdate() when download finishes
  Future<AppUpdateResult> startFlexibleUpdate() async {
    try {
      LoggerService.info('Starting flexible update');
      
      final result = await InAppUpdate.startFlexibleUpdate();
      
      LoggerService.info(
        'Flexible update started',
        metadata: {'result': result.name},
      );
      
      return result;
    } catch (e, st) {
      LoggerService.error('Flexible update failed', error: e, stackTrace: st);
      return AppUpdateResult.inAppUpdateFailed;
    }
  }

  /// Complete a flexible update
  ///
  /// Call this after flexible update download completes
  /// Restarts app to install update
  Future<void> completeFlexibleUpdate() async {
    try {
      LoggerService.info('Completing flexible update');
      await InAppUpdate.completeFlexibleUpdate();
    } catch (e, st) {
      LoggerService.error('Failed to complete flexible update', error: e, stackTrace: st);
    }
  }
}
