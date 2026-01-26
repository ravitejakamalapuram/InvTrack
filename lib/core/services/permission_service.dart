/// Permission handling service for camera, photos, and storage access.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// Request camera permission
  Future<PermissionResult> requestCamera() async {
    return _requestPermission(Permission.camera);
  }

  /// Request photo library permission
  /// On Android 13+, this uses READ_MEDIA_IMAGES
  /// On older Android, uses READ_EXTERNAL_STORAGE
  Future<PermissionResult> requestPhotos() async {
    if (Platform.isAndroid) {
      // Android 13+ uses granular media permissions
      return _requestPermission(Permission.photos);
    } else {
      // iOS uses photos permission
      return _requestPermission(Permission.photos);
    }
  }

  /// Request storage permission for file picker (PDFs, etc.)
  /// On Android 13+, storage permission is deprecated
  Future<PermissionResult> requestStorage() async {
    if (Platform.isAndroid) {
      // For file picker on Android, we don't need explicit permission
      // FilePicker uses SAF (Storage Access Framework) which handles its own permissions
      return PermissionResult.granted;
    }
    // iOS doesn't need storage permission for document picker
    return PermissionResult.granted;
  }

  /// Check if camera permission is granted
  Future<bool> isCameraGranted() async {
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Check if photos permission is granted
  Future<bool> isPhotosGranted() async {
    final status = await Permission.photos.status;
    return status.isGranted || status.isLimited;
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

  /// Log permission status for debugging
  void logPermissionStatus(String name, PermissionResult result) {
    if (kDebugMode) {
      debugPrint('🔐 Permission [$name]: $result');
    }
  }
}
