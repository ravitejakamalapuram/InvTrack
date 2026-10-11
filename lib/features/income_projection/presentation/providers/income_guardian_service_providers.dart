/// Income Guardian service providers for background monitoring and sync
library;

import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/error/app_exception.dart';
import 'package:inv_tracker/core/logging/logger_service.dart';
import 'package:inv_tracker/core/providers/feature_flags_provider.dart';
import 'package:inv_tracker/core/providers/shared_preferences_provider.dart';
import 'package:inv_tracker/features/auth/presentation/providers/auth_provider.dart';
import 'package:inv_tracker/core/notifications/handlers/income_guardian_notification_handler.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/income_projection/data/services/income_guardian_monitor_service.dart';
import 'package:inv_tracker/features/income_projection/data/services/income_guardian_sync_service.dart';
import 'package:inv_tracker/features/income_projection/data/services/orphaned_expected_cash_flow_cleanup_service.dart';
import 'package:inv_tracker/features/income_projection/presentation/providers/income_guardian_settings_provider.dart';

// ============ FLUTTER LOCAL NOTIFICATIONS PLUGIN ============

/// Provider for Flutter Local Notifications plugin
///
/// This must be overridden in main.dart with the actual plugin instance
final flutterLocalNotificationsPluginProvider = Provider<FlutterLocalNotificationsPlugin>((ref) {
  throw UnimplementedError('Override in main.dart');
});

// ============ INCOME GUARDIAN NOTIFICATION HANDLER ============

/// Provider for Income Guardian notification handler
final incomeGuardianNotificationHandlerProvider = Provider<IncomeGuardianNotificationHandler>((ref) {
  final plugin = ref.watch(flutterLocalNotificationsPluginProvider);
  final notificationService = ref.watch(notificationServiceProvider);

  return IncomeGuardianNotificationHandler(
    plugin: plugin,
    ensureInitialized: () => notificationService.initialize(),
    ensurePermissionsForShow: () async {
      await notificationService.initialize();
      return await notificationService.arePermissionsGranted();
    },
    // The handler passes the payment's ISO code: show its symbol and format
    // the amount in that currency's own locale ('₹2.5 L', '\$1.5K').
    formatCurrency: (amount, currencyCode, _) => formatCompactCurrency(
      amount,
      symbol: getCurrencySymbol(currencyCode),
      locale: getCurrencyLocale(currencyCode),
    ),
  );
});

// ============ INCOME GUARDIAN MONITOR SERVICE ============

/// Provider for Income Guardian monitor service
final incomeGuardianMonitorServiceProvider = Provider<IncomeGuardianMonitorService>((ref) {
  final expectedCashFlowRepository = ref.watch(expectedCashFlowRepositoryProvider);
  final investmentRepository = ref.watch(investmentRepositoryProvider);
  final notificationHandler = ref.watch(incomeGuardianNotificationHandlerProvider);
  final settings = ref.watch(incomeGuardianSettingsProvider);
  final locale = ref.watch(currencyLocaleProvider);

  return IncomeGuardianMonitorService(
    expectedCashFlowRepository: expectedCashFlowRepository,
    investmentRepository: investmentRepository,
    notificationHandler: notificationHandler,
    settings: settings,
    locale: locale,
  );
});

// ============ INCOME GUARDIAN SYNC SERVICE ============

/// Provider for Income Guardian sync service
final incomeGuardianSyncServiceProvider = Provider<IncomeGuardianSyncService>((ref) {
  final expectedCashFlowRepository = ref.watch(expectedCashFlowRepositoryProvider);
  final investmentRepository = ref.watch(investmentRepositoryProvider);
  final settings = ref.watch(incomeGuardianSettingsProvider);

  return IncomeGuardianSyncService(
    expectedCashFlowRepository: expectedCashFlowRepository,
    investmentRepository: investmentRepository,
    settings: settings,
  );
});

// ============ ORPHANED EXPECTED PAYMENT CLEANUP ============

/// Provider for the one-off removal of expected payments whose investment no
/// longer exists (#917).
/// Throws AuthException.notAuthenticated if user is not authenticated.
final orphanedExpectedCashFlowCleanupServiceProvider =
    Provider<OrphanedExpectedCashFlowCleanupService>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    throw AuthException.notAuthenticated();
  }
  return OrphanedExpectedCashFlowCleanupService(
    firestore: ref.watch(firestoreProvider),
    userId: user.id,
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

// ============ SERVICE INITIALIZATION ============

/// Provider to initialize Income Guardian services
/// 
/// This should be called once when the user is authenticated.
/// It starts both the monitor service (notifications) and sync service (auto-matching).
///
/// Nothing starts while [FeatureFlag.incomeGuardian] is off: the feature is
/// hidden, and the sync would otherwise query Firestore once per INCOME cash
/// flow on every launch. Turning the flag off stops running services.
///
/// Expected payments of investments that were deleted are removed first (#917;
/// once per user, and a failed attempt does not keep the services from
/// starting), so that nothing reminds the user of a payment for an investment
/// that no longer exists.
final incomeGuardianServiceInitializerProvider = Provider<void>((ref) {
  if (!ref.watch(isIncomeGuardianEnabledProvider)) return;

  // Get services
  final cleanup = ref.watch(orphanedExpectedCashFlowCleanupServiceProvider);
  final monitorService = ref.watch(incomeGuardianMonitorServiceProvider);
  final syncService = ref.watch(incomeGuardianSyncServiceProvider);

  var disposed = false;
  var started = false;

  // Cleanup on dispose
  ref.onDispose(() {
    disposed = true;
    if (!started) return;
    monitorService.stopMonitoring();
    syncService.stopSync();
  });

  unawaited(() async {
    try {
      await cleanup.runOnce();
      // The flag was turned off, or the user changed, while it ran.
      if (disposed || !ref.read(isIncomeGuardianEnabledProvider)) return;
      started = true;

      // Start monitoring for notifications
      monitorService.startMonitoring();

      // Start background sync for auto-matching
      syncService.startSync();
    } catch (e) {
      LoggerService.error(
        'Error starting Income Guardian services',
        error: e,
        metadata: {'service': 'IncomeGuardianServiceInitializer'},
      );
    }
  }());
});
