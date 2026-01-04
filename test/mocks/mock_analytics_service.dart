import 'package:flutter/foundation.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';
import 'package:mocktail/mocktail.dart';

/// Mock implementation of AnalyticsService for testing.
/// This avoids Firebase initialization issues in unit tests.
class MockAnalyticsService extends Mock implements AnalyticsService {}

/// Fake implementation of AnalyticsService for testing.
/// Records all events for verification without Firebase.
class FakeAnalyticsService implements AnalyticsService {
  final List<({String name, Map<String, Object>? parameters})> loggedEvents =
      [];
  final List<String> screenViews = [];
  String? currentUserId;
  final Map<String, String?> userProperties = {};

  void reset() {
    loggedEvents.clear();
    screenViews.clear();
    currentUserId = null;
    userProperties.clear();
  }

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    loggedEvents.add((name: name, parameters: parameters));
    if (kDebugMode) {
      debugPrint('📊 FakeAnalytics: $name ${parameters ?? ''}');
    }
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async {
    screenViews.add(screenName);
  }

  @override
  Future<void> setUserId(String? userId) async {
    currentUserId = userId;
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    userProperties[name] = value;
  }

  @override
  Future<void> logSignIn({required String method}) async {
    await logEvent(name: 'login', parameters: {'method': method});
  }

  @override
  Future<void> logSignUp({required String method}) async {
    await logEvent(name: 'sign_up', parameters: {'method': method});
  }

  @override
  Future<void> logInvestmentCreated({
    required String investmentType,
    bool hasNotes = false,
  }) async {
    await logEvent(
      name: AnalyticsEvents.investmentCreated,
      parameters: {'investment_type': investmentType, 'has_notes': hasNotes},
    );
  }

  @override
  Future<void> logCashFlowAdded({
    required String flowType,
    required String amountRange,
  }) async {
    await logEvent(
      name: AnalyticsEvents.cashFlowAdded,
      parameters: {'flow_type': flowType, 'amount_range': amountRange},
    );
  }

  @override
  Future<void> logCsvImportCompleted({
    required int rowCount,
    required int successCount,
  }) async {
    await logEvent(
      name: AnalyticsEvents.csvImportCompleted,
      parameters: {'row_count': rowCount, 'success_count': successCount},
    );
  }

  @override
  Future<void> logExportGenerated({required String format}) async {
    await logEvent(
      name: AnalyticsEvents.exportGenerated,
      parameters: {'format': format},
    );
  }

  @override
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

  @override
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
        'has_deadline': hasDeadline ? 1 : 0,
      },
    );
  }

  @override
  Future<void> logGoalUpdated({required String goalId}) async {
    await logEvent(
      name: AnalyticsEvents.goalUpdated,
      parameters: {'goal_id': goalId},
    );
  }

  @override
  Future<void> logGoalArchived({required String goalId}) async {
    await logEvent(
      name: AnalyticsEvents.goalArchived,
      parameters: {'goal_id': goalId},
    );
  }

  @override
  Future<void> logGoalDeleted({required String goalId}) async {
    await logEvent(
      name: AnalyticsEvents.goalDeleted,
      parameters: {'goal_id': goalId},
    );
  }

  @override
  Future<void> logGoalMilestoneReached({
    required String goalId,
    required int milestone,
  }) async {
    await logEvent(
      name: AnalyticsEvents.goalMilestoneReached,
      parameters: {'goal_id': goalId, 'milestone': milestone},
    );
  }

  @override
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

  @override
  Future<void> logInvestmentClosed({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentClosed,
      parameters: {'investment_type': investmentType},
    );
  }

  @override
  Future<void> logInvestmentReopened({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentReopened,
      parameters: {'investment_type': investmentType},
    );
  }

  @override
  Future<void> logInvestmentArchived({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentArchived,
      parameters: {'investment_type': investmentType},
    );
  }

  @override
  Future<void> logInvestmentUnarchived({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentUnarchived,
      parameters: {'investment_type': investmentType},
    );
  }

  @override
  Future<void> logInvestmentDeleted({required String investmentType}) async {
    await logEvent(
      name: AnalyticsEvents.investmentDeleted,
      parameters: {'investment_type': investmentType},
    );
  }

  // ============ Security & Settings Events ============

  @override
  Future<void> logSecurityEnabled({required String method}) async {
    await logEvent(
      name: AnalyticsEvents.securityEnabled,
      parameters: {'method': method},
    );
  }

  @override
  Future<void> logSecurityDisabled() async {
    await logEvent(name: AnalyticsEvents.securityDisabled);
  }

  @override
  Future<void> logThemeChanged({required String theme}) async {
    await logEvent(
      name: AnalyticsEvents.themeChanged,
      parameters: {'theme': theme},
    );
  }
}
