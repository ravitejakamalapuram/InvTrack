/// Income Guardian service providers for background monitoring and sync
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inv_tracker/core/di/database_module.dart';
import 'package:inv_tracker/core/notifications/handlers/income_guardian_notification_handler.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/core/utils/currency_utils.dart';
import 'package:inv_tracker/features/income_projection/data/services/income_guardian_monitor_service.dart';
import 'package:inv_tracker/features/income_projection/data/services/income_guardian_sync_service.dart';

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
    // Wrap formatCompactCurrency to match expected signature
    formatCurrency: (amount, symbol, locale) => formatCompactCurrency(
      amount,
      symbol: symbol,
      locale: locale,
    ),
  );
});

// ============ INCOME GUARDIAN MONITOR SERVICE ============

/// Provider for Income Guardian monitor service
final incomeGuardianMonitorServiceProvider = Provider<IncomeGuardianMonitorService>((ref) {
  final expectedCashFlowRepository = ref.watch(expectedCashFlowRepositoryProvider);
  final investmentRepository = ref.watch(investmentRepositoryProvider);
  final notificationHandler = ref.watch(incomeGuardianNotificationHandlerProvider);
  final locale = ref.watch(currencyLocaleProvider);

  return IncomeGuardianMonitorService(
    expectedCashFlowRepository: expectedCashFlowRepository,
    investmentRepository: investmentRepository,
    notificationHandler: notificationHandler,
    locale: locale,
  );
});

// ============ INCOME GUARDIAN SYNC SERVICE ============

/// Provider for Income Guardian sync service
final incomeGuardianSyncServiceProvider = Provider<IncomeGuardianSyncService>((ref) {
  final expectedCashFlowRepository = ref.watch(expectedCashFlowRepositoryProvider);
  final investmentRepository = ref.watch(investmentRepositoryProvider);

  return IncomeGuardianSyncService(
    expectedCashFlowRepository: expectedCashFlowRepository,
    investmentRepository: investmentRepository,
  );
});

// ============ SERVICE INITIALIZATION ============

/// Provider to initialize Income Guardian services
/// 
/// This should be called once when the user is authenticated.
/// It starts both the monitor service (notifications) and sync service (auto-matching).
final incomeGuardianServiceInitializerProvider = Provider<void>((ref) {
  // Get services
  final monitorService = ref.watch(incomeGuardianMonitorServiceProvider);
  final syncService = ref.watch(incomeGuardianSyncServiceProvider);

  // Start monitoring for notifications
  monitorService.startMonitoring();

  // Start background sync for auto-matching
  syncService.startSync();

  // Cleanup on dispose
  ref.onDispose(() {
    monitorService.stopMonitoring();
    syncService.stopSync();
  });
});
