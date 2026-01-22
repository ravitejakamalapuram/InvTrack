---
type: "always_apply"
---

# Analytics & Monitoring Rules – InvTrack

These rules ensure meaningful analytics and effective error monitoring.

---

## ANALYTICS RULE 1: EVENT NAMING
Use snake_case for all event names:
```dart
// ✅ Correct
analytics.logEvent(name: 'investment_created');
analytics.logEvent(name: 'goal_completed');
analytics.logEvent(name: 'csv_import_started');

// ❌ Wrong
analytics.logEvent(name: 'InvestmentCreated');
analytics.logEvent(name: 'goal-completed');
analytics.logEvent(name: 'CSV Import Started');
```

Event naming pattern: `{noun}_{verb}` or `{feature}_{action}`

---

## ANALYTICS RULE 2: STANDARD EVENTS
Use predefined events when available:
```dart
// ✅ Use standard events
analytics.logScreenView(screenName: 'investment_detail');
analytics.logLogin(loginMethod: 'google');
analytics.logSignUp(signUpMethod: 'google');
analytics.logShare(contentType: 'csv_export', itemId: 'investments');

// Custom events for app-specific actions
analytics.logEvent(name: 'xirr_calculated', parameters: {'count': 5});
```

---

## ANALYTICS RULE 3: SCREEN TRACKING
Log screen views for all main screens:
```dart
// In GoRouter observer or screen widget
analytics.logScreenView(
  screenName: 'home',
  screenClass: 'HomeScreen',
);
```

Required screens to track:
- Home / Dashboard
- Investment list / detail
- Add/Edit investment
- Goals list / detail
- Settings
- Premium / Upgrade
- Onboarding steps

---

## ANALYTICS RULE 4: USER PROPERTIES
Set meaningful user properties for segmentation:
```dart
// ✅ Useful properties
analytics.setUserProperty(name: 'investment_count', value: '10');
analytics.setUserProperty(name: 'premium_status', value: 'active');
analytics.setUserProperty(name: 'app_theme', value: 'dark');

// ❌ Never set PII
analytics.setUserProperty(name: 'email', value: user.email); // WRONG!
```

---

## ANALYTICS RULE 5: FUNNEL TRACKING
Track key user journeys:

### Onboarding Funnel
1. `onboarding_started`
2. `onboarding_step_1_completed`
3. `onboarding_step_2_completed`
4. `onboarding_completed`

### Investment Creation Funnel
1. `add_investment_tapped`
2. `investment_form_started`
3. `investment_created`

### Premium Conversion Funnel
1. `premium_screen_viewed`
2. `premium_plan_selected`
3. `premium_purchase_started`
4. `premium_purchase_completed`

---

## ANALYTICS RULE 6: ERROR TRACKING (CRASHLYTICS)
Log errors with context:
```dart
// ✅ Rich error context
CrashlyticsService().recordError(
  error,
  stack,
  reason: 'Failed to load investments',
  information: ['userId: ${user.id}', 'count: $count'],
);

// ✅ Non-fatal errors for recoverable issues
CrashlyticsService().recordError(error, stack, fatal: false);

// ✅ Fatal errors for crashes
CrashlyticsService().recordError(error, stack, fatal: true);
```

---

## ANALYTICS RULE 7: CUSTOM KEYS FOR DEBUGGING
Set breadcrumbs for crash investigation:
```dart
// Before complex operations
Crashlytics.instance.setCustomKey('last_action', 'bulk_import');
Crashlytics.instance.setCustomKey('item_count', investments.length);

// User flow tracking
Crashlytics.instance.log('User started CSV import with 50 rows');
```

---

## ANALYTICS RULE 8: PERFORMANCE MONITORING
Track key operation durations:
```dart
// ✅ Track slow operations
final trace = FirebasePerformance.instance.newTrace('bulk_import');
await trace.start();
try {
  await performBulkImport(data);
  trace.putAttribute('row_count', data.length.toString());
} finally {
  await trace.stop();
}
```

Operations to monitor:
- App startup time
- Screen load times
- Database queries
- File operations
- Network requests

---

## ANALYTICS RULE 9: PRIVACY COMPLIANCE
Never log:
- ❌ Email addresses
- ❌ Phone numbers
- ❌ Full names
- ❌ Financial account numbers
- ❌ Investment amounts (use ranges instead)
- ❌ Document contents
- ❌ Location data (unless explicitly consented)

Anonymize data:
```dart
// ✅ Use ranges instead of exact values
String getAmountRange(double amount) {
  if (amount < 1000) return 'under_1k';
  if (amount < 10000) return '1k_10k';
  if (amount < 100000) return '10k_100k';
  return 'over_100k';
}

analytics.logEvent(
  name: 'investment_created',
  parameters: {'amount_range': getAmountRange(investment.amount)},
);
```

---

## ANALYTICS RULE 10: DEBUG MODE HANDLING
Disable analytics in debug builds:
```dart
// In main.dart or analytics service
if (kDebugMode) {
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
}
```

Or use a debug analytics service that logs to console instead.

---

## ANALYTICS RULE 11: EVENT PARAMETERS
Limit parameters per event:
- Max 25 parameters per event
- Parameter names: max 40 characters
- Parameter values: max 100 characters
- Use meaningful parameter names

```dart
analytics.logEvent(
  name: 'investment_created',
  parameters: {
    'type': investment.type.name,           // enum value
    'has_documents': investment.hasDocuments, // boolean
    'source': 'manual',                      // string
  },
);
```

---

## ANALYTICS RULE 12: ANALYTICS SERVICE PATTERN
Centralize analytics in a service:
```dart
class AnalyticsService {
  final FirebaseAnalytics _analytics;
  
  Future<void> logInvestmentCreated(InvestmentEntity investment) async {
    await _analytics.logEvent(
      name: 'investment_created',
      parameters: {
        'type': investment.type.name,
        'amount_range': _getAmountRange(investment.initialAmount),
      },
    );
  }
  
  // ... other typed methods
}
```

Benefits:
- Type-safe event logging
- Consistent parameter naming
- Easy to update across app
- Testable

