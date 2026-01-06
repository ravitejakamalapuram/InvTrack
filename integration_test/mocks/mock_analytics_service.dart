import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:inv_tracker/core/analytics/analytics_service.dart';

/// Fake implementation of AnalyticsService for integration tests.
class FakeAnalyticsService implements AnalyticsService {
  final List<String> _loggedEvents = [];

  /// Access logged events for test assertions
  List<String> get loggedEvents => List.unmodifiable(_loggedEvents);

  /// Reset state between tests
  void reset() {
    _loggedEvents.clear();
  }

  void _log(String event, [Map<String, dynamic>? params]) {
    _loggedEvents.add(event);
  }

  /// Return null for observer in tests - we don't need navigation tracking
  @override
  FirebaseAnalyticsObserver? getObserver() => null;

  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async =>
      _log(name, parameters?.cast<String, dynamic>());

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
  }) async =>
      _log('screen_view', {'screen_name': screenName});

  @override
  Future<void> setUserId(String? userId) async {}

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {}

  @override
  Future<void> logSignIn({required String method}) async =>
      _log('sign_in', {'method': method});

  @override
  Future<void> logSignUp({required String method}) async =>
      _log('sign_up', {'method': method});

  @override
  Future<void> logInvestmentCreated({
    required String investmentType,
    bool hasNotes = false,
  }) async =>
      _log('investment_created', {'type': investmentType, 'has_notes': hasNotes});

  @override
  Future<void> logCashFlowAdded({
    required String flowType,
    required String amountRange,
  }) async =>
      _log('cash_flow_added', {'type': flowType, 'range': amountRange});

  @override
  Future<void> logCsvImportCompleted({
    required int rowCount,
    required int successCount,
  }) async =>
      _log('csv_import_completed', {'row_count': rowCount, 'success_count': successCount});

  @override
  Future<void> logExportGenerated({required String format}) async =>
      _log('export_generated', {'format': format});

  @override
  Future<void> logErrorOccurred({
    required String errorType,
    String? screen,
  }) async =>
      _log('error_occurred', {'error_type': errorType, 'screen': screen});

  @override
  Future<void> logGoalCreated({
    required String goalType,
    required String trackingMode,
    bool hasDeadline = false,
  }) async =>
      _log('goal_created', {'type': goalType, 'tracking_mode': trackingMode});

  @override
  Future<void> logGoalUpdated({required String goalId}) async =>
      _log('goal_updated', {'goal_id': goalId});

  @override
  Future<void> logGoalArchived({required String goalId}) async =>
      _log('goal_archived', {'goal_id': goalId});

  @override
  Future<void> logGoalDeleted({required String goalId}) async =>
      _log('goal_deleted', {'goal_id': goalId});

  @override
  Future<void> logGoalMilestoneReached({
    required String goalId,
    required int milestone,
  }) async =>
      _log('goal_milestone_reached', {'goal_id': goalId, 'milestone': milestone});

  @override
  void trackDocumentAdded({
    required String documentType,
    required String fileType,
  }) {
    _log('document_added', {'document_type': documentType, 'file_type': fileType});
  }

  // ============ Investment Lifecycle Events ============

  @override
  Future<void> logInvestmentClosed({required String investmentType}) async =>
      _log('investment_closed', {'investment_type': investmentType});

  @override
  Future<void> logInvestmentReopened({required String investmentType}) async =>
      _log('investment_reopened', {'investment_type': investmentType});

  @override
  Future<void> logInvestmentArchived({required String investmentType}) async =>
      _log('investment_archived', {'investment_type': investmentType});

  @override
  Future<void> logInvestmentUnarchived({required String investmentType}) async =>
      _log('investment_unarchived', {'investment_type': investmentType});

  @override
  Future<void> logInvestmentDeleted({required String investmentType}) async =>
      _log('investment_deleted', {'investment_type': investmentType});

  // ============ Security & Settings Events ============

  @override
  Future<void> logSecurityEnabled({required String method}) async =>
      _log('security_enabled', {'method': method});

  @override
  Future<void> logSecurityDisabled() async => _log('security_disabled');

  @override
  Future<void> logThemeChanged({required String theme}) async =>
      _log('theme_changed', {'theme': theme});
}

