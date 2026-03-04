/// Permission handling service for camera access.
///
/// Note: We use system photo picker (SAF - Storage Access Framework) for file selection,
/// which doesn't require READ_MEDIA_IMAGES or READ_MEDIA_VIDEO permissions.
library;

import 'package:permission_handler/permission_handler.dart';

/// Result of a permission request
enum PermissionResult {
  /// Permission was granted
  granted,

  /// Permission was denied (can ask again)
  denied,

  /// Permission was permanently denied (must go to settings)
  permanentlyDenied,

  /// Permission is restricted by OS (parental controls, etc.)
  restricted,

  /// Permission is limited (iOS photos limited access)
  limited,
}

/// Service for handling runtime permissions
class PermissionService {
  const PermissionService();

  /// Request camera permission for document capture
  Future<PermissionResult> requestCamera() async {
    return _requestPermission(Permission.camera);
  }

  /// Check if camera permission is granted
  Future<bool> isCameraGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Open app settings for user to manually enable permissions
  Future<bool> openSettings() async {
    return openAppSettings();
  }

  /// Request a permission and return the result
  Future<PermissionResult> _requestPermission(Permission permission) async {
    final status = await permission.status;

    if (status.isGranted) {
      return PermissionResult.granted;
    }

    if (status.isLimited) {
      return PermissionResult.limited;
    }

    if (status.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }

    if (status.isRestricted) {
      return PermissionResult.restricted;
    }

    // Request the permission
    final result = await permission.request();

    if (result.isGranted) {
      return PermissionResult.granted;
    }

    if (result.isLimited) {
      return PermissionResult.limited;
    }

    if (result.isPermanentlyDenied) {
      return PermissionResult.permanentlyDenied;
    }

    if (result.isRestricted) {
      return PermissionResult.restricted;
    }

    return PermissionResult.denied;
  }
}
