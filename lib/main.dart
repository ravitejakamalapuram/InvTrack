import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:inv_tracker/app/app.dart';
import 'package:inv_tracker/core/analytics/crashlytics_service.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/performance/performance_service.dart';
import 'package:inv_tracker/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inv_tracker/features/settings/presentation/providers/settings_provider.dart';

void main() async {
  runZonedGuarded(
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
          ],
          child: const InvTrackerApp(),
        ),
      );

      // Defer non-critical initialization to after first frame
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _initializeNonCriticalServices(notificationService);
      });
    },
    (error, stack) {
      // Catch any errors that escape the Flutter framework
      LoggerService.error(
        'Uncaught error in Flutter framework',
        error: error,
        stackTrace: stack,
        metadata: {'fatal': 'true'},
      );
    },
  );
}

/// Initialize non-critical services after the first frame is rendered.
/// This prevents blocking the UI during app startup.
Future<void> _initializeNonCriticalServices(
  NotificationService notificationService,
) async {
  try {
    // Initialize Crashlytics in background
    final crashlyticsService = CrashlyticsService();
    unawaited(crashlyticsService.initialize());

    // Initialize Performance Monitoring in background
    final performanceService = PerformanceService();
    unawaited(performanceService.initialize());

    // Initialize notifications in background
    await notificationService.initialize();

    // Schedule recurring notifications (tax reminders, weekly check-in, FY summary)
    // These are idempotent - safe to call on every app start
    unawaited(_scheduleRecurringNotifications(notificationService));
  } catch (e) {
    LoggerService.error(
      'Error initializing non-critical services',
      error: e,
      metadata: {'service': 'main'},
    );
  }
}

/// Schedule all recurring notifications.
/// Called on every app start - methods are idempotent.
Future<void> _scheduleRecurringNotifications(
  NotificationService notificationService,
) async {
  try {
    // Schedule tax deadline reminders (India-specific)
    await notificationService.scheduleTaxReminders();

    // Schedule weekly Sunday check-in prompt
    await notificationService.scheduleWeeklyCheckIn();

    // Schedule FY summary for April 1st
    await notificationService.scheduleFYSummary();

    LoggerService.info('Recurring notifications scheduled');
  } catch (e) {
    LoggerService.error(
      'Error scheduling recurring notifications',
      error: e,
      metadata: {'service': 'NotificationService'},
    );
  }
}
