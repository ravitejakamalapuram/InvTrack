import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/app/app.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/core/database/database_init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize platform-specific database (SQLCipher for mobile, in-memory for web)
  if (!kIsWeb) {
    await initializeMobileDatabase();
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
