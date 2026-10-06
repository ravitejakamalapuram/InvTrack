import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:inv_tracker/core/notifications/notification_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/timezone.dart' as tz;

/// Mock implementation of FlutterLocalNotificationsPlugin for testing.
class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

/// Fake implementation of NotificationService for testing.
/// This is a no-op implementation that can be used to override [notificationServiceProvider].
class FakeNotificationService implements NotificationService {
  final List<String> scheduledIncomeReminders = [];
  final List<String> scheduledMaturityReminders = [];
  final List<String> cancelledIncomeReminders = [];
  final List<String> cancelledMaturityReminders = [];
  final List<String> shownMilestones = [];
  final List<String> shownGoalMilestones = [];
  final List<String> shownGoalAtRiskNotifications = [];
  final List<String> shownGoalStaleNotifications = [];

  void reset() {
    scheduledIncomeReminders.clear();
    scheduledMaturityReminders.clear();
    cancelledIncomeReminders.clear();
    cancelledMaturityReminders.clear();
    shownMilestones.clear();
    shownGoalMilestones.clear();
    shownGoalAtRiskNotifications.clear();
    shownGoalStaleNotifications.clear();
  }

  @override
  Future<void> scheduleIncomeReminder({
    required String investmentId,
    required String investmentName,
    required int monthsBetweenPayments,
    DateTime? lastIncomeDate,
  }) async {
    scheduledIncomeReminders.add(investmentId);
  }

  @override
  Future<void> cancelIncomeReminder(String investmentId) async {
    cancelledIncomeReminders.add(investmentId);
  }

  @override
  Future<void> scheduleMaturityReminders({
    required String investmentId,
    required String investmentName,
    required DateTime maturityDate,
    String? investmentType,
    double? investedAmount,
    double? currentValue,
    String currency = 'INR',
  }) async {
    scheduledMaturityReminders.add(investmentId);
  }

  @override
  Future<void> cancelMaturityReminders(String investmentId) async {
    cancelledMaturityReminders.add(investmentId);
  }

  @override
  Future<void> checkAndShowMilestone({
    required String investmentId,
    required String investmentName,
    required double totalInvested,
    required double totalReturned,
    String currency = 'INR',
  }) async {
    shownMilestones.add(investmentId);
  }

  @override
  Future<void> checkAndShowGoalMilestone({
    required String goalId,
    required String goalName,
    required double progressPercent,
    required double currentValue,
    required double targetValue,
    String currency = 'INR',
    bool announce = true,
  }) async {
    // A silent check records the milestone but shows nothing.
    if (announce) shownGoalMilestones.add(goalId);
  }

  @override
  Future<void> showGoalAtRiskNotification({
    required String goalId,
    required String goalName,
    required double progressPercent,
    required DateTime? targetDate,
    required DateTime? projectedDate,
  }) async {
    shownGoalAtRiskNotifications.add(goalId);
  }

  @override
  Future<void> showGoalStaleNotification({
    required String goalId,
    required String goalName,
    required DateTime? lastActivityDate,
  }) async {
    shownGoalStaleNotifications.add(goalId);
  }

  // Implement preference getters
  @override
  DateTime? get userSignupDate => null;

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

  @override
  bool get goalAtRiskEnabled => true;

  @override
  bool get goalStaleEnabled => true;

  @override
  int get goalStaleDays => 60;

  @override
  String? get remindersOwnerUid => null;

  @override
  Future<void> setRemindersOwnerUid(String? uid) async {}

  // Implement all other required methods with no-op stubs
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // For Future-returning methods, return completed future
    return Future<void>.value();
  }
}

/// Fake implementation of FlutterLocalNotificationsPlugin for testing.
/// Records all notifications for verification without actually showing them.
class FakeFlutterLocalNotificationsPlugin
    implements FlutterLocalNotificationsPlugin {
  final List<FakeNotification> shownNotifications = [];
  final List<FakeScheduledNotification> scheduledNotifications = [];
  final List<int> cancelledNotificationIds = [];
  bool _isInitialized = false;
  bool _allCancelled = false;
  bool permissionsGranted = true;

  /// When set, [zonedSchedule] rejects a one-off date that is not in the
  /// future, as the real plugin does ("Must be a date in the future").
  DateTime Function()? now;

  /// Ids whose [zonedSchedule] call throws, to simulate a platform failure.
  final Set<int> failingScheduleIds = {};

  /// When set, [zonedSchedule] waits for it before recording, so a test can
  /// act while a reschedule is in flight.
  Completer<void>? holdSchedules;

  void reset() {
    shownNotifications.clear();
    scheduledNotifications.clear();
    cancelledNotificationIds.clear();
    _isInitialized = false;
    _allCancelled = false;
    permissionsGranted = true;
  }

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    void Function(NotificationResponse)? onDidReceiveNotificationResponse,
    void Function(NotificationResponse)?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    _isInitialized = true;
    if (kDebugMode) {
      debugPrint('🔔 FakeNotificationPlugin: initialized');
    }
    return true;
  }

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    shownNotifications.add(
      FakeNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: notificationDetails,
      ),
    );
    if (kDebugMode) {
      debugPrint('🔔 FakeNotificationPlugin: show($id, $title, $body)');
    }
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    String? title,
    String? body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    final hold = holdSchedules;
    if (hold != null) await hold.future;
    final clock = now;
    if (clock != null &&
        matchDateTimeComponents == null &&
        scheduledDate.isBefore(clock())) {
      throw ArgumentError.value(
        scheduledDate,
        'scheduledDate',
        'Must be a date in the future',
      );
    }
    if (failingScheduleIds.contains(id)) {
      throw StateError('zonedSchedule failed for $id');
    }
    // As on Android, scheduling an id that is already pending replaces it.
    scheduledNotifications.removeWhere((n) => n.id == id);
    scheduledNotifications.add(
      FakeScheduledNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        payload: payload,
        matchDateTimeComponents: matchDateTimeComponents,
      ),
    );
    if (kDebugMode) {
      debugPrint(
        '🔔 FakeNotificationPlugin: zonedSchedule($id, $title, $scheduledDate)',
      );
    }
  }

  @override
  Future<void> cancel({required int id, String? tag}) async {
    cancelledNotificationIds.add(id);
    scheduledNotifications.removeWhere((n) => n.id == id);
    // As on Android, cancel also removes a notification already presented
    // with this id from the notification shade.
    shownNotifications.removeWhere((n) => n.id == id);
    if (kDebugMode) {
      debugPrint('🔔 FakeNotificationPlugin: cancel($id)');
    }
  }

  @override
  Future<void> cancelAll() async {
    _allCancelled = true;
    scheduledNotifications.clear();
    shownNotifications.clear();
    if (kDebugMode) {
      debugPrint('🔔 FakeNotificationPlugin: cancelAll()');
    }
  }

  bool get allCancelled => _allCancelled;
  bool get isInitialized => _isInitialized;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async {
    return scheduledNotifications
        .map(
          (n) => PendingNotificationRequest(n.id, n.title, n.body, n.payload),
        )
        .toList();
  }

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async {
    return [];
  }

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() {
    // Return a fake Android implementation for permission checking
    if (T == AndroidFlutterLocalNotificationsPlugin) {
      return FakeAndroidFlutterLocalNotificationsPlugin(this) as T;
    }
    return null;
  }

  // Add remaining required methods with no-op implementations
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Represents a notification that was shown immediately
class FakeNotification {
  final int id;
  final String? title;
  final String? body;
  final String? payload;
  final NotificationDetails? notificationDetails;

  FakeNotification({
    required this.id,
    this.title,
    this.body,
    this.payload,
    this.notificationDetails,
  });
}

/// Represents a notification that was scheduled for later
class FakeScheduledNotification {
  final int id;
  final String? title;
  final String? body;
  final DateTime scheduledDate;
  final String? payload;
  final DateTimeComponents? matchDateTimeComponents;

  FakeScheduledNotification({
    required this.id,
    this.title,
    this.body,
    required this.scheduledDate,
    this.payload,
    this.matchDateTimeComponents,
  });
}

/// Fake Android implementation for permission checking
class FakeAndroidFlutterLocalNotificationsPlugin
    implements AndroidFlutterLocalNotificationsPlugin {
  final FakeFlutterLocalNotificationsPlugin _parent;

  FakeAndroidFlutterLocalNotificationsPlugin(this._parent);

  @override
  Future<bool?> areNotificationsEnabled() async {
    return _parent.permissionsGranted;
  }

  @override
  Future<bool?> requestNotificationsPermission() async {
    return _parent.permissionsGranted;
  }

  @override
  Future<bool?> requestExactAlarmsPermission() async {
    return true;
  }

  @override
  Future<bool?> canScheduleExactNotifications() async {
    return true;
  }

  // Add remaining required methods with no-op implementations
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
