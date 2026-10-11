# Reports Feature - Analytics & Monitoring Guide

**Last Updated:** 2024-04-29  
**Status:** Production-Ready  
**Analytics Framework:** Firebase Analytics

---

## 📊 Overview

The Reports feature includes comprehensive analytics tracking to monitor:
- Report usage patterns (which reports are most valuable to users)
- Export behavior (preferred formats, export frequency)
- Historical data access (how often users reference past data)
- User engagement with financial metrics (tooltip views)

All analytics events comply with **InvTrack Enterprise Rules** (Rule 9 and Rule 17.4):
- ✅ **No exact amounts logged** (privacy-safe ranges only)
- ✅ **No PII or sensitive data** (user IDs, names, emails)
- ✅ **Granular enough for insights** (understand user behavior)

---

## 🎯 Key Analytics Events

### 1. `report_viewed`
Tracks when a user views any report.

**Purpose:** Understand which reports are most valuable, identify adoption patterns

**Parameters:**
- `report_type` (string): Type of report viewed
  - Values: `"weekly"`, `"monthly"`, `"fy"`, `"performance"`, `"goals"`, `"maturity"`, `"actions"`, `"health"`
- `is_historical` (int): Whether viewing historical data
  - Values: `0` (current), `1` (historical)
- `period` (string, optional): Period identifier for historical reports
  - Examples: `"2023"` (FY), `"2024-03"` (March 2024)

**Firebase Analytics Console:**
- Navigate to: **Events > report_viewed**
- Key Metrics:
  - Total views per report type
  - Current vs historical report ratio
  - Most viewed historical periods

**Example Queries:**
```
# Most popular reports
SELECT report_type, COUNT(*) as views
FROM events
WHERE event_name = 'report_viewed'
GROUP BY report_type
ORDER BY views DESC

# Historical vs current reports
SELECT is_historical, COUNT(*) as views
FROM events
WHERE event_name = 'report_viewed'
GROUP BY is_historical
```

---

### 2. `report_exported`
Tracks when a user exports a report to PDF or CSV.

**Purpose:** Understand export preferences, identify most exported reports

**Parameters:**
- `report_type` (string): Type of report exported
  - Values: Same as `report_viewed`
- `format` (string): Export format
  - Values: `"pdf"`, `"csv"`
- `record_count` (int, optional): Number of records in export
  - Example: `15` (15 transactions in monthly report)
  - Privacy-safe: count only, no amounts

**Firebase Analytics Console:**
- Navigate to: **Events > report_exported**
- Key Metrics:
  - PDF vs CSV preference
  - Export frequency per report type
  - Average record count per export

**Example Queries:**
```
# Export format preferences
SELECT format, COUNT(*) as exports
FROM events
WHERE event_name = 'report_exported'
GROUP BY format

# Most exported reports
SELECT report_type, COUNT(*) as exports
FROM events
WHERE event_name = 'report_exported'
GROUP BY report_type
ORDER BY exports DESC
```

---

### 3. `historical_report_accessed`
Tracks when a user accesses historical reports (past FY years or months).

**Purpose:** Understand how often users reference past data, identify common use cases

**Parameters:**
- `report_type` (string): Type of historical report
  - Values: `"fy"`, `"monthly"` (only these support historical)
- `periods_back` (int): How many periods back from current
  - Examples: `1` (last year), `2` (2 years ago), `6` (6 months ago)
- `period` (string): Period identifier
  - Examples: `"2023"` (FY), `"2024-03"` (March 2024)

**Firebase Analytics Console:**
- Navigate to: **Events > historical_report_accessed**
- Key Metrics:
  - Most common periods accessed (last year, 2 years ago, etc.)
  - FY vs Monthly historical reports ratio
  - Frequency of historical access (tax season spikes, etc.)

**Example Queries:**
```
# Most common historical periods
SELECT periods_back, COUNT(*) as accesses
FROM events
WHERE event_name = 'historical_report_accessed'
GROUP BY periods_back
ORDER BY accesses DESC

# Tax season analysis (FY reports in Apr-May)
SELECT DATE_TRUNC(timestamp, MONTH) as month, COUNT(*) as accesses
FROM events
WHERE event_name = 'historical_report_accessed'
  AND report_type = 'fy'
GROUP BY month
ORDER BY month
```

---

### 4. `report_metric_tooltip_viewed`
Tracks when a user taps a help icon to view metric tooltips (XIRR, CAGR, etc.).

**Purpose:** Identify confusing metrics, improve help documentation

**Parameters:**
- `metric_name` (string): Name of metric
  - Values: `"xirr"`, `"cagr"`, `"capital_gains"`, `"net_position"`, etc.
- `report_type` (string): Which report the tooltip was viewed in
  - Values: Same as `report_viewed`

**Firebase Analytics Console:**
- Navigate to: **Events > report_metric_tooltip_viewed**
- Key Metrics:
  - Most confusing metrics (most tooltip views)
  - Metrics that need better UI/UX
  - Help documentation gaps

**Example Queries:**
```
# Most confusing metrics (highest tooltip views)
SELECT metric_name, COUNT(*) as tooltip_views
FROM events
WHERE event_name = 'report_metric_tooltip_viewed'
GROUP BY metric_name
ORDER BY tooltip_views DESC

# Tooltip views by report type
SELECT report_type, COUNT(*) as tooltip_views
FROM events
WHERE event_name = 'report_metric_tooltip_viewed'
GROUP BY report_type
```

---

## 📈 Key Dashboards & Metrics

### Dashboard 1: Report Adoption & Usage
**Purpose:** Track which reports are driving value

**Metrics:**
- Total report views (last 7/30/90 days)
- Report views by type (bar chart)
- Current vs historical report ratio (pie chart)
- Report views trend over time (line chart)

**Alerts:**
- Drop in report views >20% week-over-week
- Any report with <10 views in 30 days (low adoption)

---

### Dashboard 2: Export Behavior
**Purpose:** Understand how users want to save/share data

**Metrics:**
- Total exports (last 7/30/90 days)
- PDF vs CSV ratio (pie chart)
- Exports by report type (bar chart)
- Average record count per export

**Alerts:**
- Export failures >5% (error rate spike)
- CSV exports dropping (may indicate format preference shift)

---

### Dashboard 3: Historical Reports Usage
**Purpose:** Monitor historical reporting feature adoption

**Metrics:**
- Total historical accesses (last 7/30/90 days)
- Most accessed historical periods (bar chart)
- Historical access trend (line chart)
- Tax season spikes (Apr-May FY report access)

**Alerts:**
- Tax season (Apr-May): expect 3-5x spike in FY historical reports
- Anomalous spikes outside tax season (investigate feature changes)

---

## 🔍 Monitoring Best Practices

### 1. Weekly Review
**Every Monday:**
- Check Dashboard 1: Any report with declining views?
- Review export errors: Any spikes in failures?
- Identify most viewed reports: Focus improvements here

### 2. Monthly Analysis
**First week of every month:**
- Compare month-over-month report views
- Identify seasonal patterns (tax season, year-end)
- Review tooltip views: Are users still confused about same metrics?
- Export format preferences: Any shift from PDF to CSV (or vice versa)?

### 3. Quarterly Deep Dive
**Every quarter:**
- User cohort analysis: New users vs returning users report usage
- Historical report adoption: Is feature growing or plateauing?
- A/B test ideas: Based on low-adoption reports, test UI improvements
- Help documentation gaps: Update FAQ/tooltips for confusing metrics

---

## 🚨 Alert Thresholds

### Critical Alerts (Immediate Action Required)
- ❌ **Export failure rate >10%**: Investigate storage/share_plus issues
- ❌ **Report crash rate >5%**: Check error logs, Firestore query issues
- ❌ **Zero report views for 7+ days**: Feature discovery issue

### Warning Alerts (Monitor Closely)
- ⚠️ **Report views drop >20% week-over-week**: Investigate UI changes, bugs
- ⚠️ **Tooltip views spike >50%**: New metric confusing users, improve help
- ⚠️ **Export format shift >30%**: User preference changing, ensure both formats work well

### Info Alerts (Track Trends)
- ℹ️ **Tax season spike (Apr-May)**: Expected 3-5x increase in FY historical reports
- ℹ️ **Year-end spike (Dec-Jan)**: Expected 2-3x increase in performance reports
- ℹ️ **New report launch**: Monitor adoption in first 30 days

---

## 🛠️ Troubleshooting Guide

### Low Report Adoption (<10 views/30 days)
**Possible Causes:**
1. Poor discoverability (hidden in UI)
2. Confusing report title/description
3. Not solving user pain point

**Actions:**
- A/B test report card design on home screen
- Add sample data screenshots to help screen
- User interviews: Why aren't you using X report?

### High Tooltip View Rate (>30% of report views)
**Possible Causes:**
1. Metric too technical (XIRR, CAGR)
2. Insufficient inline explanation
3. First-time user onboarding gap

**Actions:**
- Add inline hints (e.g., "XIRR: Annual return rate")
- Improve tooltip content clarity
- Add onboarding tour for financial metrics

### Export Failures Spike
**Possible Causes:**
1. Storage permission issues (Android/iOS)
2. Large dataset timeout
3. Share_plus integration issue

**Actions:**
- Check Crashlytics for PDF/CSV export errors
- Test with large datasets (100+ records)
- Verify share_plus version compatibility

### Declining Historical Report Usage
**Possible Causes:**
1. UI/UX issue (hard to find historical links)
2. Performance issue (slow loading)
3. Data quality issue (missing historical data)

**Actions:**
- Move historical reports section higher on home screen
- Add caching for historical reports (reduce Firestore reads)
- Verify historical data availability for all users

---

## 📊 Success Metrics (OKRs)

### Q2 2024 Goals
**Objective:** Drive report feature adoption to 80% MAU

**Key Results:**
1. **70% of MAU** view at least 1 report per month (baseline: 45%)
2. **30% of report viewers** export at least 1 report per month (baseline: 15%)
3. **<10% tooltip view rate** (users understand metrics without help)
4. **<2% export failure rate** (reliable export experience)

### Tracking Dashboard
Create custom Firebase Analytics audiences:
- **"Report Power Users"**: View 5+ reports per month
- **"Export Enthusiasts"**: Export 2+ reports per month
- **"Historical Report Users"**: Access historical data monthly

Track conversion funnels:
1. Home Screen View → Report Card Tap → Report View → Export
2. Report View → Tooltip View → Help Screen View

---

## 🔐 Privacy Compliance Checklist

Before releasing any new analytics:
- [ ] No exact monetary amounts logged (use ranges from `getAmountRange()`)
- [ ] No PII (names, emails, phone numbers, account numbers)
- [ ] No user IDs directly in events (Firebase Auth UID is auto-attached)
- [ ] Record counts only (no transaction details)
- [ ] All events follow `{noun}_{action}` naming convention
- [ ] All events documented in this file
- [ ] All events tested in debug mode (check console logs)

---

## 📚 Implementation Reference

**Analytics Service:** `lib/core/analytics/analytics_service.dart`
**Event Constants:** `AnalyticsEvents` class (lines 97-187)
**Convenience Methods:** `AnalyticsService` class (lines 831-978)
**Base Report Screen:** `lib/features/reports/presentation/widgets/base_report_screen.dart`
**Export Services:**
- `lib/features/reports/data/services/report_pdf_exporter.dart`
- `lib/features/reports/data/services/report_csv_exporter.dart`

**Testing:**
- Unit tests: `test/core/analytics/analytics_service_test.dart`
- Mock service: `test/mocks/mock_analytics_service.dart`

---

## 🎯 Future Enhancements

### Phase 2 (Q3 2024)
- **Funnel analysis**: Track complete user journeys (onboard → report view → export)
- **Retention cohorts**: Weekly/monthly report viewer retention
- **Session duration**: Time spent in each report (engagement metric)

### Phase 3 (Q4 2024)
- **User surveys**: In-app NPS for reports feature
- **Heatmaps**: Which report sections get most attention
- **Comparison reports**: Users comparing multiple periods (advanced feature)

---

**End of Analytics Documentation** 📊✅
