# InvTrack Feature & Bug Planning

**Created:** 2026-04-22  
**Status:** Planning Phase  
**Execution Strategy:** Bugs first (PR), then Features (separate PRs)

---

## 🐛 BUGS (Priority 1 - Execute First)

### **BUG-1: Goal Notifications Spamming on Cashflow Addition**

**Issue:** Goal milestone notifications trigger on EVERY cashflow addition, even when goal is already at 100%

**Root Cause:**
- `lib/features/investment/presentation/providers/investment_notifier.dart:825-841`
- Method `_checkGoalMilestones()` is called after EVERY cashflow addition
- No check if milestone was ALREADY shown for that goal
- Milestone tracking uses `isGoalMilestoneShown()` but the logic re-triggers on every progress recalculation

**Fix Strategy:**
1. ✅ Milestone tracking already exists in `GoalNotificationHandler.checkAndShowGoalMilestone()`
2. ❌ Issue: The method checks milestones but triggers on EVERY call when goal >= 100%
3. **Solution:** Add additional guard to prevent re-showing 100% milestone if already achieved
4. **Files to modify:**
   - `lib/core/notifications/handlers/goal_notification_handler.dart` (line 54-64)
   - Add check: Skip if goal >= 100% AND 100% milestone already shown

**Test Plan:**
- Create goal with $10,000 target
- Add cashflows to reach 50% → verify notification shows once
- Add more cashflows to reach 100% → verify notification shows once
- Add MORE cashflows (goal now at 120%) → verify NO NEW notifications
- Verify milestone notifications appear ONLY at 25%, 50%, 75%, 100% (once each)

---

### **BUG-2: Crashlytics Not Working**

**Issue:** Crash analytics not reporting errors to Firebase Console

**Diagnosis Checklist:**
1. ✅ Initialization verified in `lib/main.dart:77-78` - CrashlyticsService initialized
2. ✅ Error handler setup in `lib/core/analytics/crashlytics_service.dart:22-38`
3. ⚠️ **Likely Issue:** Crashlytics disabled in debug mode (line 24)
   - `await _crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);`
   - This means crashlytics ONLY works in **release builds**
4. ⚠️ **Possible Issue:** No test crashes triggered in production

**Fix Strategy:**
1. Verify Firebase Crashlytics setup in Firebase Console
2. Check if app is built in release mode for testing: `flutter build apk --release`
3. Add debug flag to optionally enable Crashlytics in debug mode for testing
4. Create test crash button in Settings > Developer Options
5. Verify `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are present

**Files to check:**
- `lib/core/analytics/crashlytics_service.dart:22-38`
- `android/app/google-services.json` (must exist)
- `ios/Runner/GoogleService-Info.plist` (must exist)
- Firebase Console: https://console.firebase.google.com/project/invtracker-b19d1/crashlytics

**Test Plan:**
- Build release APK: `flutter build apk --release`
- Install on device and trigger test crash
- Verify crash appears in Firebase Console within 5 minutes
- Add Settings screen toggle: "Enable Crashlytics in Debug Mode" for easier testing

---

### **BUG-3: New Version Popup Not Showing**

**Issue:** Update notification dialog doesn't appear when new version is available

**Root Cause Analysis:**
- `lib/features/app_update/presentation/widgets/version_check_initializer.dart:44-66`
- Version check happens 2 seconds after app launch
- Checks Firestore document: `app_config/version_info`
- Requires `releaseDate` to be null or past for popup to show

**Likely Issues:**
1. ❌ Firestore document `app_config/version_info` doesn't exist or has wrong structure
2. ❌ `releaseDate` field is set to future date (prevents popup until that date)
3. ❌ Version check network timeout (10 seconds) - fails silently
4. ❌ Navigator not ready when dialog tries to show

**Fix Strategy:**
1. **Verify Firestore Document:**
   - Collection: `app_config`
   - Document: `version_info`
   - Required fields:
     ```json
     {
       "latestVersion": "3.54.5",
       "latestBuildNumber": 60,
       "minimumVersion": "3.50.0",
       "minimumBuildNumber": 55,
       "forceUpdate": false,
       "updateMessage": "New features available!",
       "whatsNew": "- Multi-currency support\n- Goal tracking\n- Performance improvements",
       "downloadUrl": "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker",
       "releaseDate": null
     }
     ```
   - **CRITICAL:** `releaseDate` must be `null` or past date
   - **CRITICAL:** `latestBuildNumber` must be > current app build number

2. **Add Debug Logging:**
   - Add logs in `VersionCheckInitializer._checkForUpdates()` to trace execution
   - Log when version check starts, completes, and when dialog should show
   - Log version state: `hasUpdate`, `shouldShowUpdateDialog`, `requiresForceUpdate`

3. **Add Manual Trigger:**
   - Add "Check for Updates" button in Settings screen
   - Show version check result in a debug dialog (current version, latest version, update available)

**Files to modify:**
- `lib/features/app_update/presentation/widgets/version_check_initializer.dart`
- `lib/features/app_update/data/services/version_check_service.dart`
- `lib/features/settings/presentation/screens/settings_screen.dart` (add manual check button)

**Test Plan:**
1. Create Firestore document `app_config/version_info` with test data
2. Set `latestBuildNumber` higher than current app build
3. Set `releaseDate` to `null`
4. Launch app → verify dialog shows after 2 seconds
5. Tap "Later" → verify dialog dismissed
6. Re-launch app → verify dialog shows again (unless user tapped "Later")
7. Test "Force Update" scenario (set `forceUpdate: true`, `minimumBuildNumber` higher than current)

---

## ✨ FEATURES (Priority 2 - Execute After Bugs)

### **FEATURE-1: Ad Integration (Monetization)**

**Status:** ✅ Code already exists in `docs/AD_INTEGRATION_SUMMARY.md`

**Implementation Plan:**
1. ✅ Ad infrastructure already built:
   - `lib/core/ads/ad_service.dart` (150 lines)
   - `lib/core/ads/ad_provider.dart` (125 lines)
   - `lib/core/widgets/native_ad_widget.dart` (150 lines)
   - Ad placements: Investment List, Portfolio Health, Goals

2. **Remaining Tasks:**
   - [ ] Create AdMob account at https://admob.google.com
   - [ ] Add app (Android + iOS) to AdMob
   - [ ] Create 3 native ad units (Investment List, Portfolio Health, Goals)
   - [ ] Copy ad unit IDs and replace test IDs in `ad_service.dart`
   - [ ] Configure Android: Add `APPLICATION_ID` to `AndroidManifest.xml`
   - [ ] Configure iOS: Add `GADApplicationIdentifier` to `Info.plist`
   - [ ] Test ads in debug mode (test IDs)
   - [ ] Test ads in release mode (real IDs)
   - [ ] Monitor ad revenue in AdMob dashboard

**Files to modify:**
- `lib/core/ads/ad_service.dart` (replace test ad unit IDs)
- `android/app/src/main/AndroidManifest.xml` (add AdMob app ID)
- `ios/Runner/Info.plist` (add AdMob app ID)
- `lib/features/investment/presentation/screens/investment_list_screen.dart` (integrate NativeAdWidget)
- `lib/features/portfolio_health/presentation/screens/portfolio_health_details_screen.dart` (integrate NativeAdWidget)
- `lib/features/goals/presentation/screens/goals_screen.dart` (integrate NativeAdWidget)

**Dependencies:**
- Already added: `google_mobile_ads: ^5.2.0` in `pubspec.yaml`

**Analytics Events:**
- Track: `ad_impression`, `ad_click`, `ad_failed_to_load`
- Already implemented in `lib/core/ads/ad_service.dart`

**Test Plan:**
1. Debug mode: Verify test ads load and display correctly
2. Release mode: Verify real ads load after AdMob approval
3. Verify ads respect privacy mode (no data leakage)
4. Test ad click → verify opens browser
5. Monitor AdMob dashboard for impressions and revenue

---

### **FEATURE-2: Notification Report Pages**

**Problem:** Notifications navigate to generic screens (overview, investment detail, goal detail)
**Goal:** Create dedicated summary/report screens for each notification type

**Implementation Plan:**

#### **2.1 Weekly Summary Report Screen**

**Payload:** `weekly_summary` → Navigate to `/reports/weekly`

**Content:**
- Date range: Last 7 days (Monday - Sunday)
- Total cashflows added this week (INVEST, RETURN, INCOME, FEE)
- Net position change: `(RETURN + INCOME) - (INVEST + FEE)`
- Top performing investment (by XIRR)
- Total income received this week
- New investments created this week
- Investments maturing next week (preview)
- Chart: Daily cashflow trend (bar chart)

**Files to create:**
- `lib/features/reports/presentation/screens/weekly_summary_screen.dart`
- `lib/features/reports/presentation/widgets/weekly_summary_card.dart`
- `lib/features/reports/presentation/widgets/cashflow_timeline_chart.dart`
- `lib/features/reports/data/services/weekly_summary_service.dart`

**Navigation:**
- Update `lib/core/notifications/notification_payload.dart` to navigate to `/reports/weekly`
- Update `lib/core/router/app_router.dart` to add route

---

#### **2.2 Monthly Summary Report Screen**

**Payload:** `monthly_summary` → Navigate to `/reports/monthly`

**Content:**
- Date range: Last month (1st - last day)
- Total income received (sum of INCOME cashflows)
- Total TDS deducted (if tracked)
- Month-over-month comparison (vs previous month)
- Top income-generating investments
- Investment type breakdown (FD, P2P, Gold, etc.)
- Chart: Monthly income trend (last 12 months)
- Export button: Download as CSV/PDF

**Files to create:**
- `lib/features/reports/presentation/screens/monthly_summary_screen.dart`
- `lib/features/reports/presentation/widgets/monthly_income_chart.dart`
- `lib/features/reports/data/services/monthly_summary_service.dart`

---

#### **2.3 FY Summary Report Screen**

**Payload:** `fy_summary` → Navigate to `/reports/fy-summary`

**Content:**
- Financial Year: April 1 (previous year) - March 31 (current year)
- Total income (for tax filing)
- Total TDS deducted
- Top performer (investment with highest return)
- Total gains/losses (realized + unrealized)
- Investment type breakdown
- Export button: Tax-ready CSV/PDF report
- Chart: FY cashflow waterfall (invested vs returned)

**Files to create:**
- `lib/features/reports/presentation/screens/fy_summary_screen.dart`
- `lib/features/reports/presentation/widgets/fy_income_breakdown.dart`
- `lib/features/reports/data/services/fy_summary_service.dart`

---

#### **2.4 Goal Progress Report Screen**

**Payload:** `goal_milestone:{goalId}:{milestonePercent}` → Navigate to `/reports/goal/{goalId}`

**Content:**
- Goal name, icon, target amount
- Current progress (with celebration animation if 100%)
- Milestone history: 25%, 50%, 75%, 100% with dates
- Linked investments list (with current values)
- Progress chart: Timeline showing growth over time
- Projected completion date (if target date not set)
- "Add Investment" button to continue progress
- Share button: Share milestone achievement

**Files to create:**
- `lib/features/reports/presentation/screens/goal_progress_report_screen.dart`
- `lib/features/reports/presentation/widgets/goal_milestone_timeline.dart`
- `lib/features/reports/presentation/widgets/goal_progress_chart.dart`

**Special Features:**
- Confetti animation when viewing 100% milestone
- Social share: "I achieved my {goalName} goal! 🎉" with privacy-masked amount

---

#### **2.5 Investment Maturity Report Screen**

**Payload:** `maturity_reminder:{investmentId}:{days}` → Navigate to `/reports/maturity/{investmentId}`

**Content:**
- Investment name, type, maturity date
- Days until maturity (countdown)
- Current value (with XIRR, CAGR, returns)
- Total invested vs total returned
- Maturity options checklist:
  - [ ] Renew investment (same terms)
  - [ ] Withdraw funds (mark as closed)
  - [ ] Reinvest in different instrument
  - [ ] Extend maturity date (if allowed)
- Maturity reminder: 7 days, 3 days, 1 day before
- Action buttons: "Renew", "Close Investment", "Extend"

**Files to create:**
- `lib/features/reports/presentation/screens/investment_maturity_screen.dart`
- `lib/features/reports/presentation/widgets/maturity_countdown_card.dart`
- `lib/features/reports/presentation/widgets/maturity_action_buttons.dart`

---

#### **2.6 Risk Alert Report Screen**

**Payload:** `risk_alert:{alertType}` → Navigate to `/reports/risk-alert`

**Content:**
- Alert type: Concentration risk, idle investment, underperformance
- Risk score (0-100, higher = more risk)
- Affected investments list
- Recommendations:
  - Diversify portfolio (if concentration risk)
  - Add cashflows (if idle investment)
  - Review performance (if underperformance)
- Action buttons: "View Investment", "Ignore Alert"

**Files to create:**
- `lib/features/reports/presentation/screens/risk_alert_screen.dart`
- `lib/features/reports/presentation/widgets/risk_score_gauge.dart`
- `lib/features/reports/data/services/risk_analysis_service.dart`

---

### **Implementation Checklist for Notification Reports**

**Phase 1: Infrastructure (1-2 days)**
- [ ] Create `lib/features/reports` folder structure
- [ ] Create base report screen widget with common layout
- [ ] Update `lib/core/router/app_router.dart` to add report routes
- [ ] Update `lib/core/notifications/notification_payload.dart` to parse report payloads
- [ ] Update `lib/core/notifications/notification_navigator.dart` to navigate to reports

**Phase 2: Weekly Summary (1 day)**
- [ ] Create `WeeklySummaryService` to aggregate weekly data
- [ ] Create `WeeklySummaryScreen` with UI
- [ ] Add cashflow timeline chart
- [ ] Test navigation from notification

**Phase 3: Monthly Summary (1 day)**
- [ ] Create `MonthlySummaryService` to aggregate monthly data
- [ ] Create `MonthlySummaryScreen` with UI
- [ ] Add monthly income chart
- [ ] Add CSV/PDF export

**Phase 4: FY Summary (1 day)**
- [ ] Create `FYSummaryService` to aggregate FY data
- [ ] Create `FYSummaryScreen` with UI
- [ ] Add FY cashflow waterfall chart
- [ ] Add tax-ready export

**Phase 5: Goal Progress Report (1 day)**
- [ ] Create `GoalProgressReportScreen` with milestone timeline
- [ ] Add confetti animation for 100% milestone
- [ ] Add social share feature (privacy-masked)

**Phase 6: Investment Maturity Report (1 day)**
- [ ] Create `InvestmentMaturityScreen` with countdown
- [ ] Add maturity action buttons (renew, close, extend)
- [ ] Integrate with investment lifecycle

**Phase 7: Risk Alert Report (1 day)**
- [ ] Create `RiskAlertScreen` with risk score gauge
- [ ] Create `RiskAnalysisService` to calculate risk
- [ ] Add affected investments list

**Phase 8: Testing & Polish (1 day)**
- [ ] Test all notification → report navigations
- [ ] Verify data accuracy in all reports
- [ ] Add localization for all report strings
- [ ] Add analytics events for report views
- [ ] Test privacy mode in all reports
- [ ] Add Help & FAQ entries for reports

---

## 📋 EXECUTION PLAN

### **Sprint 1: Bug Fixes (3-4 days)**

**PR-1: Fix Goal Notification Spamming**
- [ ] Modify `goal_notification_handler.dart` to add 100% milestone guard
- [ ] Add unit tests for milestone notification logic
- [ ] Manual test: Add cashflows and verify notifications
- [ ] Merge to main

**PR-2: Fix Crashlytics Not Working**
- [ ] Verify Firebase Crashlytics setup in Firebase Console
- [ ] Add debug flag to enable Crashlytics in debug mode
- [ ] Add test crash button in Settings > Developer Options
- [ ] Build release APK and test crash reporting
- [ ] Merge to main

**PR-3: Fix New Version Popup**
- [ ] Create Firestore document `app_config/version_info` with correct structure
- [ ] Add debug logging in `VersionCheckInitializer`
- [ ] Add "Check for Updates" button in Settings
- [ ] Test manual version check
- [ ] Test automatic version check on app launch
- [ ] Merge to main

---

### **Sprint 2: Ad Integration (2-3 days)**

**PR-4: AdMob Setup & Integration**
- [ ] Create AdMob account and add app
- [ ] Create 3 native ad units
- [ ] Update ad unit IDs in `ad_service.dart`
- [ ] Configure Android `AndroidManifest.xml`
- [ ] Configure iOS `Info.plist`
- [ ] Integrate NativeAdWidget in Investment List screen
- [ ] Integrate NativeAdWidget in Portfolio Health screen
- [ ] Integrate NativeAdWidget in Goals screen
- [ ] Test ads in debug mode (test IDs)
- [ ] Test ads in release mode (real IDs)
- [ ] Monitor AdMob dashboard for impressions
- [ ] Merge to main

---

### **Sprint 3: Notification Report Pages (7-8 days)**

**PR-5: Reports Infrastructure**
- [ ] Create `lib/features/reports` folder structure
- [ ] Update router and notification navigator
- [ ] Create base report screen widget
- [ ] Merge to main

**PR-6: Weekly & Monthly Summary Reports**
- [ ] Implement WeeklySummaryService & Screen
- [ ] Implement MonthlySummaryService & Screen
- [ ] Add charts and export features
- [ ] Test navigation from notifications
- [ ] Merge to main

**PR-7: FY Summary & Goal Progress Reports**
- [ ] Implement FYSummaryService & Screen
- [ ] Implement GoalProgressReportScreen
- [ ] Add confetti animation and social share
- [ ] Test navigation from notifications
- [ ] Merge to main

**PR-8: Maturity & Risk Alert Reports**
- [ ] Implement InvestmentMaturityScreen
- [ ] Implement RiskAlertScreen
- [ ] Add action buttons and risk analysis
- [ ] Test navigation from notifications
- [ ] Merge to main

**PR-9: Reports Testing & Polish**
- [ ] Add localization for all report strings
- [ ] Add analytics events
- [ ] Test privacy mode
- [ ] Update Help & FAQ
- [ ] Merge to main

---

## 📊 TIMELINE ESTIMATE

- **Sprint 1 (Bugs):** 3-4 days → PRs 1, 2, 3
- **Sprint 2 (Ads):** 2-3 days → PR 4
- **Sprint 3 (Reports):** 7-8 days → PRs 5, 6, 7, 8, 9

**Total:** ~12-15 days (working evenings/weekends)
