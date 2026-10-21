import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:inv_tracker/features/auth/data/services/sign_out_cleanup_service.dart';
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/analytics/consent_service.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/analytics/run_guarded.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/core/security/app_check_service.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_service_providers.dart';
import 'package:inv_tracker/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';

void main() async {
  runGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize date formatting for intl package (required before using DateFormat)
      await initializeDateFormatting();

      // Critical path: Firebase must be initialized before runApp
      // Run in parallel with SharedPreferences for faster startup
      final results = await Future.wait([
        Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform),
        SharedPreferences.getInstance(),
      ]);

      final sharedPreferences = results[1] as SharedPreferences;

      // Apply the user's analytics and crash-reporting choices (A34) before
      // anything can report.
      await ConsentService(sharedPreferences).applyAtStartup();

      // Monitor mode only (#774); must follow Firebase.initializeApp.
      await AppCheckService.initialize();

      // A sign-out queued a wipe of the offline cache; it must run before
      // Firestore is first used.
      await SignOutCleanupService.clearPendingCache(
        firestore: FirebaseFirestore.instance,
        prefs: sharedPreferences,
        // currentUser can be null until Auth has restored the session.
        currentUserId: () => FirebaseAuth.instance
            .authStateChanges()
            .first
            .then((user) => user?.uid)
            .timeout(const Duration(seconds: 5)),
      );

      // Create notification service (don't initialize yet - defer to post-frame)
      final notificationPlugin = FlutterLocalNotificationsPlugin();
      final notificationService = NotificationService(
        notificationPlugin,
        sharedPreferences,
      );

      // Launch UI immediately - don't block on non-critical initialization
      runApp(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            notificationServiceProvider.overrideWithValue(notificationService),
            flutterLocalNotificationsPluginProvider.overrideWithValue(notificationPlugin),
          ],
          child: const InvTrackerApp(),
        ),
      );

      // Defer non-critical initialization to after first frame
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _initializeNonCriticalServices(notificationService, sharedPreferences);
      });
    },
    service: CrashlyticsService(
      debugModeEnabled: CrashlyticsService.enableInDebugMode,
    ),
  );
}

/// Initialize non-critical services after the first frame is rendered.
/// This prevents blocking the UI during app startup.
///
/// Note: This function doesn't have access to ProviderContainer, so it creates
/// a standalone CrashlyticsService. The debug mode state is passed from the
/// already-resolved SharedPreferences instance.
Future<void> _initializeNonCriticalServices(
  NotificationService notificationService,
  SharedPreferences prefs,
) async {
  try {
    // Initialize Crashlytics in background
    // Note: We create a standalone instance here since we don't have access to
    // the ProviderContainer. Use the passed SharedPreferences instance.
    final debugModeEnabled =
        prefs.getBool(CrashlyticsDebugModeNotifier.prefKey) ?? false;

    // Set static field for backward compatibility with direct instantiation
    CrashlyticsService.enableInDebugMode = debugModeEnabled;

    final crashlyticsService = CrashlyticsService(
      debugModeEnabled: debugModeEnabled,
      collectionConsent: crashReportingConsentFrom(prefs),
    );
    unawaited(
      crashlyticsService.initialize().catchError((error, stack) {
        // Log Crashlytics initialization failure
        LoggerService.error(
          'Failed to initialize CrashlyticsService',
          error: error,
          stackTrace: stack,
          metadata: {
            'service': 'CrashlyticsService',
            'debugModeEnabled': debugModeEnabled.toString(),
          },
        );
      }),
    );

    // Initialize Performance Monitoring in background
    final performanceService = PerformanceService();
    unawaited(performanceService.initialize());

    // Initialize notifications in background
    await notificationService.initialize();
  } catch (e) {
    LoggerService.error(
      'Error initializing non-critical services',
      error: e,
      metadata: {'service': 'main'},
    );
  }
}
