import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

void main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize Crashlytics
    final crashlyticsService = CrashlyticsService();
    await crashlyticsService.initialize();

    final sharedPreferences = await SharedPreferences.getInstance();

    runApp(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const InvTrackerApp(),
      ),
    );
  }, (error, stack) {
    // Catch any errors that escape the Flutter framework
    if (kDebugMode) {
      debugPrint('🔴 Uncaught error: $error');
      debugPrint('Stack trace: $stack');
    } else {
      // In release mode, send to Crashlytics
      CrashlyticsService().recordError(error, stack, fatal: true);
    }
  });
}
