# Cloud-First Data Architecture

## Overview

This document describes the **Cloud-First** architecture for InvTracker's data synchronization. This replaces the previous offline-first sync approach that had issues with data loss and complex conflict resolution.

## Key Principle

> **Google Sheets is the Single Source of Truth for Google Users.**
> **Local SQLite database is only a cache for fast reads.**

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                           │
│                    (Screens, Widgets, Forms)                     │
└─────────────────────────────────────────────────────────────────┘
                               ↓ ↑
┌─────────────────────────────────────────────────────────────────┐
│                       DATA CONTROLLER                            │
│         (Orchestrates based on user type + connectivity)        │
│                                                                  │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  if (isGoogleUser) {                                     │   │
│   │      if (!hasInternet) → showToast("No internet") → STOP │   │
│   │      cloudRepo.write() → localRepo.cache()               │   │
│   │  } else {  // Guest                                      │   │
│   │      localRepo.write()                                   │   │
│   │  }                                                       │   │
│   └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
           ↓                                      ↓
┌─────────────────────────┐         ┌─────────────────────────────┐
│    CLOUD REPOSITORY     │         │      LOCAL REPOSITORY       │
│    (Google Sheets)      │         │   (SQLite with SQLCipher)   │
│                         │         │                              │
│  - fetchAll()           │         │  - getAll()                  │
│  - add()                │         │  - add()                     │
│  - update()             │         │  - update()                  │
│  - delete()             │         │  - delete()                  │
│                         │         │  - replaceAll()              │
│                         │         │  - clearAll()                │
└─────────────────────────┘         └─────────────────────────────┘
           ↓                                      ↓
┌─────────────────────────┐         ┌─────────────────────────────┐
│   GOOGLE SHEETS API     │         │       DRIFT DATABASE        │
│   (via googleapis)      │         │    (Encrypted SQLite)       │
└─────────────────────────┘         └─────────────────────────────┘
```

---

## User Types & Behavior

| User Type | Data Storage | Internet Required | Offline Capability |
|-----------|--------------|-------------------|-------------------|
| **Guest** | Local only | No | Full offline support |
| **Google** | Cloud (Sheets) + Local cache | Yes (for writes) | Read-only from cache |

---

## Core Flows

### 1. App Start - Guest User

```
App starts
    ↓
Load from local SQLite
    ↓
Display investments
```

### 2. App Start - Google User

```
App starts
    ↓
Check internet
    ├─► No internet → Load from local cache → Show "Offline mode" indicator
    │
    └─► Has internet → Fetch ALL from Google Sheets
                           ↓
                      Replace local cache (DELETE all, INSERT new)
                           ↓
                      Display investments
```

### 3. Add Investment - Guest User

```
User fills form → clicks "Save"
    ↓
Generate UUID for investment
    ↓
INSERT into local SQLite
    ↓
Update UI
```

### 4. Add Investment - Google User

```
User fills form → clicks "Save"
    ↓
Check internet connectivity
    ├─► No internet
    │       → Show toast: "No internet connection. Please try again."
    │       → STOP (no changes anywhere)
    │
    └─► Has internet
            ↓
        Generate UUID for investment
            ↓
        Call Google Sheets API: Append row
            ├─► API FAILED
            │       → Show toast: "Failed to save. Please try again."
            │       → STOP (no local changes)
            │
            └─► API SUCCESS
                    ↓
                INSERT into local SQLite (cache)
                    ↓
                Update UI
                    ↓
                Show success toast
```

### 5. Edit Investment - Google User

```
User edits form → clicks "Save"
    ↓
Check internet connectivity
    ├─► No internet → Show toast → STOP
    │
    └─► Has internet
            ↓
        Call Google Sheets API: Update row (find by ID)
            ├─► API FAILED → Show toast → STOP
            │
            └─► API SUCCESS
                    ↓
                UPDATE in local SQLite (cache)
                    ↓
                Update UI
```

### 6. Delete Investment - Google User

```
User confirms delete
    ↓
Check internet connectivity
    ├─► No internet → Show toast → STOP
    │
    └─► Has internet
            ↓
        Call Google Sheets API: Delete row (find by ID)
            ├─► API FAILED → Show toast → STOP
            │
            └─► API SUCCESS
                    ↓
                DELETE from local SQLite (cache)
                    ↓
                Update UI
```

### 7. Guest → Google Upgrade (Connect Account)

```
User clicks "Connect to Google Account" in Settings
    ↓
Check if local DB has investments
    ↓
┌─────────────────────────────────────────────────────────────────┐
│  LOCAL HAS DATA                                                  │
│                                                                  │
│  Show dialog:                                                    │
│  "You have local data. What would you like to do?"              │
│                                                                  │
│  [Upload to Cloud]     [Use Cloud Data]     [Cancel]            │
│                                                                  │
│  Upload to Cloud:                                                │
│      → Sign in with Google                                       │
│      → Create spreadsheet if not exists                          │
│      → Upload all local data to cloud                            │
│      → Done (local becomes cache)                                │
│                                                                  │
│  Use Cloud Data:                                                 │
│      → Sign in with Google                                       │
│      → Fetch from cloud                                          │
│      → Replace local with cloud data                             │
│      → Done                                                       │
│                                                                  │
│  Cancel:                                                          │
│      → Stay as guest                                              │
└─────────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────────┐
│  LOCAL HAS NO DATA                                               │
│                                                                  │
│  → Sign in with Google                                           │
│  → Fetch from cloud (if exists)                                  │
│  → Store in local cache                                          │
│  → Done                                                           │
└─────────────────────────────────────────────────────────────────┘
```

### 8. Sign Out

```
User clicks "Sign Out"
    ↓
Clear local database (privacy - different user might sign in)
    ↓
Clear auth tokens
    ↓
Navigate to Sign-In screen
```

### 9. Fresh Google Sign-In (No Guest Data)

```
User on Sign-In screen → clicks "Sign in with Google"
    ↓
Authenticate with Google
    ↓
Check if spreadsheet exists in Drive
    ├─► EXISTS → Fetch all data → Store in local cache
    │
    └─► NOT EXISTS → Create spreadsheet → Local cache empty
    ↓
Navigate to Dashboard
```

---

## Interface Definitions

### ConnectivityService

```dart
abstract class ConnectivityService {
  /// Check if device has active internet connection
  Future<bool> hasInternetConnection();

  /// Stream of connectivity changes (for real-time UI updates)
  Stream<bool> get onConnectivityChanged;
}
```

### CloudRepository

```dart
abstract class CloudRepository {
  // ============ INVESTMENTS ============

  /// Fetch all investments from Google Sheets
  /// Returns empty list if spreadsheet doesn't exist
  Future<List<Investment>> fetchAllInvestments();

  /// Add investment to Google Sheets
  /// Returns the investment with cloud-assigned row info
  Future<Investment> addInvestment(Investment investment);

  /// Update investment in Google Sheets (find by ID column)
  Future<void> updateInvestment(Investment investment);

  /// Delete investment from Google Sheets (find by ID column)
  Future<void> deleteInvestment(String investmentId);

  // ============ CASH FLOWS ============

  /// Fetch all cash flows from Google Sheets
  Future<List<CashFlow>> fetchAllCashFlows();

  /// Add cash flow to Google Sheets
  Future<CashFlow> addCashFlow(CashFlow cashFlow);

  /// Update cash flow in Google Sheets
  Future<void> updateCashFlow(CashFlow cashFlow);

  /// Delete cash flow from Google Sheets
  Future<void> deleteCashFlow(String cashFlowId);

  // ============ BULK OPERATIONS ============

  /// Upload all local data to cloud (for guest upgrade)
  Future<void> uploadAll(List<Investment> investments, List<CashFlow> cashFlows);

  /// Check if spreadsheet exists in Google Drive
  Future<bool> hasSpreadsheet();

  /// Create spreadsheet if not exists
  Future<void> ensureSpreadsheetExists();
}
```

### LocalRepository (Cache)

```dart
abstract class LocalRepository {
  // ============ INVESTMENTS ============

  /// Get all investments from local cache
  Future<List<Investment>> getAllInvestments();

  /// Add investment to local cache
  Future<void> addInvestment(Investment investment);

  /// Update investment in local cache
  Future<void> updateInvestment(Investment investment);

  /// Delete investment from local cache
  Future<void> deleteInvestment(String investmentId);

  // ============ CASH FLOWS ============

  Future<List<CashFlow>> getAllCashFlows();
  Future<void> addCashFlow(CashFlow cashFlow);
  Future<void> updateCashFlow(CashFlow cashFlow);
  Future<void> deleteCashFlow(String cashFlowId);

  // ============ BULK OPERATIONS ============

  /// Replace all data in cache (used on app start for Google users)
  Future<void> replaceAllData(List<Investment> investments, List<CashFlow> cashFlows);

  /// Clear all data (used on sign out)
  Future<void> clearAllData();

  /// Check if local has any data
  Future<bool> hasData();

  /// Get count of investments
  Future<int> getInvestmentCount();
}
```

### DataController

```dart
abstract class DataController {
  // ============ INITIALIZATION ============

  /// Initialize data on app start
  /// - Guest: Load from local
  /// - Google: Fetch from cloud, cache locally
  Future<void> initialize();

  // ============ INVESTMENTS ============

  /// Get all investments (always from local cache)
  Future<List<Investment>> getInvestments();

  /// Add investment
  /// - Guest: Local only
  /// - Google: Cloud first, then cache
  Future<Result<Investment>> addInvestment(Investment investment);

  /// Update investment
  Future<Result<void>> updateInvestment(Investment investment);

  /// Delete investment
  Future<Result<void>> deleteInvestment(String investmentId);

  // ============ CASH FLOWS ============

  Future<List<CashFlow>> getCashFlows();
  Future<Result<CashFlow>> addCashFlow(CashFlow cashFlow);
  Future<Result<void>> updateCashFlow(CashFlow cashFlow);
  Future<Result<void>> deleteCashFlow(String cashFlowId);

  // ============ ACCOUNT OPERATIONS ============

  /// Connect guest account to Google
  /// Returns true if successful
  Future<Result<void>> connectToGoogle({required bool uploadLocalData});

  /// Sign out and clear local data
  Future<void> signOut();
}

/// Result type for operations that can fail
class Result<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  Result.success(this.data) : error = null, isSuccess = true;
  Result.failure(this.error) : data = null, isSuccess = false;
}
```


---

## Implementation Phases

### Phase 1: Core Infrastructure

**Goal:** Create the foundational services without touching existing code.

| Task | File | Description |
|------|------|-------------|
| 1.1 | `lib/core/services/connectivity_service.dart` | Internet connectivity checker |
| 1.2 | `lib/core/utils/result.dart` | Result type for error handling |
| 1.3 | `lib/features/sync/domain/repositories/cloud_repository.dart` | Abstract cloud repository interface |
| 1.4 | `lib/features/sync/data/repositories/cloud_repository_impl.dart` | Google Sheets implementation |

### Phase 2: Data Controller

**Goal:** Create the orchestration layer.

| Task | File | Description |
|------|------|-------------|
| 2.1 | `lib/features/data/domain/controllers/data_controller.dart` | Abstract data controller |
| 2.2 | `lib/features/data/data/controllers/data_controller_impl.dart` | Implementation with cloud-first logic |
| 2.3 | `lib/features/data/presentation/providers/data_provider.dart` | Riverpod provider for data controller |

### Phase 3: Update Local Repository

**Goal:** Add cache-specific methods to existing repository.

| Task | File | Description |
|------|------|-------------|
| 3.1 | `lib/features/investments/domain/repositories/investment_repository.dart` | Add `replaceAll`, `clearAll`, `hasData` methods |
| 3.2 | `lib/features/investments/data/repositories/investment_repository_impl.dart` | Implement new methods |
| 3.3 | `lib/features/cashflows/...` | Same for cash flows |

### Phase 4: Update UI Layer

**Goal:** Switch screens to use new DataController instead of direct repository access.

| Task | File | Description |
|------|------|-------------|
| 4.1 | `lib/features/investments/presentation/screens/` | Use DataController for CRUD |
| 4.2 | `lib/features/cashflows/presentation/screens/` | Use DataController for CRUD |
| 4.3 | `lib/features/dashboard/presentation/screens/` | Use DataController for data |
| 4.4 | `lib/features/settings/presentation/screens/` | Update connect/disconnect flows |
| 4.5 | `lib/features/auth/presentation/screens/` | Update sign-in flow |

### Phase 5: App Initialization

**Goal:** Update app startup to use cloud-first initialization.

| Task | File | Description |
|------|------|-------------|
| 5.1 | `lib/app/` | Update app initialization to call DataController.initialize() |
| 5.2 | Loading states | Add loading indicator during cloud fetch |

### Phase 6: Cleanup

**Goal:** Remove old sync code.

| Task | Description |
|------|-------------|
| 6.1 | Remove `SyncService` old methods (import/export/sync) |
| 6.2 | Remove `_hasImportedKey` flags |
| 6.3 | Remove `keepCurrentDbId` logic |
| 6.4 | Remove old sync providers |
| 6.5 | Remove debug sync UI (or update to show cloud status) |

---

## File Structure (New/Modified)

```
lib/
├── core/
│   ├── services/
│   │   └── connectivity_service.dart        ← NEW
│   └── utils/
│       └── result.dart                       ← NEW
│
├── features/
│   ├── data/                                 ← NEW FEATURE
│   │   ├── domain/
│   │   │   └── controllers/
│   │   │       └── data_controller.dart
│   │   ├── data/
│   │   │   └── controllers/
│   │   │       └── data_controller_impl.dart
│   │   └── presentation/
│   │       └── providers/
│   │           └── data_provider.dart
│   │
│   ├── sync/
│   │   ├── domain/
│   │   │   └── repositories/
│   │   │       └── cloud_repository.dart     ← NEW
│   │   └── data/
│   │       └── repositories/
│   │           └── cloud_repository_impl.dart ← NEW
│   │
│   ├── investments/
│   │   ├── domain/repositories/
│   │   │   └── investment_repository.dart    ← MODIFIED (add cache methods)
│   │   └── data/repositories/
│   │       └── investment_repository_impl.dart ← MODIFIED
│   │
│   └── cashflows/
│       └── ... (similar modifications)
```

---

## What Gets Removed

| File/Code | Reason |
|-----------|--------|
| `SyncService.sync()` | Replaced by cloud-first writes |
| `SyncService.importOnLogin()` | Replaced by DataController.initialize() |
| `SyncService.exportToCloud()` | Replaced by CloudRepository.uploadAll() |
| `_hasImportedKey` in SecureStorage | No longer needed - always fetch on start |
| `keepCurrentDbId` parameter | No longer needed - single DB per user |
| Complex sync dialog logic | Replaced by simple cloud-first flow |
| Manual "Sync Now" button | Could keep for manual refresh, but simplified |

---

## Error Handling

### Network Errors

| Scenario | Behavior |
|----------|----------|
| No internet on write | Show toast "No internet connection" → Block action |
| No internet on app start (Google user) | Load from local cache → Show "Offline" indicator |
| API timeout | Show toast "Request timed out. Please try again." |
| API error (500, etc.) | Show toast "Something went wrong. Please try again." |
| Auth token expired | Re-authenticate silently, retry operation |

### Data Errors

| Scenario | Behavior |
|----------|----------|
| Spreadsheet deleted | Create new spreadsheet, start fresh |
| Corrupted spreadsheet | Show error, option to reset |
| Local cache corrupted | Re-fetch from cloud on next start |

---

## Testing Scenarios

### Must-Pass Test Cases

| # | Scenario | Expected Result |
|---|----------|-----------------|
| 1 | Guest adds investment offline | Data saved locally |
| 2 | Google user adds investment online | Data in cloud + local cache |
| 3 | Google user adds investment offline | Toast shown, no data saved |
| 4 | App restart (Google user, online) | Cloud data fetched, cache updated |
| 5 | App restart (Google user, offline) | Local cache displayed, offline indicator |
| 6 | Guest connects to Google (has local data, cloud empty) | Local data uploaded to cloud |
| 7 | Guest connects to Google (has local data, cloud has data) | User chooses which to keep |
| 8 | Guest connects to Google (no local data, cloud has data) | Cloud data downloaded |
| 9 | Sign out | Local data cleared |
| 10 | Multi-device: Add on Device A, open Device B | Device B sees new data after restart |

---

## Security Considerations

1. **Local cache encryption**: Continue using SQLCipher for local database
2. **Token storage**: Continue using FlutterSecureStorage for auth tokens
3. **Clear on sign-out**: Always clear local data when signing out (different user might sign in)
4. **HTTPS only**: All cloud API calls over HTTPS

---

## Future Enhancements (Out of Scope)

- Real-time sync (WebSocket/Firebase)
- Conflict resolution with merge
- Version history / undo
- Shared portfolios
- Background sync
