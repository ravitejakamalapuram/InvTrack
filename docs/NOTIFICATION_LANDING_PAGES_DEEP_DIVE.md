# 2️⃣ Notification Landing Pages - Deep Dive

**Branch**: `feature/notification-landing-pages`  
**Created**: 2026-04-18  
**Status**: 🚧 In Progress  

---

## 📋 **Problem Statement**

**Current Behavior**:
When users tap notifications, they land on **generic screens**:
- Weekly Summary → Overview (home screen)
- Maturity Reminder → InvestmentDetailScreen
- Goal Milestone → GoalDetailsScreen

**Expected Behavior**:
Each notification should route to a **specialized report screen** with:
- Contextual data specific to that notification
- Charts/visualizations
- Action buttons
- Explanation of why the notification was sent

**User Impact**:
- 📉 Low engagement: Users tap notification expecting insights, get generic screen
- 📉 Confusion: "Why did I get this notification?"
- 📉 Missed opportunities: No clear action to take

---

## 🎯 **Solution: 11 Specialized Report Screens**

Each of InvTrack's 11 notification types gets a dedicated report screen:

| # | Notification Type | Current Navigation | New Report Screen |
|---|-------------------|-------------------|-------------------|
| 1 | Weekly Summary | Overview | `WeeklySummaryReportScreen` |
| 2 | Monthly Summary | Overview | `MonthlySummaryReportScreen` |
| 3 | Maturity Reminder | InvestmentDetailScreen | `MaturityReportScreen` |
| 4 | Income Alert | AddTransactionScreen | `IncomeReportScreen` |
| 5 | Milestone | InvestmentDetailScreen | `MilestoneReportScreen` |
| 6 | Goal Milestone | GoalDetailsScreen | `GoalMilestoneReportScreen` |
| 7 | Goal At-Risk | GoalDetailsScreen | `GoalAtRiskReportScreen` |
| 8 | Goal Stale | GoalDetailsScreen | `GoalStaleReportScreen` |
| 9 | Risk Alert | Overview | `RiskAlertReportScreen` |
| 10 | Idle Alert | InvestmentDetailScreen | `IdleAlertReportScreen` |
| 11 | FY Summary | Overview | `FYSummaryReportScreen` |

---

## 🏗️ **Architecture Design**

### **Deep Linking Flow**

```text
User taps notification
        ↓
NotificationPayload.parse("weekly_summary")
        ↓
NotificationNavigator.handleNotificationTap()
        ↓
_navigateToWeeklySummaryReport()
        ↓
GoRouter: context.push('/reports/weekly')
        ↓
WeeklySummaryReportScreen renders
        ↓
Fetches data: investments, cashflows from last 7 days
        ↓
Displays: Bar chart, metrics, actions
```

### **File Structure**

```text
lib/features/notifications/
├── domain/
│   ├── entities/
│   │   ├── weekly_summary_data.dart
│   │   ├── monthly_summary_data.dart
│   │   └── ...
│   └── services/
│       └── notification_report_service.dart
├── data/
│   └── services/
│       └── notification_report_service_impl.dart
└── presentation/
    ├── screens/
    │   ├── weekly_summary_report_screen.dart
    │   ├── monthly_summary_report_screen.dart
    │   ├── maturity_report_screen.dart
    │   ├── income_report_screen.dart
    │   ├── milestone_report_screen.dart
    │   ├── goal_milestone_report_screen.dart
    │   ├── goal_at_risk_report_screen.dart
    │   ├── goal_stale_report_screen.dart
    │   ├── risk_alert_report_screen.dart
    │   ├── idle_alert_report_screen.dart
    │   └── fy_summary_report_screen.dart
    ├── widgets/
    │   ├── report_header.dart
    │   ├── report_metric_card.dart
    │   ├── report_chart.dart
    │   └── report_action_button.dart
    └── providers/
        ├── weekly_summary_provider.dart
        ├── monthly_summary_provider.dart
        └── ...
```

---

## 📊 **Report Screen UI Template**

All report screens follow a consistent structure:

```dart
class [NotificationType]ReportScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // 1. Header
      appBar: ReportHeader(
        icon: Icons.calendar_today_rounded,
        title: 'Weekly Summary',
        subtitle: 'Apr 12-18, 2026',
      ),
      
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 2. Key Metrics (2-4 cards)
            ReportMetricCard(
              label: '5 investments tracked',
              value: '5',
              trend: '+2 from last week',
            ),
            
            // 3. Data Visualization
            ReportChart(
              title: 'Weekly Cashflows',
              data: weeklyData,
              chartType: ChartType.bar,
            ),
            
            // 4. Contextual Help
            InfoCard(
              message: 'We send weekly summaries every Sunday at 9 AM to keep you on track.',
            ),
            
            // 5. Action Buttons
            ReportActionButton(
              label: 'View All Investments',
              onPressed: () => context.push('/investments'),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🔧 **Implementation Phases**

### **Phase 1: Foundation (Days 1-2)**

✅ Tasks:
- [ ] Create feature folder structure
- [ ] Add new `NotificationPayloadType` enum values
- [ ] Update `NotificationPayload.parse()` for report types
- [ ] Create reusable report widgets
- [ ] Add GoRouter routes for all 11 reports

### **Phase 2: High-Priority Reports (Days 3-5)**

Implement the 3 most-used notifications first:
- [ ] Weekly Summary Report
- [ ] Goal Milestone Report
- [ ] Maturity Reminder Report

### **Phase 3: Medium-Priority Reports (Days 6-7)**

- [ ] Monthly Summary Report
- [ ] Income Alert Report
- [ ] Milestone Report (Investment)

### **Phase 4: Low-Priority Reports (Days 8-9)**

- [ ] Goal At-Risk Report
- [ ] Goal Stale Report
- [ ] Risk Alert Report
- [ ] Idle Alert Report
- [ ] FY Summary Report

### **Phase 5: Testing & Polish (Day 10)**

- [ ] Integration testing
- [ ] Analytics events
- [ ] Localization
- [ ] Performance optimization

---

## 📐 **Technical Specifications**

### **GoRouter Route Definitions**

File: `lib/core/router/app_router.dart`

```dart
// Add inside routes array
GoRoute(
  path: '/reports/weekly',
  builder: (context, state) => const WeeklySummaryReportScreen(),
),
GoRoute(
  path: '/reports/monthly',
  builder: (context, state) => const MonthlySummaryReportScreen(),
),
GoRoute(
  path: '/reports/maturity/:investmentId',
  builder: (context, state) {
    final investmentId = state.pathParameters['investmentId']!;
    final daysToMaturity = int.tryParse(
      state.uri.queryParameters['daysToMaturity'] ?? '0',
    ) ?? 0;
    return MaturityReportScreen(
      investmentId: investmentId,
      daysToMaturity: daysToMaturity,
    );
  },
),
// ... 8 more routes
```

---

**Status**: ✅ Foundation planned - Ready for implementation starting Phase 1
