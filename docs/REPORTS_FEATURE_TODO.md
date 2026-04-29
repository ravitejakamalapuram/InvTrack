# Reports Feature - Future Improvements

**Status:** Post-Merge Enhancements  
**Created:** 2026-04-29  
**Source:** CodeRabbit PR #358 Review Comments  

---

## Priority: HIGH ⚠️

### 1. Localization Compliance (Rule 16)
**Impact:** i18n support for global users  
**Effort:** ~2-3 hours  

**Hardcoded strings to move to ARB files:**
- `maturity_calendar_screen.dart`:
  - "Maturity Overview" → `maturityOverviewTitle`
  - "Total Maturing" → `totalMaturingLabel`
  - "Next 30 Days" → `next30DaysLabel`
  - "Weighted Avg Maturity" → `weightedAvgMaturityLabel`
  
- `performance_report_screen.dart`:
  - "🏆 Top Performers" → `topPerformersTitle`
  - "📉 Bottom Performers" → `bottomPerformersTitle`
  - "Portfolio Performance" → `portfolioPerformanceTitle`
  
- `goal_progress_screen.dart`:
  - "Goals Summary" → `goalsSummaryTitle`
  - "Overall Progress" → `overallProgressLabel`
  
- `action_required_screen.dart`:
  - "Action Items" → `actionItemsTitle`
  - "No Action Required" → `noActionRequiredMessage`

**Files to update:**
- `lib/l10n/app_en.arb` (add ~30 new keys)
- All report screens (replace hardcoded strings)

**Verification:**
```bash
flutter gen-l10n
flutter analyze
```

---

### 2. Privacy Mode Export Compliance (Rule 17.3)
**Impact:** Financial data leaks in CSV/PDF exports  
**Effort:** ~1 hour  

**Current:** Privacy mode UI works, but exports show raw data  
**Required:** Mask amounts in exports when privacy mode enabled  

**Files to modify:**
- `lib/features/reports/data/services/report_csv_exporter.dart`
- `lib/features/reports/data/services/report_pdf_exporter.dart`

**Implementation:**
```dart
// Check privacy mode before export
final isPrivacyMode = ref.read(privacyModeProvider);
final displayAmount = isPrivacyMode ? '••••••' : formatAmount(amount);
```

**Test cases:**
- Export CSV with privacy ON → amounts masked
- Export PDF with privacy ON → amounts masked
- Export with privacy OFF → amounts visible

---

## Priority: MEDIUM 🟡

### 3. Domain Entity UI Logic Separation
**Impact:** Clean architecture compliance  
**Effort:** ~2 hours  

**Current:** Domain entities have UI-specific methods (emoji, labels)  
**Recommended:** Move to presentation layer view models  

**Example refactor:**
```dart
// ❌ Current (in domain/entities/goal_progress.dart)
String getStatusEmoji() { ... }
String getProgressLabel() { ... }

// ✅ Better (create presentation/view_models/goal_progress_view_model.dart)
class GoalProgressViewModel {
  final GoalProgress progress;
  String get statusEmoji => ...;
  String get progressLabel => ...;
}
```

**Files to refactor:**
- `lib/features/reports/domain/entities/goal_progress.dart`
- `lib/features/reports/domain/entities/action_item.dart`

---

### 4. Typed Error Handling (AppException)
**Impact:** Better error UX and debugging  
**Effort:** ~1.5 hours  

**Current:** Generic try-catch with raw exceptions  
**Recommended:** Use `AppException` hierarchy  

**Files to update:**
- All report service files (8 files)

**Example:**
```dart
// ❌ Current
try {
  return await calculation();
} catch (e) {
  return defaultValue;
}

// ✅ Better
try {
  return await calculation();
} on FirebaseException catch (e) {
  throw DataException.loadFailed('Failed to load report: ${e.message}');
} catch (e, st) {
  ErrorHandler.handle(e, st, context: context);
  throw AppException('Unexpected error');
}
```

---

### 5. Report Cache Cleanup Automation
**Impact:** Prevent stale cached reports  
**Effort:** ~1 hour  

**Current:** Cache expires after 1 hour but stays in memory  
**Recommended:** Add periodic cleanup timer  

**File:** `lib/features/reports/data/services/report_cache_service.dart`

**Implementation:**
```dart
class ReportCacheService {
  Timer? _cleanupTimer;
  
  void startPeriodicCleanup() {
    _cleanupTimer = Timer.periodic(Duration(minutes: 5), (_) {
      clearExpiredCache();
    });
  }
  
  void dispose() {
    _cleanupTimer?.cancel();
  }
}
```

---

## Priority: LOW 🟢

### 6. Multi-Currency Compliance Enhancements
**Impact:** Better UX for multi-currency portfolios  
**Effort:** ~3 hours  

**Recommendations from Rule 21:**
- Show exchange rates when currencies differ
- Add currency indicator badges in reports
- Highlight when base currency changed recently

**Example UI:**
```dart
// Show currency conversion transparency
if (investment.currency != baseCurrency) {
  Text('Converted from ${investment.currency}');
  Text('Rate: 1 ${investment.currency} = ${rate} ${baseCurrency}');
}
```

---

### 7. Unit Test Coverage
**Impact:** Confidence in refactoring  
**Effort:** ~4 hours  

**Current:** 27% coverage (3/11 services)  
**Target:** 80% coverage  

**Missing tests:**
- `fy_report_service_test.dart`
- `goal_progress_service_test.dart`
- `maturity_calendar_service_test.dart`
- `monthly_income_service_test.dart`
- `performance_report_service_test.dart`
- `portfolio_health_service_test.dart`
- `report_cache_service_test.dart`

---

## Completed ✅

- ~~Mock repository parity~~ (Fixed in commit 897508e9)
- ~~Negative return sign bug~~ (Fixed in commit 0e913604)
- ~~Nested scrolling layout~~ (Fixed in commit 0e913604)
- ~~Analytics tracking~~ (Implemented in commit 897508e9)

---

## Notes

- All items are **enhancements**, not blockers
- Prioritize based on business impact
- Localization is most valuable for international users
- Privacy mode export is critical for App Store compliance
- Domain refactoring can wait for architecture review

