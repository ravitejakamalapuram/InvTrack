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
/// Returns null in test mode when FakeAnalyticsService is used
final analyticsObserverProvider = Provider<FirebaseAnalyticsObserver?>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  return analytics.getObserver();
});

/// Analytics event names - centralized for consistency
/// Kept minimal to reduce noise - only core business events
class AnalyticsEvents {
  // Core conversion events
  static const String investmentCreated = 'investment_created';
  static const String cashFlowAdded = 'cashflow_added';

  // Investment lifecycle
  static const String investmentClosed = 'investment_closed';
  static const String investmentReopened = 'investment_reopened';
  static const String investmentArchived = 'investment_archived';
  static const String investmentUnarchived = 'investment_unarchived';
  static const String investmentDeleted = 'investment_deleted';

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

  // Security & Settings
  static const String securityEnabled = 'security_enabled';
  static const String securityDisabled = 'security_disabled';
  static const String themeChanged = 'theme_changed';

  // Error tracking
  static const String errorOccurred = 'error_occurred';

  // Template & Quick-Add events
  static const String templateSelected = 'template_selected';

  // Sample Data Mode events
  static const String sampleDataActivated = 'sample_data_activated';
  static const String sampleDataKept = 'sample_data_kept';
  static const String sampleDataCleared = 'sample_data_cleared';

  // Empty State Interaction events
  static const String emptyStateActionTapped = 'empty_state_action_tapped';

  // Projection & Smart Defaults events
  static const String projectionViewed = 'projection_viewed';
  static const String smartDefaultApplied = 'smart_default_applied';

  // Enhanced Fields usage
  static const String enhancedFieldsUsed = 'enhanced_fields_used';
}

/// Analytics service that wraps Firebase Analytics
class AnalyticsService {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Get the analytics observer for navigation tracking
  /// Returns null for fake implementations
  FirebaseAnalyticsObserver? getObserver() {
    return FirebaseAnalyticsObserver(analytics: _analytics);
  }

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

  // ============ Investment Lifecycle Events ============

  /// Log investment closed
  Future<void> logInvestmentClosed({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentClosed,
      parameters: {'investment_type': investmentType},
    );
  }

  /// Log investment reopened
  Future<void> logInvestmentReopened({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentReopened,
      parameters: {'investment_type': investmentType},
    );
  }

  /// Log investment archived
  Future<void> logInvestmentArchived({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentArchived,
      parameters: {'investment_type': investmentType},
    );
  }

  /// Log investment unarchived
  Future<void> logInvestmentUnarchived({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentUnarchived,
      parameters: {'investment_type': investmentType},
    );
  }

  /// Log investment deleted
  Future<void> logInvestmentDeleted({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentDeleted,
      parameters: {'investment_type': investmentType},
    );
  }

  // ============ Security & Settings Events ============

  /// Log security feature enabled (biometric or passcode)
  Future<void> logSecurityEnabled({required String method}) async {
    await logEvent(
      name: AnalyticsEvents.securityEnabled,
      parameters: {'method': method},
    );
  }

  /// Log security feature disabled
  Future<void> logSecurityDisabled() async {
    await logEvent(name: AnalyticsEvents.securityDisabled);
  }

  /// Log theme changed
  Future<void> logThemeChanged({required String theme}) async {
    await logEvent(
      name: AnalyticsEvents.themeChanged,
      parameters: {'theme': theme},
    );
  }

  // ============ Template & Quick-Add Events ============

  /// Log template selected from template selector
  Future<void> logTemplateSelected({
    required String templateId,
    required String templateName,
  }) async {
    await logEvent(
      name: AnalyticsEvents.templateSelected,
      parameters: {
        'template_id': templateId,
        'template_name': templateName,
      },
    );
  }

  // ============ Sample Data Mode Events ============

  /// Log sample data mode activated
  Future<void> logSampleDataActivated({
    required int investmentCount,
    required int goalCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.sampleDataActivated,
      parameters: {
        'investments': investmentCount,
        'goals': goalCount,
      },
    );
  }

  /// Log sample data kept (user decides to keep sample data as real)
  Future<void> logSampleDataKept({
    required int investmentCount,
    required int goalCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.sampleDataKept,
      parameters: {
        'investments': investmentCount,
        'goals': goalCount,
      },
    );
  }

  /// Log sample data cleared
  Future<void> logSampleDataCleared({
    required int investmentCount,
    required int goalCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.sampleDataCleared,
      parameters: {
        'investments': investmentCount,
        'goals': goalCount,
      },
    );
  }

  // ============ Empty State Events ============

  /// Log empty state action tapped
  Future<void> logEmptyStateActionTapped({required String action}) async {
    await logEvent(
      name: AnalyticsEvents.emptyStateActionTapped,
      parameters: {'action': action},
    );
  }

  // ============ Projection & Smart Defaults Events ============

  /// Log projection card viewed
  Future<void> logProjectionViewed({
    required String investmentType,
    required double expectedRate,
    required int tenureMonths,
    String? compounding,
  }) async {
    await logEvent(
      name: AnalyticsEvents.projectionViewed,
      parameters: {
        'investment_type': investmentType,
        'expected_rate_range': _getRateRange(expectedRate),
        'tenure_months': tenureMonths,
        if (compounding != null) 'compounding': compounding,
      },
    );
  }

  /// Log smart default applied (e.g., auto-calculated maturity date)
  Future<void> logSmartDefaultApplied({required String fieldName}) async {
    await logEvent(
      name: AnalyticsEvents.smartDefaultApplied,
      parameters: {'field': fieldName},
    );
  }

  // ============ Enhanced Fields Events ============

  /// Log enhanced fields used when creating investment
  Future<void> logEnhancedFieldsUsed({
    required String investmentType,
    required List<String> fieldsUsed,
  }) async {
    await logEvent(
      name: AnalyticsEvents.enhancedFieldsUsed,
      parameters: {
        'investment_type': investmentType,
        'fields_count': fieldsUsed.length,
        'fields': fieldsUsed.take(10).join(','), // Limit to 10 for param size
      },
    );
  }

  // ============ Helper Methods ============

  /// Get rate range bucket for analytics (avoid logging exact rates)
  String _getRateRange(double rate) {
    if (rate < 5) return 'under_5';
    if (rate < 8) return '5_to_8';
    if (rate < 12) return '8_to_12';
    if (rate < 15) return '12_to_15';
    return 'over_15';
  }
}
