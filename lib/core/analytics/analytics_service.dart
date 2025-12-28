/// Analytics service for tracking user events and screen views.
///
/// This abstraction layer wraps Firebase Analytics and provides
/// a clean interface for the rest of the app.
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for the analytics service
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  return AnalyticsService();
});

/// Provider for the Firebase Analytics observer (for GoRouter)
final analyticsObserverProvider = Provider<FirebaseAnalyticsObserver>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  return FirebaseAnalyticsObserver(analytics: analytics._analytics);
});

/// Analytics event names - centralized for consistency
/// Kept minimal to reduce noise - only core business events
class AnalyticsEvents {
  // Core conversion events
  static const String investmentCreated = 'investment_created';
  static const String cashFlowAdded = 'cashflow_added';

  // Feature adoption
  static const String csvImportCompleted = 'csv_import_completed';
  static const String exportGenerated = 'export_generated';

  // Goals feature
  static const String goalCreated = 'goal_created';
  static const String goalUpdated = 'goal_updated';
  static const String goalArchived = 'goal_archived';
  static const String goalDeleted = 'goal_deleted';
  static const String goalMilestoneReached = 'goal_milestone_reached';

  // Documents feature
  static const String documentAdded = 'document_added';

  // Error tracking
  static const String errorOccurred = 'error_occurred';
}

/// Analytics service that wraps Firebase Analytics
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log a custom event
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
      if (kDebugMode) {
        debugPrint('📊 Analytics: $name ${parameters ?? ''}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Analytics error: $e');
      }
    }
  }

  /// Log screen view
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    try {
      await _analytics.logScreenView(
        screenName: screenName,
        screenClass: screenClass,
      );
      if (kDebugMode) {
        debugPrint('📊 Screen: $screenName');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Analytics error: $e');
      }
    }
  }

  /// Set user ID for analytics
  Future<void> setUserId(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Analytics error setting user ID: $e');
      }
    }
  }

  /// Set user property
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Analytics error setting user property: $e');
      }
    }
  }

  // ============ Convenience methods for common events ============

  /// Log sign in event
  Future<void> logSignIn({required String method}) async {
    await _analytics.logLogin(loginMethod: method);
  }

  /// Log sign up event
  Future<void> logSignUp({required String method}) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  /// Log investment created
  Future<void> logInvestmentCreated({
    required String investmentType,
    bool hasNotes = false,
  }) async {
    await logEvent(
      name: AnalyticsEvents.investmentCreated,
      parameters: {'investment_type': investmentType, 'has_notes': hasNotes},
    );
  }

  /// Log cash flow added
  Future<void> logCashFlowAdded({
    required String flowType,
    required String amountRange,
  }) async {
    await logEvent(
      name: AnalyticsEvents.cashFlowAdded,
      parameters: {'flow_type': flowType, 'amount_range': amountRange},
    );
  }

  /// Log CSV import completed
  Future<void> logCsvImportCompleted({
    required int rowCount,
    required int successCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.csvImportCompleted,
      parameters: {'row_count': rowCount, 'success_count': successCount},
    );
  }

  /// Log export generated
  Future<void> logExportGenerated({required String format}) async {
    await logEvent(
      name: AnalyticsEvents.exportGenerated,
      parameters: {'format': format},
    );
  }

  /// Log error occurred
  Future<void> logErrorOccurred({
    required String errorType,
    String? screen,
  }) async {
    await logEvent(
      name: AnalyticsEvents.errorOccurred,
      parameters: {
        'error_type': errorType,
        if (screen != null) 'screen': screen,
      },
    );
  }

  /// Log goal created
  Future<void> logGoalCreated({
    required String goalType,
    required String trackingMode,
    bool hasDeadline = false,
  }) async {
    await logEvent(
      name: AnalyticsEvents.goalCreated,
      parameters: {
        'goal_type': goalType,
        'tracking_mode': trackingMode,
        'has_deadline': hasDeadline
            ? 1
            : 0, // Firebase Analytics only accepts String or num
      },
    );
  }

  /// Log goal updated
  Future<void> logGoalUpdated({required String goalId}) async {
    await logEvent(
      name: AnalyticsEvents.goalUpdated,
      parameters: {'goal_id': goalId},
    );
  }

  /// Log goal archived
  Future<void> logGoalArchived({required String goalId}) async {
    await logEvent(
      name: AnalyticsEvents.goalArchived,
      parameters: {'goal_id': goalId},
    );
  }

  /// Log goal deleted
  Future<void> logGoalDeleted({required String goalId}) async {
    await logEvent(
      name: AnalyticsEvents.goalDeleted,
      parameters: {'goal_id': goalId},
    );
  }

  /// Log goal milestone reached
  Future<void> logGoalMilestoneReached({
    required String goalId,
    required int milestone,
  }) async {
    await logEvent(
      name: AnalyticsEvents.goalMilestoneReached,
      parameters: {'goal_id': goalId, 'milestone': milestone},
    );
  }

  /// Track document added
  void trackDocumentAdded({
    required String documentType,
    required String fileType,
  }) {
    logEvent(
      name: AnalyticsEvents.documentAdded,
      parameters: {'document_type': documentType, 'file_type': fileType},
    );
  }
}
