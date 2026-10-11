# Reports Feature - Future Improvements

**Status:** Post-Merge Enhancements  
**Created:** 2026-04-29  
**Source:** CodeRabbit PR #358 Review Comments  

---

## Priority: HIGH ⚠️

### 1. ✅ Localization Compliance (Rule 16) - COMPLETED
**Status:** COMPLETED ✅ (2026-05-02)
**Impact:** i18n support for global users
**Actual Effort:** ~30 minutes

**What was done:**
- ✅ Audited all 4 report screens - found all strings already localized
- ✅ Found and fixed 2 hardcoded strings in `base_report_screen.dart`:
  - "Failed to generate report" → `l10n.failedToGenerateReport`
  - "Try Again" → `l10n.tryAgain`
- ✅ Added 2 new ARB entries with proper metadata
- ✅ Generated localization files: `flutter gen-l10n`
- ✅ Verified zero analyzer issues: `flutter analyze`

**Files modified:**
- `lib/l10n/app_en.arb` - Added 2 new keys
- `lib/features/reports/presentation/widgets/base_report_screen.dart` - Fixed hardcoded strings

**Verification:**
```bash
flutter gen-l10n  # ✅ Passed
flutter analyze   # ✅ No issues found
```

**Result:** 100% localization compliance achieved for Reports feature 🎉

---

### 2. ✅ Privacy Mode Export Compliance (Rule 17.3) - COMPLETED
**Status:** COMPLETED ✅ (PR #362 - May 1, 2026)
**Impact:** Financial data protected in CSV/PDF exports
**Actual Effort:** Already implemented

**What was done:**
- ✅ Added `isPrivacyMode` parameter to CSV/PDF exporters
- ✅ Implemented `_formatAmount()` method that masks amounts with `••••••`
- ✅ `report_export_providers.dart` reads `privacyModeProvider` and passes to exporters
- ✅ All financial amounts in exports use privacy-aware formatting
- ✅ Verified in commit 4ec2f2f6

**Files modified:**
- `lib/features/reports/data/services/report_csv_exporter.dart` - Privacy masking support
- `lib/features/reports/data/services/report_pdf_exporter.dart` - Privacy masking support
- `lib/features/reports/presentation/providers/report_export_providers.dart` - Read privacy mode

**Implementation:**
```dart
// ✅ Already implemented in report_export_providers.dart:
final isPrivacyMode = ref.read(privacyModeProvider);

// ✅ Already implemented in exporters:
String _formatAmount(double amount, String symbol, bool isPrivacyMode, String locale) {
  if (isPrivacyMode) {
    return '••••••';
  }
  return NumberFormat.currency(locale: locale, symbol: symbol).format(amount);
}
```

**Verification:**
- ✅ All 45 `_formatAmount()` calls in PDF exporter include `isPrivacyMode`
- ✅ All amount formats in CSV exporter include `isPrivacyMode`
- ✅ Privacy mode state correctly read from provider

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
- ~~Localization Compliance~~ (Completed 2026-05-02 - 100% compliance achieved)
- ~~Privacy Mode Export Compliance~~ (PR #362, May 1, 2026 - Already implemented)

---

## Notes

- All items are **enhancements**, not blockers
- Prioritize based on business impact
- Localization is most valuable for international users
- Privacy mode export is critical for App Store compliance
- Domain refactoring can wait for architecture review

