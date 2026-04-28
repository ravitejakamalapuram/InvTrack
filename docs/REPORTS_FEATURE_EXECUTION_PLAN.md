# InvTrack Reports Feature - Execution Plan

> **Strategic Product Plan for Dynamic & Static Reports System**

**Document Version:** 1.1
**Created:** 2026-04-27
**Last Updated:** 2026-04-28
**Owner:** Product Team
**Status:** In Development (Phase 1 & 2 Active)

---

## 🎯 Implementation Status

### ✅ Completed (Phase 1 Foundation + Phase 2.1)

#### Infrastructure ✅
- ✅ Created complete `lib/features/reports/` folder structure
  - `domain/entities/` - Report entity definitions
  - `data/services/` - Report generation services
  - `presentation/{providers,screens,widgets}/` - UI layer
- ✅ Integrated Reports tab into main navigation (`HomeShellScreen`)
- ✅ Created `ReportsHomeScreen` with all 8 report types displayed
- ✅ Built reusable UI components:
  - `BaseReportScreen` - Consistent scaffold for all reports
  - `ReportStatCard` - KPI display widget
  - `DailyCashflowChart` - Chart visualization using `fl_chart`

#### Weekly Summary Report (P0) ✅ COMPLETE
- ✅ `WeeklySummary` entity with daily cashflow data
- ✅ `WeeklySummaryService` with aggregation logic
- ✅ `weeklySummaryProvider` (Riverpod)
- ✅ `WeeklySummaryScreen` with:
  - Summary cards (Total Invested, Returns, Income, Net Position)
  - Daily cashflow trend chart
  - Top performer display
  - New investments list
  - Upcoming maturities
- ✅ Privacy masking integration
- ✅ Multi-currency support via locale-aware formatting
- ✅ Route: `/reports/weekly`

#### Monthly Income Report (P0) ✅ COMPLETE
- ✅ `MonthlyIncomeReport` entity with income breakdown
- ✅ `MonthlyIncomeService` for monthly cashflow aggregation
- ✅ `monthlyIncomeProvider` (current & custom period)
- ✅ `MonthlyIncomeScreen` with:
  - Summary cards (Total Income, Net Cashflow, Invested, Returns)
  - Income breakdown by type (Dividend, Interest, Rent, etc.)
  - Top income-generating investments
  - All income transactions list
- ✅ Route: `/reports/monthly`

#### FY Report (P0) ✅ COMPLETE
- ✅ `FYReport` entity with comprehensive FY data model (Apr-Mar)
- ✅ `FYReportService` with monthly breakdown, XIRR, capital gains
- ✅ `fyReportProvider` (Riverpod)
- ✅ `FYReportScreen` with:
  - Summary cards (Invested, Returned, Net, XIRR)
  - Monthly breakdown with trend visualization
  - Capital gains summary (short-term vs long-term)
  - Top performers by returns and XIRR
- ✅ Route: `/reports/fy`

#### Performance Report (P0) ✅ COMPLETE
- ✅ `PerformanceReport` entity with performance analysis
- ✅ `PerformanceReportService` with top/bottom performers
- ✅ `performanceReportProvider` (Riverpod)
- ✅ `PerformanceReportScreen` with:
  - Summary cards (Avg XIRR, Median XIRR, Profitable count)
  - Top 5 performers list
  - Bottom 5 performers list
  - Recent milestone achievements
- ✅ Route: `/reports/performance`

#### Goal Progress Report (P0) ✅ COMPLETE
- ✅ `GoalProgressReport` entity with goal status tracking
- ✅ `GoalProgressService` for progress analysis
- ✅ `goalProgressReportProvider` (Riverpod)
- ✅ `GoalProgressScreen` with:
  - Summary cards (Total Goals, Avg Progress, On Track, At Risk)
  - Achieved goals section
  - On-track goals with progress bars
  - At-risk goals with warning indicators
- ✅ Route: `/reports/goals`

#### Maturity Calendar (P1) ✅ COMPLETE
- ✅ `MaturityCalendarReport` entity with maturity tracking
- ✅ `MaturityCalendarService` for maturity timeline generation
- ✅ `maturityCalendarReportProvider` (Riverpod)
- ✅ `MaturityCalendarScreen` with:
  - Summary cards (Total w/ Maturity, Next 30 Days, Next 90 Days)
  - Upcoming 30 days section with urgency indicators
  - Next 90 days timeline
  - Beyond 90 days list
  - Color-coded urgency levels (Critical, Warning, Normal, Low)
- ✅ Route: `/reports/maturity`

### 📊 Progress Metrics
- **Reports Completed:** 6/8 (75%)
- **High Priority (P0) Completed:** 5/5 (100%!)
- **Medium Priority (P1) Completed:** 1/3 (33%)
- **Code Quality:** ✅ Zero analyzer errors
- **Architecture Compliance:** ✅ Clean layer boundaries maintained
- **Privacy Compliance:** ✅ All amounts wrapped in PrivacyMask
- **Multi-Currency:** ✅ Locale-aware formatting implemented

### 🎯 Next Priority Tasks
1. **Export Services (P0)** - PDF & CSV generation (Complex feature, requires significant implementation)
2. **Action Required (P1)** - Action items dashboard (NEXT)
3. **Portfolio Health (P1)** - Health assessment integration

---

## Executive Summary

This document outlines the execution plan for building a comprehensive **Reports Section** in InvTrack. Reports will provide users with actionable insights derived from existing notification triggers and investment analytics. The system will support both **dynamic reports** (generated on-demand) and **static reports** (pre-generated snapshots), aligned with InvTrack's notification architecture.

### Key Objectives

1. **Leverage Existing Notifications**: Transform 13 notification types into 8 actionable report templates
2. **Dynamic + Static Hybrid**: Use dynamic reports for real-time insights, static reports for historical comparisons
3. **Rich Visualizations**: Integrate charts, trends, and KPIs using existing chart infrastructure
4. **Export & Share**: PDF/CSV export for tax filing, advisor sharing, and record-keeping

---

## Table of Contents

1. [Notification → Report Mapping](#1-notification--report-mapping)
2. [Report Template Definitions](#2-report-template-definitions)
3. [Architecture Design](#3-architecture-design)
4. [Implementation Roadmap](#4-implementation-roadmap)
5. [UI/UX Specifications](#5-uiux-specifications)
6. [Data Requirements](#6-data-requirements)
7. [Testing Strategy](#7-testing-strategy)

---

## 1. Notification → Report Mapping

### Current Notifications (13 Types)

Based on `lib/core/notifications/notification_service.dart`:

#### **A. Scheduled Notifications (4)**
| # | Notification | Frequency | Report Potential | Priority |
|---|--------------|-----------|------------------|----------|
| 1 | Weekly Summary | Every Sunday 9 AM | ✅ **High** - Core report | P0 |
| 2 | Monthly Summary | Last day of month 6 PM | ✅ **High** - Core report | P0 |
| 3 | FY Summary | April 1st 9 AM | ✅ **High** - Tax planning | P0 |
| 4 | Tax Reminder | March 15th 9 AM | ✅ **Medium** - Tax optimization | P1 |

#### **B. Investment Notifications (3)**
| # | Notification | Trigger | Report Potential | Priority |
|---|--------------|---------|------------------|----------|
| 5 | Maturity Reminder | 7 days before maturity | ✅ **Medium** - Reinvestment planning | P1 |
| 6 | Income Alert | When dividend/interest recorded | ⚠️ **Low** - Part of monthly report | P2 |
| 7 | Milestone | 10%, 25%, 50%, 100% gain | ✅ **High** - Performance tracking | P0 |

#### **C. Goal Notifications (3)**
| # | Notification | Trigger | Report Potential | Priority |
|---|--------------|---------|------------------|----------|
| 8 | Goal Milestone | 25%, 50%, 75%, 100% progress | ✅ **High** - Goal tracking | P0 |
| 9 | Goal At-Risk Alert | Projected to miss deadline | ✅ **High** - Action required | P0 |
| 10 | Goal Stale Alert | No activity for 90 days | ⚠️ **Low** - Part of action report | P2 |

#### **D. Alert Notifications (3)**
| # | Notification | Trigger | Report Potential | Priority |
|---|--------------|---------|------------------|----------|
| 11 | Risk Alert | Investment underperforms | ✅ **Medium** - Portfolio health | P1 |
| 12 | Idle Investment | No transactions for 90 days | ⚠️ **Low** - Part of action report | P2 |
| 13 | Weekly Check-In | Onboarding nudges | ❌ **None** - Not report-worthy | - |

### Report Consolidation Strategy

**8 Core Reports** (derived from 13 notifications):

| Report Name | Source Notifications | Type | Reason |
|-------------|---------------------|------|--------|
| **1. Weekly Investment Summary** | Weekly Summary | Dynamic | Real-time weekly insights |
| **2. Monthly Income Report** | Monthly Summary, Income Alert | Static + Dynamic | Tax filing, record-keeping |
| **3. Financial Year Report** | FY Summary, Tax Reminder | Static | Annual tax planning |
| **4. Investment Performance Report** | Milestone, Risk Alert | Dynamic | Track winners & losers |
| **5. Goal Progress Report** | Goal Milestone, Goal At-Risk | Dynamic | Track goal health |
| **6. Maturity Calendar Report** | Maturity Reminder | Dynamic | Reinvestment planning |
| **7. Action Required Report** | Idle Investment, Goal Stale | Dynamic | Pending tasks |
| **8. Portfolio Health Report** | Risk Alert, Diversification | Dynamic | Overall health score |

---

## 2. Report Template Definitions

### 🔹 Report 1: Weekly Investment Summary

**Type:** Dynamic (generated on-demand)
**Purpose:** Quick weekly snapshot of investment activity
**User Story:** "As an investor, I want to see this week's cashflow activity and performance changes"

**Data Sources:**
- `lib/features/investment/presentation/providers/investment_stats_provider.dart` → Global stats
- `lib/features/investment/presentation/providers/investment_analytics_provider.dart` → Trends
- Cash flows filtered by `date >= lastMonday && date <= thisSunday`

**Key Metrics:**
| Metric | Calculation | Visualization |
|--------|-------------|---------------|
| Total Invested This Week | Sum of INVEST flows | Card + Trend |
| Total Returns This Week | Sum of RETURN + INCOME flows | Card + Trend |
| Net Position Change | `(RETURN + INCOME) - (INVEST + FEE)` | Card with +/- indicator |
| Top Performer | Investment with highest XIRR | Card with investment name |
| Total Income | Sum of INCOME flows | Card |
| New Investments | Count of investments created | List |
| Maturing Next Week | Investments with `maturityDate` in next 7 days | List |

**Charts:**
1. **Daily Cashflow Trend** (Bar Chart)
   - X-axis: Mon-Sun
   - Y-axis: Amount
   - Bars: INVEST (outflow, red), RETURN+INCOME (inflow, green)
   - Reuse: `MonthlyCashFlowTrend` from `overview_analytics.dart`

2. **Week-over-Week Comparison** (Comparison Card)
   - This week vs last week net position
   - Percentage change indicator
   - Reuse: `YoYComparisonCard` pattern

**UI Layout:**
```
┌─────────────────────────────────────┐
│ Weekly Summary (Apr 21 - Apr 27)   │
├─────────────────────────────────────┤
│ [Total Invested] [Total Returns]   │
│ [Net Position] [Top Performer]      │
├─────────────────────────────────────┤
│ Daily Cashflow Trend Chart          │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   │
├─────────────────────────────────────┤
│ Week-over-Week Comparison           │
│ This Week: +₹50,000 (+15%)          │
├─────────────────────────────────────┤
│ New Investments (2)                 │
│ • FD @ 8.5% - ₹100,000             │
│ • Gold Purchase - ₹25,000          │
├─────────────────────────────────────┤
│ Maturing Next Week (1)              │
│ • ICICI FD - ₹50,000 on Apr 30     │
└─────────────────────────────────────┘
```

---

### 🔹 Report 2: Monthly Income Report

**Type:** Static (snapshot) + Dynamic (on-demand)
**Purpose:** Track monthly income for tax filing and record-keeping
**User Story:** "As an investor, I need monthly income breakdown for ITR filing"

**Data Sources:**
- Cash flows filtered by `type == INCOME` and `date.month == selectedMonth`
- Investment entities for context (name, type)

**Key Metrics:**
| Metric | Calculation | Visualization |
|--------|-------------|---------------|
| Total Income | Sum of all INCOME flows | Hero card |
| Income by Type | Group by investment type | Pie chart |
| Income by Investment | Top 5 income generators | List |
| Average Monthly Income | Last 6 months average | Trend line |
| Tax Implications | TDS deducted (future) | Alert card |

**Charts:**
1. **Income by Type** (Pie/Donut Chart)
   - FD Interest, P2P Returns, Dividend, Gold Sale, etc.
   - Reuse: `TypeDistributionChart` pattern

2. **Monthly Income Trend** (Line Chart)
   - Last 12 months income
   - Show seasonality (e.g., March spike for FD interest)

**Static Storage:**
- **Why Static:** Tax records need immutable snapshots
- **When Generated:** Automatically on month-end (triggered by Monthly Summary notification)
- **Storage:** Firestore subcollection: `users/{userId}/monthlyReports/{YYYY-MM}`
- **Data Model:**
  ```dart
  class MonthlyIncomeReport {
    final String id; // "2024-03"
    final DateTime generatedAt;
    final double totalIncome;
    final Map<String, double> incomeByType; // {"FD": 5000, "P2P": 2000}
    final List<IncomeEntry> topInvestments; // Top 5
    final double averageMonthlyIncome; // Last 6 months
  }
  ```

**Export Options:**
- ✅ PDF (for ITR filing)
- ✅ CSV (for spreadsheet analysis)
- ✅ Share via email/WhatsApp

---

### 🔹 Report 3: Financial Year Report

**Type:** Static (snapshot)
**Purpose:** Annual tax planning and compliance
**User Story:** "As an investor, I need FY summary for 80C, capital gains, and ITR filing"

**Data Sources:**
- Cash flows filtered by FY period: `Apr 1, YYYY to Mar 31, YYYY+1`
- Investments created/matured in FY
- Goal progress as of Mar 31

**Key Metrics:**
| Metric | Calculation | Visualization |
|--------|-------------|---------------|
| Total Invested (FY) | Sum of INVEST flows | Card |
| Total Returns (FY) | Sum of RETURN + INCOME flows | Card |
| Net Gain/Loss | `TotalReturns - TotalInvested` | Card with +/- |
| XIRR (FY) | Portfolio XIRR for FY | Card |
| Short-term Gains | Investments held <3 years | Alert card |
| Long-term Gains | Investments held ≥3 years | Alert card |
| Tax Saving Investments | ELSS, PPF, etc. (future) | List |

**Charts:**
1. **Monthly Investment Trend** (Bar Chart)
   - 12 months (Apr to Mar)
   - Invested vs Returns

2. **Category-wise Returns** (Horizontal Bar Chart)
   - FD, P2P, Gold, etc.
   - Show absolute returns per category

**Static Storage:**
- **Why Static:** Tax records are immutable by law
- **When Generated:** Automatically on Apr 1st (triggered by FY Summary notification)
- **Storage:** Firestore subcollection: `users/{userId}/fyReports/{FY2023-24}`
- **Retention:** Permanent (7 years for tax compliance)

---

### 🔹 Report 4: Investment Performance Report

**Type:** Dynamic
**Purpose:** Track top performers and underperformers
**User Story:** "As an investor, I want to identify which investments are delivering best returns"

**Data Sources:**
- All active investments with XIRR calculation
- Investment stats (MOIC, absolute return)
- Historical milestones

**Key Metrics:**
| Metric | Calculation | Visualization |
|--------|-------------|---------------|
| Top 5 Performers | Sorted by XIRR descending | Ranked list |
| Bottom 5 Performers | Sorted by XIRR ascending | Ranked list |
| Milestone Achievements | 10%, 25%, 50%, 100% gains | Timeline |
| Average Portfolio XIRR | Weighted average XIRR | Card |
| Risk vs Return Matrix | Volatility vs XIRR | Scatter plot |

**Charts:**
1. **Performance Distribution** (Bar Chart)
   - All investments sorted by XIRR
   - Color-coded: Green (>10%), Yellow (5-10%), Red (<5%)

2. **Milestone Timeline** (Event Timeline)
   - Recent milestones achieved
   - Celebration badges (🎉 10%, 🏆 25%, 🚀 50%, 💎 100%)

**UI Features:**
- Tap investment → Navigate to investment details
- Filter by investment type (FD, P2P, Gold, etc.)
- Sort by: XIRR, MOIC, Absolute Return, Duration

---

### 🔹 Report 5: Goal Progress Report

**Type:** Dynamic
**Purpose:** Track goal health and required actions
**User Story:** "As an investor, I want to see if I'm on track to meet my financial goals"

**Data Sources:**
- `lib/features/goals/domain/entities/goal_progress.dart`
- Goal entities with target amount, deadline, current value
- Goal milestones and alerts

**Key Metrics:**
| Metric | Calculation | Visualization |
|--------|-------------|---------------|
| Goals on Track | Progress ≥ expected | List with ✅ |
| Goals at Risk | Progress < expected | List with ⚠️ |
| Goals Achieved | Progress = 100% | List with 🎉 |
| Average Progress | Mean of all goal progress % | Card |
| Projected Completion | Based on current rate | List |

**Charts:**
1. **Goal Progress Rings** (Multi-ring Chart)
   - One ring per goal
   - Color: Green (on track), Yellow (at risk), Red (critical)
   - Reuse: `FireProgressRing` from `fire_progress_ring.dart`

2. **Monthly Contribution Trend** (Line Chart)
   - Track monthly goal contributions
   - Show required vs actual contributions

**Alerts:**
- **Goal At-Risk:** "House Down Payment is 15% behind schedule. Increase monthly contribution by ₹5,000"
- **Goal Stale:** "Retirement Fund has no activity for 90 days. Last investment on Jan 15"

---

### 🔹 Report 6: Maturity Calendar Report

**Type:** Dynamic
**Purpose:** Plan reinvestments and avoid lapses
**User Story:** "As an investor, I want to see which investments are maturing soon"

**Data Sources:**
- Investments with `maturityDate` field
- Grouped by: Next 7 days, Next 30 days, Next 3 months

**Key Metrics:**
| Metric | Calculation | Visualization |
|--------|-------------|---------------|
| Maturing This Week | Count + total amount | Card |
| Maturing This Month | Count + total amount | Card |
| Maturing This Quarter | Count + total amount | Card |
| Total Maturity Value | Sum of all maturing amounts | Hero card |

**Calendar View:**
```
April 2024
─────────────────────────────────────
Mon Tue Wed Thu Fri Sat Sun
 1   2   3   4   5   6   7
                 🔔       💰
 8   9   10  11  12  13  14
            🔔
15  16  17  18  19  20  21
22  23  24  25  26  27  28
            💰  🔔
29  30
🔔 = Maturity date
💰 = Income payout
```

**List View:**
```
┌─────────────────────────────────────┐
│ Maturing This Week (3)              │
├─────────────────────────────────────┤
│ Apr 28 • ICICI FD • ₹50,000        │
│ Apr 30 • HDFC RD • ₹25,000         │
│ May 1  • P2P Loan #123 • ₹10,000   │
└─────────────────────────────────────┘
```

**Actions:**
- Tap investment → View details + Reinvestment options
- Set reminders (already exists via notifications)
- Mark as "Reinvested" or "Withdrawn"

---

### 🔹 Report 7: Action Required Report

**Type:** Dynamic
**Purpose:** Consolidated list of pending tasks
**User Story:** "As an investor, I want to see all actions I need to take"

**Data Sources:**
- Idle investments (no transactions for 90 days)
- Stale goals (no activity for 90 days)
- Maturing investments (within 7 days)
- Goals at risk

**Actions by Priority:**
| Priority | Action Type | Trigger | Example |
|----------|-------------|---------|---------|
| 🔴 High | Maturing Soon | <7 days to maturity | "ICICI FD matures in 3 days - Decide reinvestment" |
| 🟡 Medium | Goal At-Risk | Projected to miss deadline | "House Fund behind by 20% - Increase contribution" |
| 🟠 Low | Idle Investment | No activity for 90 days | "Gold investment has no transactions for 120 days" |
| 🟢 Info | Goal Stale | No activity for 90 days | "Education Fund has no activity for 100 days" |

**UI Layout:**
```
┌─────────────────────────────────────┐
│ Action Required (5)                 │
├─────────────────────────────────────┤
│ 🔴 ICICI FD matures in 3 days       │
│    ₹50,000 • Decide reinvestment    │
│    [View Details] [Snooze]          │
├─────────────────────────────────────┤
│ 🟡 House Fund behind schedule       │
│    60% complete, need 75%           │
│    [View Goal] [Add Investment]     │
└─────────────────────────────────────┘
```

---

### 🔹 Report 8: Portfolio Health Report

**Type:** Dynamic
**Purpose:** Overall portfolio health assessment
**User Story:** "As an investor, I want a health score for my entire portfolio"

**Data Sources:**
- `lib/features/portfolio_health/domain/services/portfolio_health_calculator.dart`
- All investments, goals, cash flows

**Key Metrics:**
| Metric | Calculation | Visualization |
|--------|-------------|---------------|
| Overall Score | Weighted average of 5 components | Progress ring (0-100) |
| Returns Performance | XIRR vs benchmark | Card with score |
| Diversification | Herfindahl index | Card with score |
| Liquidity | % maturing in 90 days | Card with score |
| Goal Alignment | % goals on track | Card with score |
| Action Readiness | % investments needing action | Card with score |

**Charts:**
1. **Health Score Breakdown** (Radar Chart)
   - 5 axes: Returns, Diversification, Liquidity, Goals, Actions
   - Show current vs ideal

2. **Score Trend** (Line Chart)
   - Last 6 months health score
   - Reuse: `HealthScoreTrendChart` from `portfolio_health_dashboard_card.dart`

**Existing Implementation:**
- ✅ Score calculation already exists in `portfolio_health_calculator.dart`
- ✅ Dashboard card already exists in `portfolio_health_dashboard_card.dart`
- 🔨 **New:** Expand into full report with historical trends and recommendations

---

## 3. Architecture Design

### 3.1 Feature Structure

```
lib/features/reports/
├── data/
│   ├── models/
│   │   ├── weekly_summary_model.dart
│   │   ├── monthly_income_report_model.dart
│   │   ├── fy_report_model.dart
│   │   └── report_metadata_model.dart
│   ├── repositories/
│   │   └── firestore_report_repository.dart
│   └── services/
│       ├── report_generation_service.dart        # Core report generation
│       ├── static_report_service.dart            # Static report snapshots
│       └── report_export_service.dart            # PDF/CSV export
├── domain/
│   ├── entities/
│   │   ├── weekly_summary.dart
│   │   ├── monthly_income_report.dart
│   │   ├── fy_report.dart
│   │   ├── investment_performance_report.dart
│   │   ├── goal_progress_report.dart
│   │   ├── maturity_calendar_report.dart
│   │   └── action_required_report.dart
│   └── repositories/
│       └── report_repository.dart
├── presentation/
│   ├── providers/
│   │   ├── report_providers.dart                 # Riverpod providers
│   │   └── report_export_providers.dart
│   ├── screens/
│   │   ├── reports_home_screen.dart              # Main reports list
│   │   ├── weekly_summary_screen.dart
│   │   ├── monthly_income_screen.dart
│   │   ├── fy_report_screen.dart
│   │   ├── investment_performance_screen.dart
│   │   ├── goal_progress_screen.dart
│   │   ├── maturity_calendar_screen.dart
│   │   └── action_required_screen.dart
│   └── widgets/
│       ├── report_card.dart                      # Reusable report card
│       ├── report_stat_card.dart
│       ├── report_chart_wrapper.dart
│       └── report_export_button.dart
```

---

### 3.2 Data Models

#### Static Report Storage Model
```dart
class StaticReportMetadata {
  final String id; // "monthly_2024_03" or "fy_2023_24"
  final ReportType type; // WEEKLY, MONTHLY, FY
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime generatedAt;
  final int version; // Schema version for migrations
  final Map<String, dynamic> data; // JSON blob
}
```

#### Dynamic Report Configuration
```dart
class ReportConfig {
  final ReportType type;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> filters; // Optional filters
}
```

### 3.3 Static vs Dynamic Decision Matrix

| Report | Type | Reason | Storage |
|--------|------|--------|---------|
| Weekly Summary | **Dynamic** | Data changes frequently, no compliance need | Cache only |
| Monthly Income | **Static** | Tax compliance, immutable historical record | Firestore |
| FY Report | **Static** | Tax compliance, legal requirement (7 years) | Firestore |
| Performance | **Dynamic** | Real-time XIRR changes daily | Cache only |
| Goal Progress | **Dynamic** | Goals updated frequently | Cache only |
| Maturity Calendar | **Dynamic** | Forward-looking, changes as dates approach | Cache only |
| Action Required | **Dynamic** | Real-time action items | Cache only |
| Portfolio Health | **Dynamic** | Score recalculated on every investment change | Cache only |

### 3.4 Firestore Schema (Static Reports)

```
users/{userId}/
  ├── monthlyReports/
  │   ├── 2024-01/
  │   │   ├── generatedAt: timestamp
  │   │   ├── totalIncome: 15000
  │   │   ├── incomeByType: {FD: 10000, P2P: 5000}
  │   │   ├── topInvestments: [{name, amount}...]
  │   │   └── version: 1
  │   ├── 2024-02/
  │   └── 2024-03/
  ├── fyReports/
  │   ├── FY2022-23/
  │   ├── FY2023-24/
  │   │   ├── generatedAt: timestamp
  │   │   ├── totalInvested: 500000
  │   │   ├── totalReturns: 550000
  │   │   ├── netGain: 50000
  │   │   ├── xirr: 0.12
  │   │   ├── monthlyBreakdown: [{month, invested, returns}...]
  │   │   └── version: 1
```

---

## 4. Implementation Roadmap

### Phase 1: Foundation (Week 1)

#### Sprint 1.1: Data Infrastructure
- [ ] Create `lib/features/reports/` folder structure
- [ ] Define domain entities for all 8 reports
- [ ] Implement `ReportRepository` interface
- [ ] Implement `FirestoreReportRepository`
- [ ] Add Firestore security rules for reports collection
- [ ] Add to `deleteUserData()` flow

#### Sprint 1.2: Core Services
- [ ] Implement `ReportGenerationService` with caching
- [ ] Implement `StaticReportService` for snapshots
- [ ] Create scheduled job for month-end static report generation
- [ ] Create scheduled job for FY-end static report generation

### Phase 2: Dynamic Reports (Week 2)

#### Sprint 2.1: Weekly Summary
- [ ] Implement `WeeklySummary` entity
- [ ] Create `weeklySummaryProvider` (Riverpod)
- [ ] Build `WeeklySummaryScreen` with charts
- [ ] Add navigation from notifications

#### Sprint 2.2: Performance & Goals
- [ ] Implement `InvestmentPerformanceReport` entity
- [ ] Implement `GoalProgressReport` entity
- [ ] Create providers
- [ ] Build screens with visualizations

#### Sprint 2.3: Maturity & Actions
- [ ] Implement `MaturityCalendarReport` entity
- [ ] Implement `ActionRequiredReport` entity
- [ ] Build calendar view UI
- [ ] Build action items list UI

### Phase 3: Static Reports (Week 3)

#### Sprint 3.1: Monthly Income Report
- [ ] Implement `MonthlyIncomeReport` entity
- [ ] Create auto-generation trigger on month-end
- [ ] Build `MonthlyIncomeScreen`
- [ ] Add PDF export capability

#### Sprint 3.2: FY Report
- [ ] Implement `FYReport` entity
- [ ] Create auto-generation trigger on Apr 1st
- [ ] Build `FYReportScreen`
- [ ] Add PDF/CSV export

### Phase 4: UI/UX Integration (Week 4)

#### Sprint 4.1: Reports Home
- [ ] Build `ReportsHomeScreen` with report cards
- [ ] Add bottom navigation item for Reports
- [ ] Implement search/filter for reports
- [ ] Add date range selector

#### Sprint 4.2: Export & Share
- [ ] Implement PDF generation service
- [ ] Implement CSV export service
- [ ] Add share functionality (email, WhatsApp)
- [ ] Add "Save to Files" option

#### Sprint 4.3: Notifications Integration
- [ ] Add deep links from notifications to reports
- [ ] Update notification tap handlers
- [ ] Add "View Report" CTA in notifications

### Phase 5: Testing & Refinement (Week 5)

#### Sprint 5.1: Testing
- [ ] Unit tests for all report entities
- [ ] Unit tests for report generation services
- [ ] Widget tests for all report screens
- [ ] Integration tests for static report generation

#### Sprint 5.2: Localization & Accessibility
- [ ] Add all strings to ARB files
- [ ] Test with different currencies (USD, EUR, INR)
- [ ] Verify accessibility (screen readers, touch targets)
- [ ] Test on different screen sizes

#### Sprint 5.3: Polish
- [ ] Performance optimization (caching, lazy loading)
- [ ] Error handling and retry logic
- [ ] Loading states and skeletons
- [ ] Empty states for new users

---

## 5. UI/UX Specifications

### 5.1 Reports Home Screen

**Route:** `/reports`
**Bottom Nav Item:** Reports (📊 icon)

**Layout:**
```
┌─────────────────────────────────────┐
│ Reports              [Filter] [⋮]   │
├─────────────────────────────────────┤
│ [Date Range: This Month ▼]          │
├─────────────────────────────────────┤
│ Quick Reports                        │
├─────────────────────────────────────┤
│ ┌─────────────┐ ┌─────────────┐    │
│ │ 📊 Weekly   │ │ 💰 Monthly  │    │
│ │ Summary     │ │ Income      │    │
│ │ Apr 21-27   │ │ March 2024  │    │
│ └─────────────┘ └─────────────┘    │
├─────────────────────────────────────┤
│ ┌─────────────┐ ┌─────────────┐    │
│ │ 🎯 Goals    │ │ 📈 Performnc│    │
│ │ Progress    │ │ Report      │    │
│ │ 5 active    │ │ Top 10      │    │
│ └─────────────┘ └─────────────┘    │
├─────────────────────────────────────┤
│ Historical Reports                   │
├─────────────────────────────────────┤
│ 📅 FY 2023-24 Report                │
│    Generated on Apr 1, 2024          │
│    [View PDF] [Export CSV]           │
├─────────────────────────────────────┤
│ 💰 Monthly Income - Feb 2024        │
│    ₹45,000 total income              │
│    [View] [Export]                   │
└─────────────────────────────────────┘
```

### 5.2 Chart Components to Reuse

| Chart Type | Existing Implementation | Report Usage |
|------------|------------------------|--------------|
| Bar Chart | `MonthlyCashFlowTrend` | Weekly/Monthly trends |
| Donut/Pie | `TypeDistributionChart` | Income by type |
| Progress Ring | `FireProgressRing` | Goal progress |
| Comparison Card | `YoYComparisonCard` | Period comparisons |
| Stat Cards | `QuickStatCard` | KPI metrics |

### 5.3 Export UI

**Export Button:**
```dart
Row(
  children: [
    IconButton(
      icon: Icon(Icons.picture_as_pdf),
      onPressed: () => exportToPDF(),
      tooltip: 'Export as PDF',
    ),
    IconButton(
      icon: Icon(Icons.table_chart),
      onPressed: () => exportToCSV(),
      tooltip: 'Export as CSV',
    ),
    IconButton(
      icon: Icon(Icons.share),
      onPressed: () => shareReport(),
      tooltip: 'Share Report',
    ),
  ],
)
```

---

## 6. Data Requirements

### 6.1 Analytics Events

```dart
// Report viewed
analyticsService.logEvent(
  name: 'report_viewed',
  parameters: {
    'report_type': 'weekly_summary',
    'date_range': '2024-04-21_2024-04-27',
  },
);

// Report exported
analyticsService.logEvent(
  name: 'report_exported',
  parameters: {
    'report_type': 'monthly_income',
    'export_format': 'pdf',
  },
);
```

### 6.2 Firestore Security Rules

```javascript
// Monthly reports
match /users/{userId}/monthlyReports/{reportId} {
  allow read: if request.auth.uid == userId;
  allow write: if request.auth.uid == userId;
}

// FY reports
match /users/{userId}/fyReports/{reportId} {
  allow read: if request.auth.uid == userId;
  allow write: if request.auth.uid == userId;
}
```

---

## 7. Testing Strategy

### 7.1 Unit Tests

```dart
// Test report generation
test('WeeklySummary calculates correct metrics', () {
  final cashFlows = [/* test data */];
  final summary = WeeklySummary.generate(cashFlows);

  expect(summary.totalInvested, 100000);
  expect(summary.totalReturns, 110000);
  expect(summary.netPosition, 10000);
});

// Test static report storage
test('MonthlyIncomeReport saves to Firestore', () async {
  final report = MonthlyIncomeReport(/* test data */);
  await reportRepository.saveMonthlyReport(userId, report);

  final retrieved = await reportRepository.getMonthlyReport(userId, '2024-03');
  expect(retrieved.totalIncome, report.totalIncome);
});
```

### 7.2 Widget Tests

```dart
testWidgets('WeeklySummaryScreen displays metrics', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weeklySummaryProvider.overrideWith((ref) => AsyncValue.data(mockSummary)),
      ],
      child: MaterialApp(home: WeeklySummaryScreen()),
    ),
  );

  expect(find.text('₹100,000'), findsOneWidget); // Total invested
  expect(find.text('+₹10,000'), findsOneWidget); // Net position
});
```

### 7.3 Integration Tests

- [ ] Test static report auto-generation on month-end
- [ ] Test FY report auto-generation on Apr 1st
- [ ] Test PDF export with real data
- [ ] Test deep linking from notifications

---

## 8. Multi-Perspective Review

### 8.1 Product Manager Review

**✅ Strengths:**
- Addresses real user pain points (tax filing, performance tracking)
- Leverages existing notification infrastructure
- Clear priority: P0 (core) → P1 (important) → P2 (nice-to-have)
- Export features enable sharing with advisors/CAs

**⚠️ Concerns:**
- 8 reports might overwhelm new users → **Solution:** Progressive disclosure (show 3 core reports first)
- PDF export adds dependency → **Solution:** Use `pdf` package (already in pubspec)
- Static reports increase storage costs → **Solution:** Compress JSON, limit to 7 years

**🔨 Recommendations:**
1. Add onboarding tooltip: "Reports help you track performance and file taxes"
2. Highlight "Most Useful" tag on Weekly Summary, Monthly Income, FY Report
3. Add "Request Report" for custom date ranges (P2 feature)

---

### 8.2 Senior Flutter Developer Review

**✅ Strengths:**
- Reuses existing widgets (`MonthlyCashFlowTrend`, `TypeDistributionChart`)
- Clean architecture (domain entities, repositories, providers)
- Riverpod for reactive state management
- Proper caching strategy (dynamic reports cached, static stored)

**⚠️ Concerns:**
- PDF generation can be CPU-intensive → **Solution:** Use `compute()` for background processing
- 8 report screens = code duplication → **Solution:** Create `BaseReportScreen` scaffold
- Static report auto-generation needs scheduling → **Solution:** Use Cloud Functions (future) or client-side on app launch

**🔨 Recommendations:**
1. Create `ReportChartFactory` to standardize chart creation
2. Use `freezed` for report entity immutability
3. Add `ReportCache` service with TTL (5 minutes for dynamic reports)
4. Implement lazy loading for historical reports list

**Code Pattern:**
```dart
// BaseReportScreen for code reuse
abstract class BaseReportScreen extends ConsumerWidget {
  const BaseReportScreen({super.key});

  String get title;
  ProviderListenable<AsyncValue<Object>> get dataProvider;
  Widget buildContent(BuildContext context, WidgetRef ref, Object data);
  List<Widget> buildActions(BuildContext context, WidgetRef ref);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(dataProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: buildActions(context, ref),
      ),
      body: dataAsync.when(
        data: (data) => buildContent(context, ref, data),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => ErrorWidget(error: e),
      ),
    );
  }
}
```

---

### 8.3 Compliance & Security Review

**✅ Strengths:**
- Static reports for tax compliance (7-year retention)
- Privacy mode support (wrap amounts in `PrivacyProtectionWrapper`)
- Firestore security rules restrict access to userId
- No PII in analytics events

**⚠️ Concerns:**
- PDF export might leak data in device logs → **Solution:** No debug prints in export service
- Shared reports via WhatsApp are unencrypted → **Solution:** Add warning: "Shared reports are not encrypted"
- Static reports don't support data deletion (GDPR) → **Solution:** Add to `deleteUserData()` flow

**🔨 Recommendations:**
1. Add audit log for report exports (who, when, format)
2. Add watermark to exported PDFs: "Confidential - For Tax Filing Only"
3. Implement auto-deletion of reports older than 7 years
4. Add consent dialog: "Reports may contain sensitive financial data. Share securely."

---

### 8.4 UX/Accessibility Review

**✅ Strengths:**
- Clear iconography (📊, 💰, 🎯, 📈)
- Consistent card-based layout
- Existing chart patterns (familiarity)

**⚠️ Concerns:**
- 8 reports = choice paralysis → **Solution:** Add "Recommended" section
- Charts need semantic labels for screen readers → **Solution:** Add `Semantics` widgets
- Export buttons need tooltips → **Solution:** Already included
- Color-only indicators (green/red) fail accessibility → **Solution:** Add icons (✅/⚠️)

**🔨 Recommendations:**
1. Add empty states for new users: "No reports yet. Add investments to generate reports."
2. Add loading skeletons for better perceived performance
3. Use `ListView.builder` for historical reports (performance)
4. Add "What's this?" info icon for each report with explanation

**Accessibility Checklist:**
- [ ] All charts have semantic labels
- [ ] Touch targets ≥44dp
- [ ] Color contrast ratio ≥4.5:1
- [ ] Screen reader compatible
- [ ] Supports dynamic font sizes

---

## 9. Refined Execution Plan (Post-Review)

Based on multi-perspective review, here's the optimized implementation plan:

### Phase 1: Foundation & Quick Wins (Week 1)

**Goal:** Ship 3 core reports (P0) for immediate value

#### Day 1-2: Infrastructure
- [ ] Create feature folder structure
- [ ] Create `BaseReportScreen` scaffold
- [ ] Create `ReportChartFactory` utility
- [ ] Implement `ReportCache` service (5-min TTL)
- [ ] Add Firestore security rules

#### Day 3-4: Weekly Summary Report (P0)
- [ ] Implement `WeeklySummary` entity
- [ ] Create `weeklySummaryProvider`
- [ ] Build `WeeklySummaryScreen` extending `BaseReportScreen`
- [ ] Add charts: Daily cashflow bar chart, week-over-week comparison
- [ ] Add to reports home

#### Day 5: Monthly Income Report (P0 - Dynamic View)
- [ ] Implement `MonthlyIncomeReport` entity
- [ ] Create `monthlyIncomeProvider` for current month
- [ ] Build `MonthlyIncomeScreen`
- [ ] Add charts: Income by type pie chart, 12-month trend
- [ ] Add export buttons (defer PDF implementation to Week 3)

### Phase 2: Reports Home & Navigation (Week 2)

#### Day 1-2: Reports Home Screen
- [ ] Create `ReportsHomeScreen` with card grid
- [ ] Add "Recommended" section (Weekly, Monthly, FY)
- [ ] Add "All Reports" section with search/filter
- [ ] Add bottom navigation item: Reports (📊)
- [ ] Implement date range selector

#### Day 3: Performance & Goal Reports (P0)
- [ ] Implement `InvestmentPerformanceReport` entity
- [ ] Implement `GoalProgressReport` entity
- [ ] Build screens with multi-ring charts
- [ ] Add filters (by type, by goal status)

#### Day 4: Action Required Report (P0)
- [ ] Implement `ActionRequiredReport` entity
- [ ] Build `ActionRequiredScreen` with priority sorting
- [ ] Add deep link from notifications
- [ ] Add "Snooze" and "Mark Done" actions

#### Day 5: Maturity Calendar (P1)
- [ ] Implement `MaturityCalendarReport` entity
- [ ] Build calendar view UI
- [ ] Build list view UI
- [ ] Add toggle between views

### Phase 3: Static Reports & Export (Week 3)

#### Day 1-2: Static Report Infrastructure
- [ ] Implement `FirestoreReportRepository`
- [ ] Create `StaticReportService`
- [ ] Implement auto-generation trigger (client-side on app launch)
- [ ] Add to `deleteUserData()` flow

#### Day 3-4: FY Report (P0)
- [ ] Implement `FYReport` entity
- [ ] Build `FYReportScreen`
- [ ] Add auto-generation on Apr 1st
- [ ] Add charts: Monthly investment trend, category-wise returns

#### Day 5: PDF Export Service
- [ ] Implement `ReportExportService`
- [ ] Add PDF generation for Monthly Income report
- [ ] Add PDF generation for FY Report
- [ ] Add watermark: "Confidential - For Tax Filing Only"
- [ ] Use `compute()` for background processing

### Phase 4: Polish & Testing (Week 4)

#### Day 1-2: CSV Export & Sharing
- [ ] Implement CSV export for Monthly Income
- [ ] Implement CSV export for FY Report
- [ ] Add share functionality (email, WhatsApp)
- [ ] Add consent dialog: "Reports contain sensitive data"

#### Day 3: Localization & Privacy
- [ ] Add all strings to ARB files
- [ ] Wrap amounts in `PrivacyProtectionWrapper`
- [ ] Test with different currencies (USD, EUR, INR)
- [ ] Test with privacy mode ON

#### Day 4: Accessibility & Error Handling
- [ ] Add semantic labels to all charts
- [ ] Verify touch targets ≥44dp
- [ ] Add error states with retry buttons
- [ ] Add empty states for new users
- [ ] Add loading skeletons

#### Day 5: Testing
- [ ] Unit tests for all report entities
- [ ] Widget tests for all screens
- [ ] Integration tests for static report generation
- [ ] Performance testing (100+ investments, 1000+ cashflows)

### Phase 5: Optimization & Launch Prep (Week 5)

#### Day 1-2: Performance Optimization
- [ ] Implement lazy loading for historical reports
- [ ] Add pagination for reports list
- [ ] Optimize chart rendering (RepaintBoundary)
- [ ] Add caching for expensive calculations

#### Day 3: Analytics & Monitoring
- [ ] Add analytics events (report_viewed, report_exported)
- [ ] Add Crashlytics error logging
- [ ] Test report generation with edge cases (0 investments, 1 cashflow)

#### Day 4: Documentation
- [ ] Update Help & FAQ screen with Reports section
- [ ] Add onboarding tooltip for Reports tab
- [ ] Create user guide for PDF export
- [ ] Update README.md

#### Day 5: Final Review & Launch
- [ ] Run full test suite
- [ ] Check for analyzer warnings
- [ ] Verify code coverage ≥60%
- [ ] Verify compliance with InvTrack Enterprise Rules
- [ ] Create PR with comprehensive description

---

## 10. Success Metrics

### User Engagement
- **Target:** 60% of users view at least 1 report per week
- **Measure:** `report_viewed` analytics event

### Feature Adoption
- **Target:** 40% of users export at least 1 report (PDF/CSV)
- **Measure:** `report_exported` analytics event

### User Satisfaction
- **Target:** <5% error rate on report generation
- **Measure:** Crashlytics error logs

### Performance
- **Target:** Reports load within 2 seconds
- **Measure:** Performance tracking with `PerformanceService`

---

## 11. Future Enhancements (Post-MVP)

### P2 Features (Week 6+)
- [ ] Custom date range reports
- [ ] Email auto-delivery (weekly/monthly reports)
- [ ] Comparison reports (This Year vs Last Year)
- [ ] Tax optimization suggestions
- [ ] Scheduled PDF generation (Cloud Functions)
- [ ] Report templates (customizable)
- [ ] Multi-currency aggregation
- [ ] Benchmark comparison (market indices)

### Premium Features
- [ ] Unlimited historical reports (free: last 12 months)
- [ ] Advanced charts (candlestick, heatmaps)
- [ ] AI-powered insights ("Your top performer is FDs at 9% XIRR")
- [ ] Advisor sharing (secure links with expiry)

---

## Appendix A: Notification → Report Mapping Table

| Notification ID | Notification Name | Report(s) Generated | Report Type | Priority |
|----------------|-------------------|---------------------|-------------|----------|
| 1000 | Weekly Summary | Weekly Investment Summary | Dynamic | P0 |
| 1001 | Monthly Summary | Monthly Income Report | Static | P0 |
| 2001 | FY Summary | Financial Year Report | Static | P0 |
| 1010-1015 | Tax Reminders | (Included in FY Report) | Static | P1 |
| 50000+ | Maturity Reminder | Maturity Calendar Report | Dynamic | P1 |
| 50000+ | Income Alert | (Included in Monthly Report) | Static | P2 |
| 150000+ | Milestone | Investment Performance Report | Dynamic | P0 |
| 220000+ | Goal Milestone | Goal Progress Report | Dynamic | P0 |
| 240000+ | Goal At-Risk | Goal Progress Report | Dynamic | P0 |
| N/A | Goal Stale | Action Required Report | Dynamic | P2 |
| 200000+ | Risk Alert | Portfolio Health Report | Dynamic | P1 |
| 210000+ | Idle Investment | Action Required Report | Dynamic | P2 |

---

## Appendix B: Technical Decisions

### Decision 1: Static vs Dynamic Reports
**Decision:** Use static snapshots for Monthly & FY reports, dynamic for all others

**Rationale:**
- Tax compliance requires immutable historical records
- Static reports enable offline access
- Dynamic reports always show latest data
- Storage cost: ~10KB per monthly report × 12 months = 120KB/user/year (negligible)

### Decision 2: PDF Export Library
**Decision:** Use `pdf` package (already in dependencies)

**Alternatives Considered:**
- `printing` package - More features but larger bundle size
- `flutter_html_to_pdf` - Web view dependency (slower)

### Decision 3: Chart Library
**Decision:** Reuse existing custom chart widgets

**Rationale:**
- Consistent UI/UX with overview screen
- No new dependencies
- Full control over styling
- Better performance than `fl_chart`

### Decision 4: Report Auto-Generation
**Decision:** Client-side trigger on app launch (check last generated date)

**Alternatives Considered:**
- Cloud Functions (requires paid plan)
- Cloud Scheduler (overkill for simple task)

**Implementation:**
```dart
// On app launch
final lastGenerated = await prefs.getString('last_monthly_report_date');
final now = DateTime.now();
if (lastGenerated == null ||
    DateTime.parse(lastGenerated).month != now.month) {
  await generateMonthlyReport();
  await prefs.setString('last_monthly_report_date', now.toIso8601String());
}
```

### Decision 5: Caching Strategy
**Decision:** In-memory cache with 5-minute TTL for dynamic reports

**Rationale:**
- Reports are expensive to generate (XIRR calculations)
- Users typically view reports multiple times in a session
- 5 minutes balances freshness vs performance

---

## Appendix C: Localization Strings

```json
{
  "reportsTitle": "Reports",
  "reportsEmptyState": "No reports yet. Add investments to generate reports.",
  "reportWeeklySummary": "Weekly Investment Summary",
  "reportMonthlyIncome": "Monthly Income Report",
  "reportFY": "Financial Year Report",
  "reportPerformance": "Investment Performance",
  "reportGoalProgress": "Goal Progress",
  "reportMaturityCalendar": "Maturity Calendar",
  "reportActionRequired": "Action Required",
  "reportPortfolioHealth": "Portfolio Health",
  "exportPDF": "Export as PDF",
  "exportCSV": "Export as CSV",
  "shareReport": "Share Report",
  "shareWarning": "Reports contain sensitive financial data. Share securely.",
  "reportGenerating": "Generating report...",
  "reportError": "Failed to generate report. Please try again.",
  "dateRangeThisWeek": "This Week",
  "dateRangeThisMonth": "This Month",
  "dateRangeThisYear": "This Year",
  "dateRangeCustom": "Custom Range"
}
```

---

## Conclusion

This execution plan delivers a **production-ready Reports feature** in 5 weeks:
- **Week 1-2:** Core reports (Weekly, Monthly, Performance, Goals, Actions)
- **Week 3:** Static reports & PDF export (Monthly, FY)
- **Week 4-5:** Polish, testing, launch prep

**Key Success Factors:**
1. ✅ Reuse existing infrastructure (charts, providers, services)
2. ✅ Progressive disclosure (3 recommended reports → 8 total)
3. ✅ Clear priorities (P0 → P1 → P2)
4. ✅ Compliance-first (static reports for tax filing)
5. ✅ User-centric (export, share, actionable insights)

**Next Steps:**
1. Review this plan with stakeholders
2. Create GitHub issues for each sprint
3. Begin Phase 1 implementation
4. Ship MVP in 5 weeks 🚀

---

**Document Status:** ✅ READY FOR DEVELOPMENT



