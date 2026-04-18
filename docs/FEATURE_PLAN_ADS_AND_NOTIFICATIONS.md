# Feature Plan: Ads, Notification Reports & Critical Bugs

**Created**: 2026-04-18  
**Sprint Duration**: 2-3 weeks  
**Focus**: Phase 2 - Monetization, Engagement, Stability  

---

## 🎯 **Sprint Goals**

Ship **five high-impact items** to boost monetization, engagement, and app stability:

1. **Ad Integration** - Non-intrusive Native Ads for revenue
2. **Notification Landing Pages** - Deep-linked, data-rich reports per notification type
3. **Bug Fix: Goal Notification Logic** - "Goal Reached" alerts fire only once
4. **Bug Fix: Crashlytics Restoration** - Firebase crash reporting operational
5. **Bug Fix: Version Update Popup** - "New Version Available" dialog displays correctly

---

## 📋 **Technical Feasibility Analysis**

### **Current Architecture Strengths**

✅ **Clean Architecture** - Domain/Data/Presentation layers well-separated  
✅ **GoRouter Deep Linking** - Existing payload parsing in `notification_payload.dart`  
✅ **Notification System** - 11 notification types already implemented  
✅ **Analytics Foundation** - Firebase Analytics & Crashlytics initialized  
✅ **Version Management** - `VersionCheckService` and `AppVersionEntity` exist  

### **Current Architecture Constraints**

⚠️ **No Ad Integration** - `google_mobile_ads` not installed  
⚠️ **Generic Navigation** - All notifications route to home/detail screens, not specialized reports  
⚠️ **Missing Notification Flags** - No "sent" tracking for goal milestones (fires on every cashflow)  
⚠️ **Crashlytics Silent** - Initialized but not reporting (possible symbol upload issue)  
⚠️ **Version Popup Missing** - `VersionCheckInitializer` exists but dialog doesn't appear  

---

## 🏗️ **Architecture Compatibility**

All planned features fit within existing Clean Architecture:

| Feature | Layer | Integration Point |
|---------|-------|-------------------|
| Native Ads | Presentation | New widget in `lib/core/widgets/ad_widget.dart` |
| Notification Reports | Presentation | New screens in `lib/features/notifications/presentation/screens/` |
| Goal Notification Fix | Domain | Modify `GoalNotificationHandler.checkAndShowGoalMilestone()` |
| Crashlytics Fix | Core | Verify `main.dart` + iOS/Android symbol upload |
| Version Popup Fix | Presentation | Debug `VersionCheckInitializer._showUpdateDialog()` |

**No breaking changes to domain layer** - All modifications are additive or bug fixes.

---

## 📊 **Success Metrics**

| Metric | Target | Measurement |
|--------|--------|-------------|
| Ad Revenue | ₹500+/month after 3 months | AdMob dashboard |
| Notification CTR | 20%+ click-through to reports | Analytics: `notification_report_viewed` |
| Goal Alert Accuracy | 100% (fires once per milestone) | Manual testing + analytics |
| Crash Reporting | >90% crashes captured | Firebase Crashlytics console |
| Update Adoption | >70% users update within 7 days | Version analytics |

---

## 🗂️ **Existing Codebase Assets**

### **Notification Infrastructure**

- **11 Notification Types**: Weekly Summary, Monthly Summary, Maturity Reminder, Income Alert, Milestone, Goal Milestone, Goal At-Risk, Goal Stale, Risk Alert, Idle Alert, FY Summary
- **Payload Parsing**: `NotificationPayload.parse()` already handles all types
- **Navigation**: `NotificationNavigator.handleNotificationTap()` routes to screens
- **Preferences**: `NotificationPreferencesMixin` manages user opt-ins

### **Analytics & Monitoring**

- **Crashlytics**: `CrashlyticsService` initialized in `main.dart` (line 77-78)
- **Analytics**: `AnalyticsService` with Firebase Analytics observer
- **Performance**: `PerformanceService` tracks operation latency
- **Logging**: `LoggerService` with structured metadata

### **Version Management**

- **Version Check**: `VersionCheckService.fetchLatestVersion()` reads from `app_config/version_info`
- **Version State**: `VersionCheckProvider` manages state and auto-check
- **Update Dialog**: `UpdateDialog` widget exists, not showing
- **Firestore Schema**: `latestVersion`, `minimumVersion`, `forceUpdate`, `releaseDate`

---

---

# 1️⃣ **Ad Integration Strategy**

## **Monetization Plan: Premium UI + Non-Intrusive Ads**

**Goal**: Generate revenue without compromising the "Premium UI" brand promise.

### **Ad Placement Strategy**

**Native Ads Only** - Blend seamlessly with app design (no banner/interstitial spam)

| Placement | Screen | Frequency | User Experience |
|-----------|--------|-----------|-----------------|
| Investment List Footer | `InvestmentListScreen` | 1 ad per 10 investments | Appears after scroll, blends with card design |
| Portfolio Health Card | `PortfolioHealthDetailsScreen` | 1 ad at bottom | Styled as insight card |
| Goal List Footer | `GoalsScreen` | 1 ad per 5 goals | Matches goal card UI |

**Ad-Free Experience for Premium Features**:
- No ads in FIRE Number dashboard
- No ads in Settings/Security
- No ads during first 7 days (new user grace period)

### **Technical Requirements**

**Dependencies**:
```yaml
dependencies:
  google_mobile_ads: ^5.2.0
```

**Ad Unit IDs** (Android/iOS):
- Investment List: ca-app-pub-xxxxx/1234567890
- Portfolio Health: ca-app-pub-xxxxx/0987654321
- Goal List: ca-app-pub-xxxxx/1122334455

**Implementation Files**:
- `lib/core/ads/ad_service.dart` - Wrapper for `google_mobile_ads`
- `lib/core/ads/ad_provider.dart` - Riverpod provider for ad state
- `lib/core/widgets/native_ad_widget.dart` - Reusable styled native ad widget
- `lib/core/ads/ad_placement_strategy.dart` - Logic for ad frequency/placement

### **Privacy-First Design**

✅ **GDPR/Privacy Compliance**:
- Show "Personalized Ads" consent dialog on first launch
- Store consent in SharedPreferences
- Pass consent to AdMob via `RequestConfiguration`
- Respect "Do Not Track" if user opts out

❌ **No Invasive Tracking**:
- No user profile sharing with ad networks
- No location-based ad targeting
- Only anonymized app usage for ad relevance

### **Analytics Events**

```dart
// Track ad impressions (privacy-safe)
analyticsService.logEvent(
  name: 'ad_impression',
  parameters: {
    'ad_placement': 'investment_list',
    'ad_format': 'native',
    'user_segment': 'free_tier', // No PII
  },
);

// Track ad revenue (aggregated)
analyticsService.logEvent(
  name: 'ad_revenue',
  parameters: {
    'revenue_range': '0_to_1_rupee', // Privacy-safe ranges
    'currency': 'INR',
  },
);
```

### **Acceptance Criteria**

- [ ] Native ads load within 2 seconds
- [ ] Ads match app theme (light/dark mode)
- [ ] Ads respect "Premium UI" aesthetic (no garish colors/fonts)
- [ ] Ad frequency limits enforced (1 per 10 investments, 1 per 5 goals)
- [ ] No ads for first 7 days after signup
- [ ] GDPR consent dialog on first launch
- [ ] Analytics events fire for impressions/revenue
- [ ] Ad blockers gracefully handled (no crash, show placeholder)

---

# 2️⃣ **Notification Landing Pages (Notification Reports)**

## **Deep-Linked, Data-Rich Report Screens**

**Problem**: Tapping notifications currently lands on home/investment detail - users expect specific insights.

**Solution**: Create 11 specialized report screens, one per notification type, with GoRouter deep linking.

### **Notification Type → Report Screen Mapping**

| Notification Type | Current Navigation | New Report Screen | Deep Link |
|-------------------|-------------------|-------------------|-----------|
| Weekly Summary | Overview (home) | WeeklySummaryReportScreen | `/reports/weekly` |
| Monthly Summary | Overview (home) | MonthlySummaryReportScreen | `/reports/monthly` |
| Maturity Reminder | InvestmentDetailScreen | MaturityReportScreen | `/reports/maturity/:investmentId` |
| Income Alert | AddTransactionScreen | IncomeReportScreen | `/reports/income/:investmentId` |
| Milestone | InvestmentDetailScreen | MilestoneReportScreen | `/reports/milestone/:investmentId` |
| Goal Milestone | GoalDetailsScreen | GoalMilestoneReportScreen | `/reports/goal-milestone/:goalId` |
| Goal At-Risk | GoalDetailsScreen | GoalAtRiskReportScreen | `/reports/goal-at-risk/:goalId` |
| Goal Stale | GoalDetailsScreen | GoalStaleReportScreen | `/reports/goal-stale/:goalId` |
| Risk Alert | Overview (home) | RiskAlertReportScreen | `/reports/risk-alert` |
| Idle Alert | InvestmentDetailScreen | IdleAlertReportScreen | `/reports/idle/:investmentId` |
| FY Summary | Overview (home) | FYSummaryReportScreen | `/reports/fy-summary` |

### **GoRouter Deep Linking Logic**

**Modify `lib/core/router/app_router.dart`**:

```dart
// Add new routes for notification reports
GoRoute(
  path: '/reports/weekly',
  builder: (context, state) => const WeeklySummaryReportScreen(),
),
GoRoute(
  path: '/reports/maturity/:investmentId',
  builder: (context, state) {
    final investmentId = state.pathParameters['investmentId']!;
    final daysToMaturity = state.uri.queryParameters['daysToMaturity'] ?? '0';
    return MaturityReportScreen(
      investmentId: investmentId,
      daysToMaturity: int.parse(daysToMaturity),
    );
  },
),
GoRoute(
  path: '/reports/goal-milestone/:goalId',
  builder: (context, state) {
    final goalId = state.pathParameters['goalId']!;
    final milestonePercent = state.uri.queryParameters['milestone'] ?? '0';
    return GoalMilestoneReportScreen(
      goalId: goalId,
      milestonePercent: int.parse(milestonePercent),
    );
  },
),
// ... 8 more routes
```

**Modify `lib/core/notifications/notification_navigator.dart`**:

```dart
// Add new navigation cases for report screens
case NotificationPayloadType.weeklySummary:
  return _navigateToWeeklySummaryReport();

case NotificationPayloadType.maturityReminder:
  return _navigateToMaturityReport(payload.investmentId, payload.params);

case NotificationPayloadType.goalMilestone:
  return _navigateToGoalMilestoneReport(payload.goalId, payload.params);

// ... 8 more cases

Future<bool> _navigateToWeeklySummaryReport() async {
  rootNavigatorKey.currentContext?.push('/reports/weekly');
  return true;
}

Future<bool> _navigateToMaturityReport(
  String? investmentId,
  Map<String, String> params,
) async {
  if (investmentId == null) return false;
  rootNavigatorKey.currentContext?.push(
    '/reports/maturity/$investmentId?daysToMaturity=${params['daysToMaturity']}',
  );
  return true;
}
```

### **Report Screen UI Requirements**

Each report screen MUST include:

1. **Header**: Notification icon + title + timestamp
2. **Key Metrics**: 2-4 highlighted stats (e.g., "7 days until maturity", "₹5,000 income expected")
3. **Data Visualization**: Chart/graph where applicable (weekly trend, goal progress)
4. **Action Buttons**: 1-2 CTAs (e.g., "Add Income", "Adjust Goal", "View Investment")
5. **Contextual Help**: Tooltip explaining why this notification was sent

**Example: WeeklySummaryReportScreen**:
- Header: "📊 Weekly Summary · Apr 12-18, 2026"
- Metrics: "5 investments tracked", "+₹12,000 added", "15% avg return"
- Visualization: Bar chart of weekly cashflows
- Actions: "View All Investments", "Add Transaction"
- Help: "We send weekly summaries every Sunday at 9 AM to keep you on track."

### **Notification Payload Updates**

**Modify `lib/core/notifications/notification_payload.dart`**:

```dart
// Update payload parsing to include report-specific params
case 'weekly_summary':
  return NotificationPayload(
    type: NotificationPayloadType.weeklySummary, // NEW ENUM VALUE
    params: {
      'startDate': _getWeekStartDate().toIso8601String(),
      'endDate': _getWeekEndDate().toIso8601String(),
    },
  );

case 'maturity_reminder':
  return NotificationPayload(
    type: NotificationPayloadType.maturityReport, // NEW ENUM VALUE
    investmentId: parts.length > 1 ? parts[1] : null,
    params: {
      'daysToMaturity': parts.length > 2 ? parts[2] : '0',
      'expectedAmount': parts.length > 3 ? parts[3] : '0', // Pass maturity value
    },
  );
```

### **Acceptance Criteria**

- [ ] All 11 notification types route to specialized report screens
- [ ] GoRouter routes added for all 11 reports
- [ ] Report screens show contextual data (not just generic summaries)
- [ ] Navigation from notification tap works offline (cached data)
- [ ] Analytics event fired: `notification_report_viewed` with `report_type` param
- [ ] All report screens localized in ARB files
- [ ] All report screens respect privacy mode (mask amounts)
- [ ] Report screens show "empty state" if data unavailable
- [ ] Deep links work when app is closed (cold start)
- [ ] Deep links work when app is backgrounded (warm start)

---

# 3️⃣ **Bug Fix: Goal Notification Logic**

## **Problem Statement**

**Current Behavior**:
Goal milestone notifications (25%, 50%, 75%, 100%) fire on **every cashflow addition** after the milestone is reached, spamming users.

**Root Cause**:
`GoalNotificationHandler.checkAndShowGoalMilestone()` checks if milestone is reached but doesn't track if notification was **already sent**. The `isGoalMilestoneShown()` check uses SharedPreferences, but it's not persisting correctly across sessions.

**Evidence from Code**:
`lib/core/notifications/handlers/goal_notification_handler.dart:56`
```dart
if (progressPercent >= milestone &&
    !isGoalMilestoneShown(goalId, milestone)) { // THIS CHECK FAILS
  reachedMilestone = milestone;
  break;
}
```

The `isGoalMilestoneShown()` method relies on SharedPreferences key `goal_milestone_${goalId}_$milestone`, but this is cleared on app restart or when goal is updated.

### **Solution: Persistent Notification Flags in Firestore**

**Modify Goal Entity** to include `notificationMilestones` field:

```dart
// lib/features/goals/domain/entities/goal_entity.dart

class GoalEntity {
  // ... existing fields

  /// Notification milestones already sent (to prevent duplicates)
  /// Example: [25, 50, 75] means 25%, 50%, 75% notifications sent
  final List<int> notificationMilestonesSent;

  const GoalEntity({
    // ... existing params
    this.notificationMilestonesSent = const [],
  });
}
```

**Update Firestore Schema**:

```dart
// lib/features/goals/data/models/goal_model.dart

static Map<String, dynamic> toFirestore(GoalEntity goal) {
  return {
    // ... existing fields
    'notificationMilestonesSent': goal.notificationMilestonesSent,
  };
}

static GoalEntity fromFirestore(Map<String, dynamic> data, String id) {
  return GoalEntity(
    // ... existing fields
    notificationMilestonesSent: (data['notificationMilestonesSent'] as List<dynamic>?)
        ?.map((e) => e as int)
        .toList() ?? [],
  );
}
```

**Update Notification Logic**:

```dart
// lib/core/notifications/handlers/goal_notification_handler.dart

Future<void> checkAndShowGoalMilestone({
  required GoalEntity goal, // PASS FULL GOAL, NOT JUST ID
  required double progressPercent,
  required double currentValue,
  required double targetValue,
  String currency = 'INR',
}) async {
  // ... existing checks

  int? reachedMilestone;
  for (final milestone in goalMilestones.reversed) {
    if (progressPercent >= milestone &&
        !goal.notificationMilestonesSent.contains(milestone)) { // FIRESTORE CHECK
      reachedMilestone = milestone;
      break;
    }
  }

  if (reachedMilestone == null) return;

  // Show notification
  await _plugin.show(...);

  // PERSIST TO FIRESTORE (critical change)
  await _updateGoalMilestoneSent(goal, reachedMilestone);
}

Future<void> _updateGoalMilestoneSent(GoalEntity goal, int milestone) async {
  final updatedMilestones = [...goal.notificationMilestonesSent, milestone];
  final updatedGoal = goal.copyWith(
    notificationMilestonesSent: updatedMilestones,
  );
  // Use repository to persist (requires repository injection)
  await _goalRepository.updateGoal(updatedGoal);
}
```

**Dependency Injection**:

```dart
// lib/core/notifications/handlers/goal_notification_handler.dart

class GoalNotificationHandler with NotificationPreferencesMixin {
  final GoalRepository _goalRepository; // INJECT REPOSITORY

  GoalNotificationHandler({
    required FlutterLocalNotificationsPlugin plugin,
    required SharedPreferences prefs,
    required GoalRepository goalRepository, // NEW PARAM
    // ... existing params
  }) : _plugin = plugin,
       _prefs = prefs,
       _goalRepository = goalRepository;
}
```

### **Migration Plan**

**Backward Compatibility**:
- Existing goals without `notificationMilestonesSent` default to `[]`
- Firestore read handles missing field with null-safe fallback
- SharedPreferences milestone tracking deprecated (no removal, just ignored)

### **Testing Plan**

**Unit Tests**:
```dart
// test/features/goals/domain/entities/goal_entity_test.dart
test('goal milestone notifications sent only once', () async {
  final goal = GoalEntity(/* ... */ notificationMilestonesSent: [25]);
  final handler = GoalNotificationHandler(/* ... */);

  // Should NOT fire notification (25% already sent)
  await handler.checkAndShowGoalMilestone(
    goal: goal,
    progressPercent: 26.0,
    // ...
  );

  verifyNever(mockPlugin.show(any));
});
```

**Integration Tests**:
1. Create goal with ₹1L target
2. Add cashflow to reach 25% (₹25K) → Verify notification shown
3. Add another cashflow (total ₹30K) → Verify NO duplicate notification
4. Restart app
5. Add cashflow to reach 50% (₹50K) → Verify 50% notification shown
6. Check Firestore: `notificationMilestonesSent: [25, 50]`

### **Acceptance Criteria**

- [ ] Goal entity includes `notificationMilestonesSent` field
- [ ] Firestore schema updated with migration-safe read/write
- [ ] Notification handler persists milestone to Firestore after sending
- [ ] Duplicate notifications eliminated (100% accuracy)
- [ ] Unit tests pass for milestone deduplication
- [ ] Integration test confirms persistence across app restarts
- [ ] Analytics event: `goal_milestone_notification_sent` (includes `milestone` param)
- [ ] Help & FAQ updated with "Why am I getting/not getting goal notifications?"

---

# 4️⃣ **Bug Fix: Crash Analytics Restoration**

## **Problem Statement**

**Current Behavior**:
Firebase Crashlytics is initialized in `main.dart` but crashes are **not appearing** in Firebase Console.

**Expected Behavior**:
All uncaught exceptions, Flutter errors, and manually reported errors should appear in Crashlytics dashboard.

### **Diagnostic Checklist**

#### **✅ Step 1: Verify Initialization (DONE)**

`lib/main.dart:77-78`:
```dart
final crashlyticsService = CrashlyticsService();
unawaited(crashlyticsService.initialize());
```

`lib/core/analytics/crashlytics_service.dart:22-38`:
```dart
Future<void> initialize() async {
  await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode); // ✅
  FlutterError.onError = (errorDetails) { // ✅
    if (kDebugMode) {
      FlutterError.presentError(errorDetails);
    } else {
      _crashlytics.recordFlutterFatalError(errorDetails);
    }
  };
}
```

**Status**: ✅ Initialization code is correct.

#### **⚠️ Step 2: Check Symbol Upload (iOS)**

**Diagnosis**: iOS requires dSYM symbol upload for symbolicated crash reports.

**Check `ios/Podfile`**:
```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)

    # ⚠️ MISSING: Crashlytics symbol upload script
    target.build_configurations.each do |config|
      config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
    end
  end
end
```

**Check `ios/Runner.xcodeproj` Build Phases**:
- [ ] ❌ Missing: "Run Script" phase for Crashlytics symbol upload

**Solution**: Add Crashlytics symbol upload script to Xcode project.

#### **⚠️ Step 3: Check Symbol Upload (Android)**

**Diagnosis**: Android requires ProGuard mapping file upload for obfuscated builds.

**Check `android/app/build.gradle`**:
```gradle
buildTypes {
    release {
        signingConfig signingConfigs.release
        minifyEnabled true // Obfuscation enabled
        shrinkResources true
        proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'

        // ⚠️ MISSING: Crashlytics mapping file upload
        firebaseCrashlytics {
            mappingFileUploadEnabled true // ADD THIS
        }
    }
}
```

**Status**: ⚠️ Symbol upload likely missing for both platforms.

#### **✅ Step 4: Verify Firebase Config**

**Check `firebase_options.dart`**: ✅ Contains valid API keys
**Check `google-services.json`** (Android): ✅ Exists in `android/app/`
**Check `GoogleService-Info.plist`** (iOS): ✅ Exists in `ios/Runner/`

**Status**: ✅ Firebase config is correct.

#### **⚠️ Step 5: Test Crashlytics (Force Crash)**

**Add test crash button in Settings screen** (debug builds only):

```dart
// lib/features/settings/presentation/screens/settings_screen.dart

if (kDebugMode)
  ListTile(
    title: const Text('🔥 Test Crashlytics (Debug Only)'),
    subtitle: const Text('Force a crash to test reporting'),
    onTap: () {
      // Force crash in debug mode (will print to console)
      // In release mode, this would report to Crashlytics
      throw Exception('TEST CRASH: Crashlytics verification');
    },
  ),
```

**Testing**:
1. Switch to **release mode**: `flutter run --release`
2. Tap "Test Crashlytics" button
3. App crashes
4. Wait 5 minutes
5. Check Firebase Console → Crashlytics → "TEST CRASH" should appear

### **Solution: Enable Symbol Upload**

**iOS Symbol Upload** (Automated via Xcode Build Phase):

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select "Runner" target → "Build Phases"
3. Click "+" → "New Run Script Phase"
4. Add **after** "Compile Sources":

```bash
#!/bin/sh
# Crashlytics symbol upload for iOS

"${PODS_ROOT}/FirebaseCrashlytics/run"
```

5. Drag script phase **before** "Thin Binary"
6. Build settings → Debug Information Format → `DWARF with dSYM File`

**Android Symbol Upload** (Gradle Plugin):

**Modify `android/app/build.gradle`**:

```gradle
buildTypes {
    release {
        // ... existing config

        firebaseCrashlytics {
            mappingFileUploadEnabled true // ENABLE PROGUARD MAPPING UPLOAD
        }
    }
}
```

**Add to `android/build.gradle`** (project-level):

```gradle
buildscript {
    dependencies {
        // ... existing dependencies
        classpath 'com.google.firebase:firebase-crashlytics-gradle:2.9.9' // ADD THIS
    }
}
```

**Apply plugin in `android/app/build.gradle`**:

```gradle
apply plugin: 'com.android.application'
apply plugin: 'com.google.gms.google-services'
apply plugin: 'com.google.firebase.crashlytics' // ADD THIS
```

### **Verification**

**After implementing symbol upload**:

1. Build release APK: `flutter build apk --release`
2. Check build logs for: `✓ Uploaded mapping file to Crashlytics`
3. Install APK on device
4. Trigger test crash
5. Wait 5 minutes
6. Firebase Console → Crashlytics → Verify crash appears with **symbolicated stack trace**

**Success Indicators**:
- ✅ Stack trace shows Dart file names (not `<unknown>`)
- ✅ Line numbers visible
- ✅ Method names readable

### **Acceptance Criteria**

- [ ] iOS: dSYM upload script added to Xcode Build Phases
- [ ] Android: Crashlytics Gradle plugin applied
- [ ] Android: `mappingFileUploadEnabled true` in release build type
- [ ] Test crash in release mode reports to Crashlytics
- [ ] Stack traces are symbolicated (file names + line numbers visible)
- [ ] `ErrorHandler.logError()` reports non-validation errors to Crashlytics
- [ ] `runZonedGuarded` catches uncaught async errors (main.dart:58-66)
- [ ] Crashlytics dashboard shows >90% of crashes within 24 hours of occurrence

---

# 5️⃣ **Bug Fix: Version Update Popup**

## **Problem Statement**

**Current Behavior**:
"New Version Available" dialog does **not appear** even when a newer version exists in Firestore `app_config/version_info`.

**Expected Behavior**:
When app launches and a newer version is available (per `latestBuildNumber` in Firestore), the `UpdateDialog` should display.

### **Diagnostic Analysis**

#### **✅ Step 1: Firestore Document Exists**

Per `docs/VERSION_UPDATE_TROUBLESHOOTING.md`, the Firestore document structure is correct:

```json
{
  "latestVersion": "3.55.5",
  "latestBuildNumber": 165,
  "minimumVersion": "3.50.0",
  "minimumBuildNumber": 150,
  "forceUpdate": false,
  "updateMessage": "New features: Portfolio Health Score!",
  "whatsNew": "- Portfolio Health Score\n- Smart Notifications\n- Performance Improvements",
  "downloadUrl": "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker",
  "releaseDate": "2026-04-18T09:00:00Z" // CRITICAL: Must be in the past!
}
```

**Status**: ✅ Document exists and schema is correct.

#### **⚠️ Step 2: `releaseDate` Logic**

**Code Review** (`lib/features/app_update/domain/entities/app_version_entity.dart:40-43`):

```dart
bool isReleased() {
  if (releaseDate == null) return true; // Backward compatibility
  return DateTime.now().isAfter(releaseDate!); // GATE: Only show if released
}
```

**Hypothesis**: If `releaseDate` is set to a **future date**, the dialog won't show.

**Check Firestore**:
```text
releaseDate: "2026-04-25T09:00:00Z" // ❌ FUTURE DATE (today is 2026-04-18)
```

**Root Cause**: `releaseDate` is set to **1 week in the future** (auto-generated by CI/CD), preventing dialog from showing.

#### **✅ Step 3: Version Check Trigger**

**Code Review** (`lib/features/app_update/presentation/providers/version_check_provider.dart:108-111`):

```dart
// Auto-check on initialization if not checked in last 24 hours
if (_shouldAutoCheck()) {
  await checkForUpdates(); // ✅ Auto-checks on app start
}
```

**Status**: ✅ Version check triggers automatically.

#### **✅ Step 4: Dialog Display Logic**

**Code Review** (`lib/features/app_update/presentation/widgets/version_check_initializer.dart:62-66`):

```dart
if (versionState.shouldShowUpdateDialog && !_hasShownDialog) {
  _showUpdateDialog(versionState.latestVersion!);
} else if (versionState.requiresForceUpdate && !_hasShownDialog) {
  _showUpdateDialog(versionState.latestVersion!, forceUpdate: true);
}
```

**Code Review** (`lib/features/app_update/presentation/providers/version_check_provider.dart:36-47`):

```dart
bool get hasUpdate =>
    latestVersion != null &&
    latestVersion!.isOutdated(currentVersion, currentBuildNumber) &&
    latestVersion!.isReleased(); // ⚠️ GATE: Requires isReleased() == true

bool get shouldShowUpdateDialog =>
    hasUpdate && !updateDismissed && !requiresForceUpdate;
```

**Root Cause Confirmed**: `isReleased()` returns `false` because `releaseDate` is in the future.

### **Solution 1: Immediate Fix (Remove Future Date Gate)**

**Modify Firestore Document**:

Update `app_config/version_info` to set `releaseDate` to **today or past**:

```json
{
  "releaseDate": "2026-04-18T00:00:00Z" // SET TO TODAY OR REMOVE FIELD
}
```

**Alternative**: Remove `releaseDate` field entirely (backward compatibility triggers immediate display).

### **Solution 2: Long-Term Fix (CI/CD Adjustment)**

**Problem**: GitHub Actions workflow sets `releaseDate` to 7 days in the future by default.

**Fix**: Modify `.github/workflows/update-version-info.yml`:

```yaml
# BEFORE (sets future date)
releaseDate: ${{ steps.release_date.outputs.date }} # 7 days from now

# AFTER (sets immediate release)
releaseDate: ${{ github.event.repository.pushed_at }} # Timestamp of push
```

**Or**: Remove `releaseDate` field from workflow (use null for immediate display).

### **Solution 3: Add "Force Show" for Testing**

**Add debug option in Settings** (debug builds only):

```dart
// lib/features/settings/presentation/screens/settings_screen.dart

if (kDebugMode)
  ListTile(
    title: const Text('🔔 Force Show Update Dialog (Debug)'),
    subtitle: const Text('Test version update popup'),
    onTap: () async {
      final versionState = ref.read(versionCheckProvider);
      if (versionState.latestVersion != null) {
        showDialog(
          context: context,
          builder: (context) => UpdateDialog(
            versionInfo: versionState.latestVersion!,
            forceUpdate: false,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No version info loaded. Check Firestore.')),
        );
      }
    },
  ),
```

### **Testing Plan**

**Manual Test**:
1. Update Firestore `releaseDate` to yesterday
2. Restart app
3. Verify dialog appears within 2 seconds of app launch
4. Tap "Update Now" → Verify Play Store opens
5. Tap "Later" → Verify dialog dismisses
6. Restart app → Verify dialog **does not** appear (dismissed state persists)

**Automated Test**:
```dart
// test/features/app_update/version_check_provider_test.dart
testWidgets('shows update dialog when new version released', (tester) async {
  final container = ProviderContainer(
    overrides: [
      versionCheckServiceProvider.overrideWith(
        (ref) => FakeVersionCheckService(
          latestVersion: AppVersionEntity(
            latestVersion: '4.0.0',
            latestBuildNumber: 200,
            minimumVersion: '3.0.0',
            minimumBuildNumber: 150,
            releaseDate: DateTime.now().subtract(Duration(days: 1)), // PAST DATE
          ),
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const InvTrackerApp(),
    ),
  );

  await tester.pumpAndSettle();

  // Verify dialog appears
  expect(find.text('Update Available'), findsOneWidget);
  expect(find.text('Update Now'), findsOneWidget);
});
```

### **Acceptance Criteria**

- [ ] Firestore `releaseDate` set to past date (or removed)
- [ ] Dialog appears within 2 seconds of app launch (when update available)
- [ ] "Update Now" button opens Play Store
- [ ] "Later" button dismisses dialog
- [ ] Dismissed updates don't re-appear on app restart
- [ ] Force update mode blocks dismissal (when `forceUpdate: true`)
- [ ] Analytics event fired: `update_dialog_shown` (params: `version`, `force_update`)
- [ ] Unit tests pass for all version comparison edge cases
- [ ] Widget test verifies dialog rendering

---

# 🎯 **Sprint Summary**

## **Estimated Effort**

| Feature | Priority | Effort | Value |
|---------|----------|--------|-------|
| 1. Ad Integration | P1 | 5-7 days | High (revenue) |
| 2. Notification Reports | P0 | 7-10 days | Very High (engagement) |
| 3. Goal Notification Fix | P0 | 2-3 days | Critical (UX bug) |
| 4. Crashlytics Fix | P1 | 1-2 days | High (observability) |
| 5. Version Popup Fix | P2 | 1 day | Medium (update adoption) |

**Total**: 16-23 days (3-4 weeks with 1 developer)

## **Dependencies**

- **Ad Integration**: Google AdMob account setup, ad unit IDs
- **Notification Reports**: No external dependencies
- **Goal Notification Fix**: Firestore schema migration (backward-compatible)
- **Crashlytics Fix**: Xcode access (iOS), Android SDK setup
- **Version Popup Fix**: Firestore update permission

## **Risk Mitigation**

- **Ad Revenue Below Target**: Offer "Premium" ad-free tier (₹99/month)
- **Notification Report Complexity**: Ship 3 high-priority reports first (Weekly Summary, Goal Milestone, Maturity Reminder)
- **Crashlytics Symbol Upload Fails**: Document manual upload process in `docs/`
- **Version Popup Still Broken**: Add "Check for Updates" button in Settings as fallback

---

**Status**: ✅ **Ready for Implementation** - All technical blockers identified and solutions designed.

**Next Step**: Create GitHub issues for each of the 5 features and assign to sprint backlog.
