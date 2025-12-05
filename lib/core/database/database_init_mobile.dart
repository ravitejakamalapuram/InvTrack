import 'dart:io';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

/// Initialize SQLCipher for mobile platforms (Android/iOS)
/// Must be called BEFORE any database operations
Future<void> initializeMobileDatabase() async {
  if (Platform.isAndroid) {
    // Apply workaround for older Android versions first
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    // Override sqlite3 to use sqlcipher
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }
  // iOS uses SQLCipher automatically via the pod dependency
}

