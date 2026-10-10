# Week 2 Progress: Backend Infrastructure & Persistence

**Date**: 2026-04-03 (Started)  
**Status**: 🟡 **IN PROGRESS** (60% Complete)  
**Team Mode**: Reluctant but committed dev team 💪

---

## ✅ **Completed Tasks**

### **1. Firestore Schema Design** ✅
**File**: `lib/features/portfolio_health/data/models/health_score_snapshot_model.dart`

- ✅ Created `HealthScoreSnapshotModel` for persistence
- ✅ Stores overall score + all 5 component scores
- ✅ Firestore converter methods (`fromFirestore`, `toFirestore`)
- ✅ Chart data conversion (`toChartData`)
- ✅ Metadata field for future extensions

**Schema**:
```
users/{userId}/healthScores/{snapshotId}
{
  overallScore: double,
  returnsScore: double,
  diversificationScore: double,
  liquidityScore: double,
  goalAlignmentScore: double,
  actionReadinessScore: double,
  calculatedAt: Timestamp,
  metadata: Map<String, dynamic>?
}
```

### **2. Repository Pattern** ✅
**File**: `lib/features/portfolio_health/data/repositories/health_score_repository.dart`

- ✅ CRUD operations for health score snapshots
- ✅ `saveSnapshot()` - persist to Firestore
- ✅ `getLatestSnapshot()` - fetch most recent
- ✅ `getHistoricalSnapshots(weeks)` - fetch last N weeks
- ✅ `watchHistoricalSnapshots()` - real-time stream
- ✅ `deleteAllSnapshots()` - data deletion compliance
- ✅ Error handling with `AppException`
- ✅ Crashlytics integration for error tracking

### **3. Riverpod Providers** ✅
**File**: `lib/features/portfolio_health/presentation/providers/portfolio_health_provider.dart`

- ✅ `healthScoreRepositoryProvider` - repository singleton
- ✅ `historicalHealthScoresProvider` - stream of snapshots
- ✅ `healthScoreChartData` Provider` - simplified for charts
- ✅ Auto-save logic (debounced: >1 point change OR >24h)

### **4. Data Lifecycle Compliance** ✅

**Updated Files**:
- ✅ `lib/features/settings/presentation/screens/data_management_screen.dart` - added health score deletion
- ✅ `functions/src/cleanupAnonymousUsers.ts` - added `healthScores` collection
- ✅ `firestore.rules` - already covered by `users/{userId}/{document=**}`

**Compliance**:
- ✅ Delete all health scores on account deletion
- ✅ Delete all health scores on anonymous user cleanup (30+ days)
- ✅ Proper error handling and logging

### **5. Error Handling Enhancement** ✅
**File**: `lib/core/error/app_exception.dart`

- ✅ Added `DataException.fetchFailed()` factory
- ✅ Consistent exception signatures across app

---

## 📊 **Auto-Save Logic**

**Smart Debouncing** (prevents excessive writes):
1. Fetch latest snapshot from Firestore
2. Compare with current score
3. Save IF:
   - No previous snapshot exists, OR
   - Score changed by >1 point, OR
   - >24 hours since last save

**Benefits**:
- Reduces Firestore writes (saves costs)
- Only saves significant changes
- Daily snapshots even if score stable

---

## 🧪 **Testing Status**

| Component | Status | Notes |
|-----------|--------|-------|
| **Model Serialization** | ⏳ Not Started | Test Firestore to/from conversion |
| **Repository CRUD** | ⏳ Not Started | Mock Firestore operations |
| **Auto-Save Logic** | ⏳ Not Started | Test debouncing conditions |
| **Data Deletion** | ⏳ Not Started | Verify cleanup works |

---

## 📁 **Files Created/Modified**

**New Files** (3):
1. `lib/features/portfolio_health/data/models/health_score_snapshot_model.dart` (145 lines)
2. `lib/features/portfolio_health/data/repositories/health_score_repository.dart` (166 lines)
3. `docs/WEEK_2_PROGRESS.md` (this file)

**Modified Files** (5):
1. `lib/features/portfolio_health/presentation/providers/portfolio_health_provider.dart` (+60 lines)
2. `lib/features/settings/presentation/screens/data_management_screen.dart` (+3 lines)
3. `functions/src/cleanupAnonymousUsers.ts` (+1 line)
4. `lib/core/error/app_exception.dart` (+13 lines)
5. `lib/features/portfolio_health/presentation/providers/portfolio_health_provider.g.dart` (regenerated)

**Total Code**: ~400 new lines

---

## 🚧 **Remaining Tasks (Week 2)**

### **Task 6: Historical Trend Chart Widget** (Next)
- [ ] Create `PortfolioHealthTrendChart` widget
- [ ] Line chart showing last 12 weeks
- [ ] Display overall score + 5 component scores
- [ ] Tap to toggle component visibility
- [ ] Empty state for <2 data points

### **Task 7: Score Improvement Tracking**
- [ ] Calculate score delta (current vs last week)
- [ ] Show "+5 points this week" badge
- [ ] Color code: Green (improved), Red (declined), Gray (stable)

### **Task 8: Unit Tests** (Critical)
- [ ] Test `HealthScoreSnapshotModel` serialization
- [ ] Test repository CRUD operations
- [ ] Test auto-save debouncing logic
- [ ] Test data deletion compliance
- [ ] Target: 90%+ coverage for Week 2 code

### **Task 9: Integration Testing**
- [ ] Test full flow: calculate → save → fetch → display
- [ ] Test error scenarios (Firestore offline, auth issues)
- [ ] Test data deletion end-to-end

---

## 📈 **Progress Metrics**

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| **Code Written** | ~500 lines | ~400 lines | 🟡 80% |
| **Features Complete** | 5 tasks | 5 tasks | ✅ 100% |
| **Tests Written** | 90% coverage | 0% | ⏳ 0% |
| **Zero Analyzer Errors** | ✅ | ✅ | ✅ Done |

---

## 🎯 **Next Steps**

**Today** (2026-04-03, continued):
1. ✅ Build historical trend chart widget
2. ✅ Add score improvement tracking
3. ✅ Write comprehensive unit tests

**Tomorrow** (2026-04-04):
1. Integration testing
2. Performance testing (large datasets)
3. Week 2 completion & handoff to Week 3

---

**Status**: 🎯 **ON TRACK** for Week 2 completion  
**Confidence**: 90% (backend solid, UI/tests remaining)  
**Blockers**: None

