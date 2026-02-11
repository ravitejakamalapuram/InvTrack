# Performance Monitoring Implementation

> Firebase Performance Monitoring setup for tracking critical operations in InvTrack
> Implemented: 2026-02-11

---

## 📊 Overview

This implementation adds comprehensive performance monitoring to InvTrack using Firebase Performance Monitoring. It tracks critical operations to identify bottlenecks and optimize user experience.

---

## 🎯 What Was Implemented

### **1. Core Infrastructure**

#### **PerformanceService** (`lib/core/performance/performance_service.dart`)
- Singleton service wrapping Firebase Performance Monitoring
- Methods:
  - `initialize()` - Initialize Firebase Performance
  - `startTrace(name)` - Start a custom trace
  - `trackOperation(name, operation, metrics, attributes)` - Track async operations
  - `trackSync(name, operation, metrics, attributes)` - Track sync operations (debug only)

#### **PerformanceProvider** (`lib/core/performance/performance_provider.dart`)
- Riverpod provider for PerformanceService singleton
- Enables dependency injection across the app

---

### **2. Custom Traces Implemented**

#### **Investment CRUD Operations**
| Trace Name | Operation | Metrics | Attributes |
|------------|-----------|---------|------------|
| `investment_create` | Create investment | - | `investment_type` |
| `investment_update` | Update investment | - | `investment_type`, `is_archived` |
| `investment_delete` | Delete investment | - | `investment_type` |
| `investment_bulk_import` | Bulk import | `investment_count`, `cash_flow_count` | - |

**File:** `lib/features/investment/presentation/providers/investment_notifier.dart`

---

#### **XIRR Calculation**
| Trace Name | Operation | Metrics | Attributes |
|------------|-----------|---------|------------|
| `xirr_calculation` | Calculate XIRR (active) | `cash_flow_count` | - |
| `xirr_calculation_archived` | Calculate XIRR (archived) | `cash_flow_count` | - |

**File:** `lib/features/investment/presentation/providers/investment_stats_provider.dart`

**Note:** XIRR calculation already uses `compute()` for background processing. Performance tracking wraps this to measure total time including isolate overhead.

---

#### **Goal Progress Calculation**
| Trace Name | Operation | Metrics | Attributes |
|------------|-----------|---------|------------|
| `goal_progress_calculation` | Calculate all goal progress | `goal_count`, `investment_count`, `cash_flow_count` | - |

**File:** `lib/features/goals/presentation/providers/goal_progress_provider.dart`

**Note:** This is a synchronous operation, so tracking is debug-only (logs execution time in debug mode).

---

### **3. Initialization**

Performance monitoring is initialized in `main.dart` during app startup:
- Runs in background (non-blocking)
- Initializes after Firebase Core
- Logs initialization status in debug mode

---

## 📦 Dependencies Added

```yaml
firebase_performance: ^0.10.0+8
```

---

## 🔍 How It Works

### **Async Operations (trackOperation)**
```dart
await performanceService.trackOperation(
  'investment_create',
  () => repository.createInvestment(investment),
  attributes: {'investment_type': type.name},
);
```

1. Starts a Firebase Performance trace
2. Adds attributes before operation
3. Executes the operation
4. Adds metrics after operation
5. Stops the trace
6. Returns the operation result

### **Sync Operations (trackSync)**
```dart
final result = performanceService.trackSync(
  'goal_progress_calculation',
  () => calculateProgress(),
  metrics: {'goal_count': goals.length},
);
```

1. In debug mode: Logs execution time
2. In production: Just executes the operation
3. Returns the operation result

---

## 📈 Metrics Tracked

### **Performance Metrics (Automatic)**
- **Duration** - Time taken for each operation
- **Success Rate** - Percentage of successful operations
- **Network Latency** - Firestore operation latency (automatic)

### **Custom Metrics**
- **Investment Count** - Number of investments in bulk operations
- **Cash Flow Count** - Number of cash flows processed
- **Goal Count** - Number of goals calculated

### **Custom Attributes**
- **Investment Type** - Type of investment (FD, MF, Stocks, etc.)
- **Is Archived** - Whether investment is archived
- **Operation Type** - Create, Update, Delete

---

## 🎯 Benefits

1. **Identify Bottlenecks** - See which operations are slow
2. **Track Improvements** - Measure impact of optimizations (like .autoDispose)
3. **User Experience** - Understand real-world performance
4. **Production Monitoring** - Track performance in production
5. **Data-Driven Decisions** - Optimize based on actual usage patterns

---

## 📊 Firebase Console

View performance data in Firebase Console:
1. Go to Firebase Console → Performance
2. View custom traces under "Custom Traces"
3. Filter by trace name, time range, app version
4. Analyze percentiles (50th, 90th, 99th)

---

## 🚀 Next Steps

### **Phase 2: Additional Traces (Optional)**
- CSV Export/Import operations
- Document upload/download
- FIRE calculation
- App startup time
- Screen rendering performance

### **Phase 3: Alerts (Optional)**
- Set up performance alerts in Firebase Console
- Alert when operations exceed thresholds
- Monitor regression in performance

---

## ✅ Compliance

- ✅ **Rule 1.1** - Clean layer boundaries (service in core, used via provider)
- ✅ **Rule 3.2** - Proper ref usage (ref.read in callbacks)
- ✅ **Rule 6.2** - No memory leaks (service is singleton)
- ✅ **Privacy** - No sensitive data in traces (only counts and types)

---

**Implementation Date:** 2026-02-11
**Status:** ✅ Complete
**Branch:** `feature/performance-monitoring-setup`

