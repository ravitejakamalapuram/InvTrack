import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mocktail/mocktail.dart';
import 'package:timezone/timezone.dart' as tz;

/// Mock implementation of FlutterLocalNotificationsPlugin for testing.
class MockFlutterLocalNotificationsPlugin extends Mock
    implements FlutterLocalNotificationsPlugin {}

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

  void reset() {
    shownNotifications.clear();
    scheduledNotifications.clear();
    cancelledNotificationIds.clear();
    _isInitialized = false;
    _allCancelled = false;
    permissionsGranted = true;
  }

  @override
  Future<bool?> initialize(
    InitializationSettings initializationSettings, {
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
  Future<void> show(
    int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails, {
    String? payload,
  }) async {
    shownNotifications.add(
      FakeNotification(id: id, title: title, body: body, payload: payload),
    );
    if (kDebugMode) {
      debugPrint('🔔 FakeNotificationPlugin: show($id, $title, $body)');
    }
  }

  @override
  Future<void> zonedSchedule(
    int id,
    String? title,
    String? body,
    tz.TZDateTime scheduledDate,
    NotificationDetails notificationDetails, {
    required AndroidScheduleMode androidScheduleMode,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
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
  Future<void> cancel(int id, {String? tag}) async {
    cancelledNotificationIds.add(id);
    scheduledNotifications.removeWhere((n) => n.id == id);
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

  FakeNotification({required this.id, this.title, this.body, this.payload});
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
