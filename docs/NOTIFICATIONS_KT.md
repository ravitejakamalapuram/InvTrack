# InvTrack Notifications - Knowledge Transfer Document

> Complete guide to the notification system in InvTrack, covering all notification types, how they're triggered, and how to extend the system.

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Notification Types](#notification-types)
3. [How Notifications Are Triggered](#how-notifications-are-triggered)
4. [Deep Linking & Navigation](#deep-linking--navigation)
5. [User Preferences](#user-preferences)
6. [Testing Notifications](#testing-notifications)
7. [Adding New Notification Types](#adding-new-notification-types)

---

## Architecture Overview

### Key Files

| File | Purpose |
|------|---------|
| `lib/core/notifications/notification_service.dart` | Main service for scheduling/showing notifications |
| `lib/core/notifications/notification_payload.dart` | Payload parsing for deep linking |
| `lib/core/notifications/notification_navigator.dart` | Navigation logic when user taps notification |
| `lib/main.dart` | Initialization and recurring notification scheduling |
| `lib/features/investment/presentation/providers/investment_notifier.dart` | Integration with business logic |

### Dependencies

- **flutter_local_notifications** - Core notification plugin
- **timezone** - For scheduling notifications at specific times
- **shared_preferences** - Storing user preferences and milestone tracking

### Initialization Flow

```
main.dart
  └── _initializeNonCriticalServices()
        ├── notificationService.initialize()
        │     ├── Initialize timezone data
        │     ├── Configure Android/iOS settings
        │     └── Set up tap handler
        └── _scheduleRecurringNotifications()
              ├── scheduleTaxReminders()
              ├── scheduleWeeklyCheckIn()
              └── scheduleFYSummary()
```

---

## Notification Types

### 1. Weekly Summary 📊
**Channel:** `weekly_summary`  
**Trigger:** Scheduled - Every Sunday at 10 AM  
**Purpose:** Prompts user to check weekly investment activity  
**Payload:** `weekly_summary` → Navigates to Overview screen  
**User Toggle:** ✅ Settings → Notifications → Weekly Summary

### 2. Monthly Summary 📈
**Channel:** `monthly_summary`  
**Trigger:** Scheduled - Last day of each month at 6 PM  
**Purpose:** Review monthly income from investments  
**Payload:** `monthly_summary` → Navigates to Overview screen  
**User Toggle:** ✅ Settings → Notifications → Monthly Summary

### 3. Income Reminders 💰
**Channel:** `income_reminders`  
**Trigger:** Scheduled based on investment's income frequency  
**Purpose:** Remind user to check if expected income was received  
**Payload:** `income_reminder:{investmentId}` → Opens Add Cash Flow screen  
**User Toggle:** ✅ Settings → Notifications → Income Reminders  
**Action Buttons (Android):**
- 💰 Record Income - Opens add cash flow
- ⏰ Snooze 1 Day - Reschedules notification

**Scheduling Logic:**
- If `lastIncomeDate` exists: Next payment = last date + frequency
- If no last date: Next payment = today + frequency
- Time: 9 AM on expected date

### 4. Maturity Reminders 📅
**Channel:** `maturity_reminders`  
**Trigger:** Scheduled - 7 days and 1 day before maturity date  
**Purpose:** Alert user before investment matures  
**Payload:** `maturity_reminder:{investmentId}:{daysRemaining}` → Investment Detail  
**User Toggle:** ✅ Settings → Notifications → Maturity Reminders  
**Action Buttons (Android):**
- 👁️ View Details - Opens investment detail
- ✅ Mark Complete - Opens investment to close it

**Enhanced Body includes:**
- Investment type (FD, Bond, etc.)
- Maturity value
- Returns percentage

### 5. Milestone Celebrations 🎉
**Channel:** `milestones`  
**Trigger:** Event-based - After cash flow is added (income/return)  
**Purpose:** Celebrate when investment reaches return milestones  
**Milestones:** 1.5x, 2.0x, 3.0x, 5.0x, 10.0x MOIC  
**Payload:** `milestone:{investmentId}:{moic}` → Investment Detail  
**User Toggle:** ✅ (stored in preferences)  
**Deduplication:** Each milestone shown only once per investment

### 6. Tax Reminders 📋💰📝
**Channel:** `tax_reminders`  
**Trigger:** Scheduled - India-specific tax dates  
**Purpose:** Remind about tax deadlines  
**User Toggle:** ✅ (stored in preferences)

| Notification | Date | Reminder Date |
|--------------|------|---------------|
| 80C Investment Deadline | March 31 | March 24 |
| Advance Tax Q1 | June 15 | June 10 |
| Advance Tax Q2 | September 15 | September 10 |
| Advance Tax Q3 | December 15 | December 10 |
| Advance Tax Q4 | March 15 | March 10 |
| ITR Filing Deadline | July 31 | July 25 |

### 7. Risk/Concentration Alerts ⚠️
**Channel:** `risk_alerts`  
**Trigger:** Event-based - Called from portfolio analysis  
**Purpose:** Alert when portfolio has concentration risk  
**Alert Types:**
- Single investment > 30% of portfolio
- Single platform > 40% of portfolio
- Single type > 50% of portfolio
**Payload:** `risk_alert:{alertType}` → Overview screen  
**User Toggle:** ✅ (stored in preferences)

### 8. Weekly Check-In 📊
**Channel:** `weekly_check_in`  
**Trigger:** Scheduled - Every Sunday at 6 PM  
**Purpose:** Prompt user to log any income received during the week  
**Payload:** `weekly_check_in` → Add Cash Flow (generic)  
**User Toggle:** ✅ (stored in preferences)

### 9. Idle Investment Alerts 💤
**Channel:** `idle_alerts`  
**Trigger:** Event-based - During idle investment check  
**Purpose:** Alert for investments with no activity for X days  
**Default Threshold:** 90 days (configurable)  
**Payload:** `idle_alert:{investmentId}` → Investment Detail  
**User Toggle:** ✅ (stored in preferences)  
**Deduplication:** Max once per month per investment

### 10. FY Summary 📊
**Channel:** `fy_summary`  
**Trigger:** Scheduled - April 1st at 10 AM (India FY start)  
**Purpose:** Summarize previous financial year performance  
**Payload:** `fy_summary` → Overview screen  
**User Toggle:** ✅ (stored in preferences)

### 11. Test Notifications 🔔⏰
**Channel:** `general`
**Purpose:** Developer testing in Settings → Developer Options
**Types:**
- Immediate test notification
- Scheduled test (5 seconds delay)

---

## How Notifications Are Triggered

### Scheduled Notifications (Recurring)

Called in `main.dart` → `_scheduleRecurringNotifications()` on every app start:

```dart
await notificationService.scheduleTaxReminders();
await notificationService.scheduleWeeklyCheckIn();
await notificationService.scheduleFYSummary();
```

These methods are **idempotent** - safe to call repeatedly. They cancel existing notifications before rescheduling.

### Event-Based Notifications

Triggered from business logic in `InvestmentNotifier`:

```dart
// After adding cash flow
await _notificationService.checkAndShowMilestoneNotification(investment);

// After updating investment
await _notificationService.scheduleIncomeReminder(investment);
await _notificationService.scheduleMaturityReminder(investment);
```

### Notification ID Strategy

Each notification type uses a unique ID range to prevent conflicts:

| Type | ID Range/Pattern |
|------|------------------|
| Weekly Summary | 1 |
| Monthly Summary | 2 |
| Weekly Check-In | 3 |
| FY Summary | 4 |
| Tax Reminders | 100-199 |
| Income Reminders | `investmentId.hashCode` |
| Maturity Reminders | `investmentId.hashCode + 1000000` |
| Milestones | `investmentId.hashCode + 2000000` |
| Risk Alerts | 3000000+ |
| Idle Alerts | `investmentId.hashCode + 4000000` |

---

## Deep Linking & Navigation

### Payload Format

Notifications use a simple string payload format:

```
{type}:{param1}:{param2}
```

Examples:
- `income_reminder:abc123` → Income reminder for investment abc123
- `maturity_reminder:abc123:7` → Maturity reminder, 7 days remaining
- `milestone:abc123:2.0` → 2x MOIC milestone for investment abc123

### Navigation Handler

`NotificationNavigator.handleNotificationTap()` parses the payload and navigates:

```dart
static void handleNotificationTap(String? payload, BuildContext context) {
  final parsed = NotificationPayload.parse(payload);
  switch (parsed.type) {
    case NotificationType.incomeReminder:
      // Navigate to AddCashFlowScreen with investment pre-selected
    case NotificationType.maturityReminder:
      // Navigate to InvestmentDetailScreen
    // ... etc
  }
}
```

### Action Button Handling

Android action buttons are handled in `_onNotificationAction()`:

```dart
void _onNotificationAction(NotificationResponse response) {
  switch (response.actionId) {
    case 'record_income':
      // Navigate to add cash flow
    case 'snooze':
      // Reschedule notification for tomorrow
    case 'view_details':
      // Navigate to investment detail
  }
}
```

---

## User Preferences

### Preference Keys (SharedPreferences)

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `weekly_summary_enabled` | bool | true | Weekly summary notifications |
| `income_reminders_enabled` | bool | true | Income reminder notifications |
| `maturity_reminders_enabled` | bool | true | Maturity reminder notifications |
| `monthly_summary_enabled` | bool | true | Monthly summary notifications |
| `tax_reminders_enabled` | bool | true | Tax deadline reminders |
| `milestone_notifications_enabled` | bool | true | Milestone celebrations |
| `risk_alerts_enabled` | bool | true | Risk/concentration alerts |
| `idle_alerts_enabled` | bool | true | Idle investment alerts |
| `idle_alert_threshold_days` | int | 90 | Days before idle alert |
| `milestone_shown_{investmentId}_{moic}` | bool | - | Deduplication tracking |
| `last_idle_alert_{investmentId}` | int | - | Last alert timestamp |

### Accessing Preferences

```dart
// Read
final enabled = notificationService.weeklySummaryEnabled;

// Write
await notificationService.setWeeklySummaryEnabled(true);
```

---

## Testing Notifications

### In-App Testing (Settings → Developer Options)

1. **Test Notification** - Shows immediate notification
2. **Test Scheduled Notification** - Schedules notification in 5 seconds

### Manual Testing Checklist

- [ ] Toggle each notification type on/off in Settings
- [ ] Verify notification appears at scheduled time
- [ ] Tap notification and verify correct screen opens
- [ ] Test action buttons (Android only)
- [ ] Test with app in foreground/background/killed
- [ ] Verify preferences persist across app restarts

### Debug Logging

In debug mode, notifications log to console:

```
🔔 Recurring notifications scheduled
🔔 Scheduled income reminder for Investment XYZ
🔔 Showing milestone notification: 2.0x MOIC!
```

---

## Adding New Notification Types

### Step 1: Add Channel (Android)

In `notification_service.dart`, add to `_initializeAndroid()`:

```dart
const AndroidNotificationChannel newChannel = AndroidNotificationChannel(
  'new_channel_id',
  'New Channel Name',
  description: 'Description for users',
  importance: Importance.high,
);
await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
    ?.createNotificationChannel(newChannel);
```

### Step 2: Add Preference

```dart
// Getter
bool get newFeatureEnabled => _prefs.getBool('new_feature_enabled') ?? true;

// Setter
Future<void> setNewFeatureEnabled(bool value) async {
  await _prefs.setBool('new_feature_enabled', value);
  if (!value) {
    await _cancelNewFeatureNotifications();
  }
}
```

### Step 3: Add Scheduling Method

```dart
Future<void> scheduleNewFeatureNotification(Investment investment) async {
  if (!newFeatureEnabled) return;

  final hasPermission = await requestPermissions();
  if (!hasPermission) return;

  await _flutterLocalNotificationsPlugin.zonedSchedule(
    _generateNotificationId(investment.id, 'new_feature'),
    'Title',
    'Body',
    _nextScheduledTime(),
    _getNotificationDetails('new_channel_id'),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    payload: 'new_feature:${investment.id}',
  );
}
```

### Step 4: Add Payload Handling

In `notification_payload.dart`:

```dart
enum NotificationType {
  // ... existing types
  newFeature,
}

// Add parsing logic in parse() method
```

### Step 5: Add Navigation

In `notification_navigator.dart`:

```dart
case NotificationType.newFeature:
  Navigator.push(context, MaterialPageRoute(
    builder: (_) => NewFeatureScreen(investmentId: parsed.investmentId),
  ));
```

### Step 6: Add UI Toggle

In `settings_screen.dart` → `_buildNotificationsSection()`:

```dart
SwitchListTile(
  title: const Text('New Feature'),
  subtitle: const Text('Description'),
  secondary: const Icon(Icons.new_icon, color: Colors.blue),
  value: notificationService.newFeatureEnabled,
  onChanged: (bool value) async {
    if (value) await notificationService.requestPermissions();
    await notificationService.setNewFeatureEnabled(value);
    ref.invalidate(notificationServiceProvider);
  },
),
```

---

## Platform-Specific Notes

### Android

- Requires `POST_NOTIFICATIONS` permission (Android 13+)
- Supports action buttons on notifications
- Uses notification channels for user control
- Exact alarms require `SCHEDULE_EXACT_ALARM` permission

### iOS

- Requires user permission prompt
- No action buttons (simplified UX)
- Uses provisional authorization for silent notifications
- Badge count not currently implemented

---

## Future Enhancements

### Goal Progress Notifications 🎯
**Status:** Deferred - Requires user goals feature
**Concept:** Notify users when they reach milestones toward their investment goals
**Prerequisites:**
1. Goals feature - Allow users to set target corpus (e.g., "₹10L emergency fund")
2. Income goals - Allow users to set target passive income (e.g., "₹5K/month")
3. Goal tracking - Calculate progress percentage

**Proposed Notifications:**
- 25%, 50%, 75%, 90%, 100% goal progress milestones
- "On track" / "Behind schedule" alerts based on deadline
- Goal completion celebration

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Notifications not appearing | Check permissions in device settings |
| Scheduled notifications not firing | Verify timezone initialization |
| Wrong screen on tap | Check payload format and parsing |
| Duplicate notifications | Verify notification ID uniqueness |
| Notifications stop after app kill | Normal on some devices - use FCM for critical notifications |

---

*Last updated: December 2024*

