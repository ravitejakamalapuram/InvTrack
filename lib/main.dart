import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:sqlite3/open.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLCipher for Android
  // Must be done BEFORE any database operations
  if (Platform.isAndroid) {
    // Apply workaround for older Android versions first
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    // Override sqlite3 to use sqlcipher
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  }

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const InvTrackerApp(),
    ),
  );
}
