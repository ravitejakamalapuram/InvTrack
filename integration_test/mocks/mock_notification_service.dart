import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:inv_tracker/features/investment/domain/entities/investment_entity.dart';

/// Fake implementation of NotificationService for integration tests.
class FakeNotificationService implements NotificationService {
  final List<String> _shownNotifications = [];
  final List<String> _scheduledNotifications = [];

  /// Access shown notifications for test assertions
  List<String> get shownNotifications => List.unmodifiable(_shownNotifications);

  /// Access scheduled notifications for test assertions
  List<String> get scheduledNotifications =>
      List.unmodifiable(_scheduledNotifications);

  /// Reset state between tests
  void reset() {
    _shownNotifications.clear();
    _scheduledNotifications.clear();
  }

  void _logShown(String notification) {
    _shownNotifications.add(notification);
  }

  void _logScheduled(String notification) {
    _scheduledNotifications.add(notification);
  }

  @override
  Future<void> initialize() async {
    // No-op for testing
  }

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> showTestNotification() async {
    _logShown('test_notification');
    return true;
  }

  @override
  Future<bool> scheduleTestNotification({int delaySeconds = 5}) async {
    _logScheduled('test_notification_delayed');
    return true;
  }

  @override
  Future<void> cancelAll() async {
    _shownNotifications.clear();
    _scheduledNotifications.clear();
  }

  @override
  Future<void> scheduleWeeklySummary() async {
    _logScheduled('weekly_summary');
  }

  @override
  Future<void> scheduleMonthlySummary() async {
    _logScheduled('monthly_summary');
  }

  @override
  Future<void> rescheduleAllNotifications(
    List<InvestmentEntity> investments,
  ) async {
    _logScheduled('reschedule_all');
  }

  @override
  Future<void> checkAndShowGoalMilestone({
    required String goalId,
    required String goalName,
    required double progressPercent,
    required double currentValue,
    required double targetValue,
    String currency = 'INR',
  }) async {
    if (progressPercent >= 25) {
      _logShown('goal_milestone_$goalId');
    }
  }

  // Preference getters - default values for testing
  @override
  bool get weeklySummaryEnabled => true;

  @override
  bool get monthlySummaryEnabled => true;

  @override
  bool get maturityRemindersEnabled => true;

  @override
  bool get incomeRemindersEnabled => true;

  @override
  bool get milestonesEnabled => true;

  @override
  bool get goalMilestonesEnabled => true;

  @override
  bool get taxRemindersEnabled => true;

  @override
  bool get riskAlertsEnabled => true;

  @override
  bool get weeklyCheckInEnabled => true;

  @override
  bool get idleAlertsEnabled => true;

  @override
  int get idleAlertDays => 90;

  @override
  bool get fySummaryEnabled => true;

  // Allow no-op for any methods not explicitly defined
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

