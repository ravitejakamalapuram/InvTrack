# InvTracker — Complete Product Requirements Document (PRD)

> **Version 2.1** — Production-Ready Edition (Final)

---

## 1. Overview

InvTracker is a mobile investment tracking application, built with an **offline-first architecture**, allowing users to manage inflows and outflows of capital for different investments and compute return metrics like **XIRR, TWRR, CAGR, IRR, MOIC, and Profit/Loss**.

All data is stored in:
- **Local SQLite database** (primary runtime database)
- **A protected Google Sheet** in the user's Google Drive (cloud persistence)

InvTracker has **no backend server**. Everything is processed client-side.

The app targets both new and experienced investors who need transparency into their portfolio performance, with simple data entry, powerful analytics, and high privacy.

---

## 2. Problem Statement

Most retail investors track their investments in fragmented ways: spreadsheets, notes, WhatsApp exports, ad-hoc apps. Existing tools are:
- Overly complex
- Not offline-friendly
- Require creating yet another account
- Lock the data inside the app
- Lack advanced metrics like XIRR & TWRR

Users need a simple yet powerful way to track how much they invested, how much they withdrew, and what their actual returns are — with **complete ownership over their data**.

**InvTracker solves this by combining:**
> Mobile convenience + Spreadsheet transparency + Instant analytics

---

## 3. Objectives

1. Provide a ledger-style investment tracker that works **100% offline**.
2. Sync and store data in a Google Sheet owned by the user.
3. Compute industry-standard return metrics automatically.
4. Provide dashboards and insights for quick understanding.
5. Ensure data ownership, security, privacy, and extensibility.

---

## 4. Success Metrics (KPIs)

### Core Metrics
| Metric | Target |
|--------|--------|
| Time-to-first-entry | < 30 seconds |
| App open to dashboard render | < 2 seconds |
| Sync success rate | > 99.5% |
| Calculation accuracy tolerance | < 0.01% vs Excel/Sheets |

### Engagement Metrics
- Weekly retention
- Daily active users
- % offline sessions
- Number of entries logged per week

### Reliability
- Crash-free sessions > 99.9%
- Sync conflict rate < 1%

---

## 5. User Personas

### 1. DIY Investor (Primary)
Tracks multiple instruments manually: stocks, mutual funds, ETFs, crypto, gold.

### 2. Finance-Savvy Professional
Requires XIRR/TWRR accuracy, performance attribution.

### 3. Casual Saver
Needs quick views: how much invested and current value.

### 4. Privacy-conscious User
Wants local-only processing + own Google Drive as storage.

---

## 6. Core Features

### 6.1 Investment Management
- Create/edit/delete Investments
- Free-text investment names
- Optional fields: Category, Notes, Start date

### 6.2 Ledger Entries

**Fields:**
| Field | Description |
|-------|-------------|
| Date | Entry date |
| Type | Inflow / Outflow / Dividend / Expense / Exit / Partial Exit |
| Amount | Transaction amount |
| Units | (optional) |
| Price per unit | (optional) |
| Notes | Free text |
| Currency | Currency code |

### 6.3 Calculations

Per investment and portfolio:
- **XIRR**
- **TWRR**
- **CAGR**
- **IRR**
- **MOIC**
- **Profit/Loss** (realized + unrealized)

### 6.4 Dashboards
- Portfolio Overview
- KPIs summary
- **Graphs:**
  - Value over time
  - Contributions vs Returns
  - Allocation pie chart
  - Investment comparison

### 6.5 Offline-first

All operations work offline:
- Add investments
- Add entries
- View analytics (from local cache)
- Background sync when network returns

### 6.6 Sync to Google Sheets
- Automatic sheet creation
- Single sheet for all entries
- Sheet protection to prevent accidental edits
- Hidden metadata tab
- Conflict detection and resolution UI

### 6.7 Security
- Google OAuth sign-in
- Secure token storage
- Optional biometrics / passcode lock

---

## 7. Acceptance Criteria (Per Feature)

### 7.1 Investment Management

| ID | Criteria | Priority |
|----|----------|----------|
| INV-AC-01 | User can create investment with name only (minimum required field) | P0 |
| INV-AC-02 | Investment name must be unique within user's portfolio | P0 |
| INV-AC-03 | User can edit investment name, category, notes anytime | P0 |
| INV-AC-04 | Deleting investment requires confirmation modal | P0 |
| INV-AC-05 | Deleting investment archives all associated entries (soft delete) | P0 |
| INV-AC-06 | Investment creation works offline | P0 |
| INV-AC-07 | Category dropdown shows predefined + custom categories | P1 |

### 7.2 Ledger Entries

| ID | Criteria | Priority |
|----|----------|----------|
| LED-AC-01 | When user adds entry offline, it appears immediately in UI | P0 |
| LED-AC-02 | If sync fails, entry shows "pending" indicator with retry option | P0 |
| LED-AC-03 | Editing an entry triggers conflict resolution if remote differs | P0 |
| LED-AC-04 | Amount field must not allow invalid characters (letters, special chars except decimal) | P0 |
| LED-AC-05 | Amount must be positive and > 0 | P0 |
| LED-AC-06 | Date picker defaults to today, allows past dates only | P0 |
| LED-AC-07 | Entry type selection is mandatory before saving | P0 |
| LED-AC-08 | Units and price_per_unit auto-calculate if one is provided with amount | P1 |
| LED-AC-09 | Duplicate entry warning if same date + amount + type exists | P1 |
| LED-AC-10 | Bulk delete entries with multi-select | P2 |

### 7.3 Calculations

| ID | Criteria | Priority |
|----|----------|----------|
| CALC-AC-01 | XIRR calculation tolerance < 0.01% vs Excel XIRR function | P0 |
| CALC-AC-02 | XIRR shows "N/A" if insufficient data (< 2 cashflows) | P0 |
| CALC-AC-03 | XIRR shows "N/A" if no solution converges after 1000 iterations | P0 |
| CALC-AC-04 | All metrics recalculate within 100ms of new entry | P0 |
| CALC-AC-05 | Current value must be entered manually or via last outflow | P1 |
| CALC-AC-06 | Historical calculations cached and invalidated on new entries only | P1 |

### 7.4 Sync

| ID | Criteria | Priority |
|----|----------|----------|
| SYNC-AC-01 | First sync creates sheet with correct schema automatically | P0 |
| SYNC-AC-02 | Sync queue processes in FIFO order | P0 |
| SYNC-AC-03 | Failed sync retries 3 times with exponential backoff (2s, 4s, 8s) | P0 |
| SYNC-AC-04 | User can trigger manual sync from settings | P0 |
| SYNC-AC-05 | Conflict modal shows both versions with diff highlighting | P0 |
| SYNC-AC-06 | Sync status indicator visible on home screen | P0 |
| SYNC-AC-07 | Sync completes within 5 seconds for < 100 pending items | P1 |
| SYNC-AC-08 | Large sync (1000+ items) shows progress indicator | P1 |

### 7.5 Dashboard

| ID | Criteria | Priority |
|----|----------|----------|
| DASH-AC-01 | Dashboard loads within 2 seconds of app open | P0 |
| DASH-AC-02 | Portfolio value displays with 2 decimal places | P0 |
| DASH-AC-03 | Graphs render within 500ms | P0 |
| DASH-AC-04 | Empty state shows onboarding prompt for first-time users | P0 |
| DASH-AC-05 | Pull-to-refresh triggers sync + recalculation | P1 |
| DASH-AC-06 | Date range filter applies to all dashboard widgets | P1 |

### 7.6 Security

| ID | Criteria | Priority |
|----|----------|----------|
| SEC-AC-01 | App requires re-authentication after 30 days of inactivity | P0 |
| SEC-AC-02 | Biometric unlock works with Face ID / Touch ID / Fingerprint | P0 |
| SEC-AC-03 | Passcode must be 6 digits minimum | P0 |
| SEC-AC-04 | 5 failed passcode attempts locks app for 5 minutes | P0 |
| SEC-AC-05 | Tokens never logged or exposed in crash reports | P0 |

---

## 8. Non-Functional Requirements

### Performance

| Requirement | Target |
|-------------|--------|
| Local DB queries | < 100ms |
| Charts render | < 500ms |
| App cold start | < 2s |
| Background sync | < 30s for 1000 entries |

### Compatibility
- Android 8+
- iOS 13+

### Data Ownership
- All data stored in user's Google Drive
- No backend retains data

### Scalability
- Must handle >= 10,000 ledger entries without slowdown

### Storage Footprint

| Data Type | Approximate Size |
|-----------|------------------|
| Single entry (SQLite) | ~500 bytes |
| Single entry (Sheet row) | ~1 KB |
| 1,000 entries | ~1.5 MB local |
| 10,000 entries | ~15 MB local |
| App binary | ~25 MB |
| Max recommended entries | 50,000 |

---

## 9. System Architecture

### Frontend
- **Flutter**
- Provider/Bloc architecture
- SQLite for storage
- Local caching & memoized calculations

### External Services
- Google Sign-In API
- Google Drive API
- Google Sheets API

### Data Flow
```
User → Mobile App → Local DB
Local DB ↔ Sync Queue ↔ Google Sheets
Google Sheets → Drive Storage
```

---

## 10. Offline-First Architecture

### Why offline-first?
- User may travel or have bad connectivity
- Must allow data entry anytime
- Ensures smooth UX

### Strategy

| Operation | Offline Behavior | Online Behavior |
|-----------|------------------|-----------------|
| Add entry | Writes to local DB + sync queue | Processes sync queue |
| Edit entry | Updates local DB | Syncs diff |
| View dashboards | Uses cached calculations | Updates in background |
| First login | Requires online only once | Normal operation afterwards |

---

## 11. Sync Engine Specification

### Queues
A `sync_queue` table stores pending operations:
- `create`
- `update`
- `delete`

### Sync Cycle
1. If network available:
   - Dequeue items in batches
   - Append/update rows in Google Sheet
   - Update `_meta` sheet timestamp
   - Pull remote updates
   - Compare timestamps → detect conflicts
   - User sees conflict UI if needed

### Conflict Policy
- Remote `updated_at` > local → potential conflict
- User chooses:
  - **Keep Local**
  - **Keep Remote**
  - **Manual Merge**

### Auto-Merge Rules (No User Prompt)

| Scenario | Auto-Merge Action |
|----------|-------------------|
| Only `note` differs | Keep longer note, append if both non-empty |
| Only `category` differs | Keep remote (assumes intentional categorization) |
| Only `updated_at` differs | Keep latest, no data conflict |
| Local has extra fields | Merge: remote data + local extras |
| Remote has extra fields | Merge: local data + remote extras |
| Whitespace-only changes | Ignore, keep local |

### Conflict Severity Levels

| Level | Fields | Action |
|-------|--------|--------|
| **Critical** | amount, date, type, investment_id | Always prompt user |
| **Medium** | units, price_per_unit, currency | Prompt if both changed |
| **Low** | note, category | Auto-merge when possible |

### Conflict Resolution UI

```
┌─────────────────────────────────────────────────────────────┐
│  ⚠️ Conflict Detected                                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Investment: HDFC FlexiCap                                  │
│  Entry Date: 2024-01-15                                     │
│                                                             │
│  ┌─────────────────────┐   ┌─────────────────────┐          │
│  │ 📱 This Device      │   │ ☁️ Cloud            │          │
│  ├─────────────────────┤   ├─────────────────────┤          │
│  │ Amount: ₹10,000     │   │ Amount: ₹15,000 ⚠️  │          │
│  │ Type: Inflow        │   │ Type: Inflow        │          │
│  │ Note: SIP           │   │ Note: Monthly SIP   │          │
│  └─────────────────────┘   └─────────────────────┘          │
│                                                             │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │ Keep Local   │ │ Keep Cloud   │ │ View Both    │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Detailed Sync Sequence Diagram

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
│  User    │     │   App    │     │ Local DB │     │  Sheets  │
└────┬─────┘     └────┬─────┘     └────┬─────┘     └────┬─────┘
     │                │                │                │
     │ Add Entry      │                │                │
     │───────────────>│                │                │
     │                │ Write Entry    │                │
     │                │───────────────>│                │
     │                │                │                │
     │                │ Queue Sync Op  │                │
     │                │───────────────>│                │
     │                │                │                │
     │ Entry Saved ✓  │                │                │
     │<───────────────│                │                │
     │                │                │                │
     │                │ [Network Available]             │
     │                │                │                │
     │                │ Batch Dequeue  │                │
     │                │<───────────────│                │
     │                │                │                │
     │                │ Append Rows    │                │
     │                │───────────────────────────────>│
     │                │                │                │
     │                │                │   Success ✓   │
     │                │<───────────────────────────────│
     │                │                │                │
     │                │ Update Status  │                │
     │                │───────────────>│                │
     │                │                │                │
     │ Sync Complete  │                │                │
     │<───────────────│                │                │
     │                │                │                │
```

### Multi-Device Sync Behavior

```
Device A                    Google Sheets                    Device B
   │                             │                              │
   │ Add Entry #1                │                              │
   │────────────────────────────>│                              │
   │                             │                              │
   │                             │ Pull Changes                 │
   │                             │<─────────────────────────────│
   │                             │                              │
   │                             │ Entry #1                     │
   │                             │─────────────────────────────>│
   │                             │                              │
   │                             │ Add Entry #2                 │
   │                             │<─────────────────────────────│
   │                             │                              │
   │ Pull Changes                │                              │
   │<────────────────────────────│                              │
   │                             │                              │
   │ Entry #2                    │                              │
   │<────────────────────────────│                              │
   │                             │                              │
```

### Conflict Detection Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    CONFLICT DETECTION                        │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │ Pull Remote Changes   │
              └───────────┬───────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │ For Each Remote Row   │
              └───────────┬───────────┘
                          │
                          ▼
              ┌───────────────────────┐
              │ Find Local by ID      │
              └───────────┬───────────┘
                          │
            ┌─────────────┴─────────────┐
            ▼                           ▼
    ┌───────────────┐           ┌───────────────┐
    │ Not Found     │           │ Found         │
    └───────┬───────┘           └───────┬───────┘
            │                           │
            ▼                           ▼
    ┌───────────────┐           ┌───────────────┐
    │ Insert Local  │           │ Compare Dates │
    └───────────────┘           └───────┬───────┘
                                        │
                    ┌───────────────────┼───────────────────┐
                    ▼                   ▼                   ▼
            ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
            │ Remote > Local│   │ Local > Remote│   │ Dates Equal   │
            └───────┬───────┘   └───────┬───────┘   └───────┬───────┘
                    │                   │                   │
                    ▼                   ▼                   ▼
            ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
            │ Mark Conflict │   │ Push Local    │   │ No Action     │
            └───────────────┘   └───────────────┘   └───────────────┘
```

### Failure Scenarios & Recovery

| Scenario | Detection | Recovery Action |
|----------|-----------|-----------------|
| Network timeout during push | API returns timeout error | Retry with exponential backoff (2s→4s→8s→16s) |
| Partial batch failure | Some rows return error | Retry failed rows only, mark successful ones |
| OAuth token expired | 401 response | Trigger silent refresh, retry; if fails, prompt re-auth |
| Sheet deleted | 404 on sheet access | Prompt: "Sheet not found. Recreate or restore?" |
| Sheet corrupted | Schema validation fails | Prompt: "Data mismatch. Reset sheet?" with backup option |
| Quota exceeded | 429 response | Backoff for 60s, show "Sync paused" indicator |
| Device offline mid-sync | Network change detected | Pause sync, queue remainder, resume when online |
| App killed during sync | Incomplete queue on restart | Resume from last unprocessed queue item |

### Large Dataset Sync Rules

| Dataset Size | Strategy |
|--------------|----------|
| < 100 items | Single batch, immediate sync |
| 100 - 500 items | 50-item batches, 500ms delay between |
| 500 - 2000 items | 100-item batches, progress indicator |
| > 2000 items | Background sync, notification on complete |

### Schema Version Migration

```
Current Schema: v1.0
┌─────────────────────────────────────────────────────────────┐
│                  SCHEMA UPGRADE FLOW                         │
└─────────────────────────────────────────────────────────────┘

1. App Update Detected (schema v1.0 → v1.1)
2. Read current _meta.schema_version
3. If remote version < app version:
   a. Backup current sheet (create copy)
   b. Apply migration scripts in order
   c. Update _meta.schema_version
   d. Validate migrated data
4. If remote version > app version:
   a. Show "Update Required" modal
   b. Block sync until app updated
5. Resume normal sync
```

---

## 12. Google Sheets Schema

### Main Sheet: `InvTracker_Master`

| Column | Description |
|--------|-------------|
| id | UUID |
| user_id | Google user ID |
| investment_id | UUID |
| investment_name | Free text |
| category | Optional |
| date | ISO format YYYY-MM-DD |
| type | inflow/outflow/etc |
| amount | integer (minor units) |
| currency | INR/USD/etc |
| units | optional |
| price_per_unit | optional |
| running_value | optional |
| transaction_id | optional |
| note | string |
| created_at | timestamp |
| updated_at | timestamp |
| source | app/sheet/import |
| sync_status | synced/pending/conflict |
| meta | JSON reserved |

### Meta Sheet: `_meta`
- `sheet_version`
- `last_sync_at`
- `app_key` (checksum)
- `schema_version`

---

## 13. Data Model (Local SQLite)

### Tables

#### 1. Users
```sql
id, google_user_id, email, display_name, last_sync
```

#### 2. Investments
```sql
investment_id, name, category, start_date, notes
```

#### 3. Entries
```sql
id, investment_id, date, type, amount, units,
price_per_unit, note, created_at, updated_at, sync_status
```

#### 4. Sync Queue
```sql
op_id, target_id, op_type, payload_json
```

#### 5. Settings
```sql
key, value
```

#### 6. Schema Migrations
```sql
version, applied_at, description
```

### Database Indexes

```sql
-- Performance indexes for common queries
CREATE INDEX idx_entries_investment ON entries(investment_id);
CREATE INDEX idx_entries_date ON entries(date);
CREATE INDEX idx_entries_type ON entries(type);
CREATE INDEX idx_entries_sync_status ON entries(sync_status);
CREATE INDEX idx_entries_investment_date ON entries(investment_id, date);
CREATE INDEX idx_sync_queue_created ON sync_queue(created_at);
CREATE INDEX idx_sync_queue_op_type ON sync_queue(op_type);
CREATE INDEX idx_investments_category ON investments(category);
```

### Local Database Migration Policy

#### Version Table
```sql
CREATE TABLE schema_migrations (
  version INTEGER PRIMARY KEY,
  applied_at TEXT NOT NULL,
  description TEXT,
  rollback_sql TEXT
);
```

#### Migration Rules

| Rule | Description |
|------|-------------|
| Forward-only | Migrations are applied in order, never skipped |
| Idempotent | Running same migration twice has no effect |
| Backward compatible | Old app versions can read new schema (add columns, not remove) |
| Rollback support | Each migration stores rollback SQL for emergencies |
| Atomic | Each migration runs in transaction |

#### Migration Flow

```
App Start
    │
    ▼
┌─────────────────────────┐
│ Read current DB version │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Compare to app version  │
└───────────┬─────────────┘
            │
    ┌───────┴───────┐
    ▼               ▼
  Same?           Older?
    │               │
    ▼               ▼
  Continue      Apply pending
                migrations
                    │
                    ▼
              Validate schema
                    │
                    ▼
                Continue
```

#### Example Migrations

```dart
// Migration v1 → v2: Add currency column
final migration_v2 = Migration(
  version: 2,
  description: 'Add currency column to entries',
  up: '''
    ALTER TABLE entries ADD COLUMN currency TEXT DEFAULT 'INR';
  ''',
  down: '''
    -- SQLite doesn't support DROP COLUMN, use workaround
    CREATE TABLE entries_backup AS SELECT id, investment_id, date, type,
      amount, units, price_per_unit, note, created_at, updated_at, sync_status
    FROM entries;
    DROP TABLE entries;
    ALTER TABLE entries_backup RENAME TO entries;
  ''',
);
```

### Device Storage Encryption

| Component | Implementation |
|-----------|----------------|
| Encryption library | SQLCipher (AES-256-XTS) |
| Key derivation | PBKDF2 with 256,000 iterations |
| Key storage | iOS Keychain / Android Keystore |
| Key rotation | On passcode change |
| Memory protection | Key cleared from memory after use |

```dart
// SQLCipher initialization
final db = await openDatabase(
  path,
  password: await KeychainService.getDatabaseKey(),
  options: OpenDatabaseOptions(
    version: SCHEMA_VERSION,
    onCreate: _createTables,
    onUpgrade: _runMigrations,
  ),
);
```

---

## 14. Calculations Module

### 14.1 XIRR (Extended Internal Rate of Return)

**Formula:**
```
Σ (Cashflow_i / (1 + XIRR)^((Date_i - Date_0) / 365)) = 0
```

**Algorithm:**
1. Initial guess: 10%
2. Newton-Raphson iteration: `XIRR_new = XIRR_old - f(XIRR) / f'(XIRR)`
3. Convergence threshold: |f(XIRR)| < 1e-7
4. Max iterations: 1000
5. Fallback: Bisection method if Newton fails

**Data Requirements:**
- Minimum 2 cashflows (1 inflow + 1 outflow/current value)
- At least 1 day between first and last cashflow

**Edge Cases:**
| Scenario | Result |
|----------|--------|
| All inflows, no outflows | Requires current value input |
| Single cashflow | Returns "N/A" |
| No convergence | Returns "N/A" with error flag |
| Negative XIRR > -100% | Valid result |

### 14.2 TWRR (Time-Weighted Rate of Return)

**Formula:**
```
TWRR = [(1 + R_1) × (1 + R_2) × ... × (1 + R_n)] - 1

Where R_i = (Ending_Value_i - Beginning_Value_i - Cashflow_i) / Beginning_Value_i
```

**Algorithm:**
1. Identify all cashflow dates as period boundaries
2. Calculate sub-period returns between each boundary
3. Geometrically link all sub-period returns
4. Annualize if period > 1 year

**Data Requirements:**
- Portfolio value at each cashflow date
- If value not provided, interpolate linearly between known values

### 14.3 IRR (Internal Rate of Return)

**Formula:**
```
Σ (Cashflow_t / (1 + IRR)^t) = 0
```

**Usage:** Applied when cashflows are at regular intervals (monthly/quarterly).
Falls back to XIRR for irregular intervals.

### 14.4 CAGR (Compound Annual Growth Rate)

**Formula:**
```
CAGR = (Ending_Value / Beginning_Value)^(1 / Years) - 1

Where Years = (End_Date - Start_Date) / 365.25
```

**Data Requirements:**
- Beginning value (first inflow or sum of initial inflows)
- Ending value (current value or sum of all outflows)
- Time period > 0

### 14.5 MOIC (Multiple on Invested Capital)

**Formula:**
```
MOIC = (Total_Distributions + Current_Value) / Total_Invested

Where:
- Total_Distributions = Sum of all outflows (dividends, partial exits, full exits)
- Total_Invested = Sum of all inflows
```

**Interpretation:**
| MOIC | Meaning |
|------|---------|
| < 1.0 | Loss |
| = 1.0 | Break-even |
| > 1.0 | Profit |
| > 2.0 | Doubled investment |

### 14.6 Profit/Loss Calculation

**Realized P/L:**
```
Realized_PL = Total_Outflows - (Total_Inflows × Proportion_Exited)
```

**Unrealized P/L:**
```
Unrealized_PL = Current_Value - Remaining_Cost_Basis
```

**Total P/L:**
```
Total_PL = Realized_PL + Unrealized_PL
```

### 14.7 Analytics & Insights Algorithms

#### Allocation Calculation
```
Allocation_% = (Investment_Current_Value / Portfolio_Total_Value) × 100
```

#### Contribution vs Return
```
Contribution = Total_Inflows - Total_Outflows (net cash invested)
Return = Current_Value - Contribution
Return_% = (Return / Contribution) × 100
```

#### Top Movers (Daily/Weekly/Monthly)
```
Period_Return = (Value_End - Value_Start - Net_Cashflows) / Value_Start
Rank investments by Period_Return DESC
```

#### Volatility (Standard Deviation)
```
σ = √(Σ(R_i - R_mean)² / (n - 1))
Where R_i = daily/weekly returns
```

#### Best/Worst Investment Windows
```
For each investment:
  Calculate rolling 30/90/365 day returns
  Identify max and min return periods
  Store dates and return values
```

#### Future Insights (Phase 2+)
- Sharpe Ratio: `(R_portfolio - R_riskfree) / σ_portfolio`
- Sortino Ratio: `(R_portfolio - R_target) / σ_downside`
- Maximum Drawdown: `max(Peak - Trough) / Peak`
- Recovery Period: Days from trough to new peak

---

## 15. Screens & User Flows

### 15.1 Onboarding
1. Welcome screen
2. Google Sign-In
3. Permission explanation
4. Sync initialization

### 15.2 Home Dashboard
- Portfolio Value
- Total Invested
- XIRR
- Graph: Portfolio value over time
- Recent cashflows
- Quick actions

### 15.3 Add Entry
- Investment dropdown
- Date picker
- Type selector
- Amount
- Advanced: Units, price, transaction id

### 15.4 Investment Detail
- KPIs (XIRR, CAGR, MOIC)
- Large chart
- Ledger list

### 15.5 Portfolio Analytics
- Allocation pie
- Contribution vs return graph
- Investment-wise comparison

### 15.6 Settings
- Sheet location
- Passcode / Biometrics
- Export to CSV
- Manual sync
- App info

---

## 16. App Navigation Map (Information Architecture)

### 16.1 Screen Hierarchy

```
📱 App Root
├── 🔐 Auth Flow (unauthenticated)
│   ├── Welcome Screen
│   ├── Google Sign-In
│   ├── Permission Explanation
│   └── Initial Sync Loading
│
├── 🏠 Main App (authenticated)
│   ├── [Tab] Home Dashboard
│   │   ├── Portfolio Summary Card
│   │   ├── Quick Stats Row
│   │   ├── Portfolio Graph (expandable)
│   │   ├── Recent Transactions List
│   │   └── FAB → Add Entry (Modal)
│   │
│   ├── [Tab] Investments
│   │   ├── Investment List
│   │   │   └── Investment Card → Investment Detail
│   │   ├── Add Investment (Modal)
│   │   └── Search/Filter Bar
│   │
│   ├── [Tab] Analytics
│   │   ├── Allocation Pie Chart
│   │   ├── Contribution vs Return Graph
│   │   ├── Investment Comparison Table
│   │   ├── Top Movers Section
│   │   └── Date Range Selector
│   │
│   └── [Tab] Settings
│       ├── Account Section
│       │   ├── Profile Info
│       │   └── Sign Out
│       ├── Data Section
│       │   ├── Google Sheet Location
│       │   ├── Manual Sync
│       │   ├── Export to CSV
│       │   └── Import Data
│       ├── Security Section
│       │   ├── Passcode Settings
│       │   ├── Biometric Toggle
│       │   └── Auto-Lock Timer
│       ├── App Section
│       │   ├── Theme (Light/Dark/System)
│       │   ├── Currency Display
│       │   └── Notifications
│       └── About Section
│           ├── App Version
│           ├── Privacy Policy
│           └── Terms of Service
│
└── 📋 Modal Screens (overlay)
    ├── Add Entry Form
    ├── Edit Entry Form
    ├── Conflict Resolution
    ├── Investment Detail
    │   ├── KPI Cards
    │   ├── Performance Graph
    │   └── Ledger List
    └── Date Range Picker
```

### 16.2 Navigation Routes

| Route | Type | Access |
|-------|------|--------|
| `/` | Redirect | → `/home` or `/auth` |
| `/auth/welcome` | Screen | Unauthenticated |
| `/auth/signin` | Screen | Unauthenticated |
| `/auth/permissions` | Screen | Unauthenticated |
| `/home` | Tab | Authenticated |
| `/investments` | Tab | Authenticated |
| `/investments/:id` | Screen | Authenticated |
| `/analytics` | Tab | Authenticated |
| `/settings` | Tab | Authenticated |
| `/settings/security` | Screen | Authenticated |
| `/settings/data` | Screen | Authenticated |
| `/entry/add` | Modal | Authenticated |
| `/entry/edit/:id` | Modal | Authenticated |
| `/conflicts` | Modal | Authenticated |

### 16.3 Deep Links

| Deep Link | Action |
|-----------|--------|
| `invtracker://add` | Open Add Entry modal |
| `invtracker://investment/:id` | Open specific investment |
| `invtracker://sync` | Trigger manual sync |

---

## 17. UX & UI Design Principles

### 17.1 Design System Foundation

#### Spacing System (8px Grid)
| Token | Value | Usage |
|-------|-------|-------|
| `space-xxs` | 4px | Icon padding |
| `space-xs` | 8px | Inline elements |
| `space-sm` | 12px | Component internal |
| `space-md` | 16px | Between components |
| `space-lg` | 24px | Section spacing |
| `space-xl` | 32px | Screen padding |
| `space-xxl` | 48px | Major sections |

#### Typography Scale
| Style | Size | Weight | Line Height | Usage |
|-------|------|--------|-------------|-------|
| Display | 32px | Bold | 40px | Portfolio value |
| H1 | 24px | SemiBold | 32px | Screen titles |
| H2 | 20px | SemiBold | 28px | Section headers |
| H3 | 18px | Medium | 24px | Card titles |
| Body | 16px | Regular | 24px | Primary content |
| Caption | 14px | Regular | 20px | Labels, hints |
| Small | 12px | Regular | 16px | Timestamps |

#### Color Palette

**Light Mode:**
| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | #2563EB | Actions, links |
| `primary-dark` | #1D4ED8 | Pressed states |
| `success` | #10B981 | Positive returns, inflows |
| `danger` | #EF4444 | Negative returns, outflows |
| `warning` | #F59E0B | Pending, conflicts |
| `neutral-900` | #111827 | Primary text |
| `neutral-600` | #4B5563 | Secondary text |
| `neutral-400` | #9CA3AF | Disabled, hints |
| `neutral-100` | #F3F4F6 | Backgrounds |
| `white` | #FFFFFF | Cards, surfaces |

**Dark Mode:**
| Token | Hex | Usage |
|-------|-----|-------|
| `primary` | #3B82F6 | Actions, links |
| `success` | #34D399 | Positive returns |
| `danger` | #F87171 | Negative returns |
| `neutral-50` | #F9FAFB | Primary text |
| `neutral-400` | #9CA3AF | Secondary text |
| `neutral-800` | #1F2937 | Card backgrounds |
| `neutral-900` | #111827 | Screen backgrounds |

### 17.2 Graphing Style Guidelines

| Element | Style |
|---------|-------|
| Line charts | 2px stroke, rounded caps |
| Area fills | 10% opacity of line color |
| Pie charts | 2px white gap between segments |
| Bar charts | 8px border radius, 4px gap |
| Grid lines | 1px, neutral-200 (light) / neutral-700 (dark) |
| Axis labels | Caption style, neutral-600 |
| Tooltips | Card elevation, body text |

#### Graph Colors (Categorical)
```
#2563EB (Blue)
#7C3AED (Purple)
#EC4899 (Pink)
#F59E0B (Amber)
#10B981 (Emerald)
#06B6D4 (Cyan)
#F97316 (Orange)
#8B5CF6 (Violet)
```

### 17.3 Component Patterns

| Component | Behavior |
|-----------|----------|
| Cards | Tap → Navigate, Long-press → Context menu |
| Lists | Pull-to-refresh, Swipe-to-delete |
| Forms | Inline validation, Error shake animation |
| Modals | Swipe down to dismiss, Tap outside to close |
| Buttons | 44px min touch target, Haptic feedback |
| Inputs | Floating labels, Clear button on focus |

### 17.4 Accessibility Requirements

| Requirement | Standard |
|-------------|----------|
| Color contrast | WCAG AA (4.5:1 for text) |
| Touch targets | Minimum 44×44px |
| Font scaling | Support up to 200% |
| Screen readers | Full VoiceOver/TalkBack support |
| Motion | Respect reduced motion preference |
| Focus indicators | Visible 2px outline |

### 17.5 Animation Guidelines

| Animation | Duration | Easing |
|-----------|----------|--------|
| Micro-interactions | 150ms | ease-out |
| Page transitions | 300ms | ease-in-out |
| Modal open/close | 250ms | cubic-bezier(0.4, 0, 0.2, 1) |
| Loading spinners | 1000ms | linear (infinite) |
| Number counting | 500ms | ease-out |

---

## 18. Security

### Token Storage
- Access tokens in secure keystore
- Refresh tokens encrypted

### Data Protection
- Sheet protected with warning-only protection
- `_meta` tab hidden
- App computes checksum to detect tampering

### Privacy
- No data sent to any external server

---

## 19. Error Handling

### Google API Failures
- Retry with exponential backoff
- Provide manual retry option
- Store unsynced rows

### Conflicts
- Shown in conflict center with resolution options

### Sheet Deleted
- Prompt user to recreate sheet or restore from Google Drive trash

---

## 20. Roadmap

### Phase 1
- Google Sign-In
- Local DB
- Ledger
- Basic XIRR/CAGR
- Sheet sync
- Dashboard

### Phase 2
- TWRR
- Benchmark indexes
- Multi-currency
- Export PDF reports
- Alerts

### Phase 3
- Collaboration features
- Auto-import from brokers
- Tax reports
- Premium subscription model

---

## 21. Risks & Mitigation

| Risk | Mitigation |
|------|------------|
| Users manually edit sheet | Protected ranges + conflict detection |
| OAuth refresh failure | Secure token rotation + reauth |
| Data corruption | Checksums + conflict engine |
| Google API quota | Batching + optimized requests |
| Large dataset slowdown | Local DB indexes + lazy loading |

---

## 22. Notifications & Alerts Framework

### 22.1 Notification Categories

| Category | Priority | Channel | User Control |
|----------|----------|---------|--------------|
| Sync Status | Low | In-app only | Always on |
| Sync Errors | High | Push + In-app | Cannot disable |
| Conflicts | High | Push + In-app | Cannot disable |
| Price Alerts | Medium | Push + In-app | Configurable |
| Milestone Alerts | Medium | Push + In-app | Configurable |
| Weekly Summary | Low | Push | Configurable |
| Security Alerts | Critical | Push + In-app | Cannot disable |

### 22.2 Trigger Conditions

| Notification | Trigger | Content |
|--------------|---------|---------|
| Sync Complete | Background sync finishes | "✓ Data synced successfully" |
| Sync Failed | 3 retry failures | "⚠️ Sync failed. Tap to retry." |
| Conflict Detected | Remote/local mismatch | "🔄 {n} conflicts need attention" |
| XIRR Milestone | XIRR crosses 10%, 20%, 50% | "🎉 {Investment} hit {X}% XIRR!" |
| Loss Alert | Investment drops > 10% | "📉 {Investment} down {X}% this week" |
| Weekly Summary | Sunday 9 AM local | "📊 Your weekly portfolio update" |
| Session Timeout | Token expires in 7 days | "🔐 Please re-authenticate" |

### 22.3 Frequency Limits

| Notification Type | Max Frequency |
|-------------------|---------------|
| Price/Performance alerts | 1 per investment per day |
| Sync status | 1 per sync cycle |
| Weekly summary | 1 per week |
| Security alerts | Immediate, no limit |

### 22.4 User Preferences Schema

```json
{
  "notifications": {
    "push_enabled": true,
    "weekly_summary": true,
    "weekly_summary_day": "sunday",
    "weekly_summary_time": "09:00",
    "price_alerts": true,
    "milestone_alerts": true,
    "quiet_hours": {
      "enabled": true,
      "start": "22:00",
      "end": "08:00"
    }
  }
}
```

---

## 23. App Settings Specification (Detailed)

### 23.1 Account Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| Display Name | Text | User input | From Google |
| Email | Read-only | — | From Google |
| Profile Photo | Image | From Google | — |
| Sign Out | Action | — | — |
| Delete Account | Action | Confirmation required | — |

### 23.2 Data Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| Google Sheet Location | Link | Opens sheet in browser | — |
| Manual Sync | Action | Triggers immediate sync | — |
| Last Sync Time | Read-only | Timestamp | — |
| Sync Status | Read-only | Synced/Pending/Error | — |
| Export to CSV | Action | Downloads file | — |
| Export to PDF | Action | Generates report | — |
| Import Data | Action | From CSV/Excel | — |
| Reset Local Data | Action | Clears cache, re-syncs | — |
| Delete All Data | Action | Irreversible, confirmation | — |

### 23.3 Security Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| Passcode | Toggle | Enable/Disable | Off |
| Set Passcode | Action | 6-digit entry | — |
| Change Passcode | Action | Verify old, set new | — |
| Biometric Unlock | Toggle | Enable/Disable | Off (if passcode on) |
| Auto-Lock | Dropdown | Immediate/1min/5min/15min | 5 min |
| Require on Launch | Toggle | Yes/No | Yes |

### 23.4 Display Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| Theme | Dropdown | Light/Dark/System | System |
| Primary Currency | Dropdown | INR/USD/EUR/GBP/etc. | INR |
| Number Format | Dropdown | 1,234.56 / 1.234,56 | Locale |
| Date Format | Dropdown | DD/MM/YYYY / MM/DD/YYYY / YYYY-MM-DD | Locale |
| Show Decimals | Toggle | 2 decimals / Round | 2 decimals |

### 23.5 Notification Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| Push Notifications | Toggle | On/Off | On |
| Weekly Summary | Toggle | On/Off | On |
| Summary Day | Dropdown | Mon-Sun | Sunday |
| Summary Time | Time picker | — | 9:00 AM |
| Price Alerts | Toggle | On/Off | On |
| Quiet Hours | Toggle | On/Off | Off |
| Quiet Start | Time picker | — | 10:00 PM |
| Quiet End | Time picker | — | 8:00 AM |

#### Quiet Hours Enforcement Logic

```dart
bool shouldDeliverNotification(Notification notification) {
  // Critical notifications always bypass quiet hours
  if (notification.priority == Priority.CRITICAL) {
    return true;
  }

  final now = DateTime.now();
  final quietStart = settings.quietHoursStart; // e.g., 22:00
  final quietEnd = settings.quietHoursEnd;     // e.g., 08:00

  // Handle overnight quiet hours (22:00 - 08:00)
  if (quietStart > quietEnd) {
    if (now.hour >= quietStart.hour || now.hour < quietEnd.hour) {
      return false; // In quiet hours
    }
  } else {
    if (now.hour >= quietStart.hour && now.hour < quietEnd.hour) {
      return false; // In quiet hours
    }
  }

  return true;
}
```

| Notification Type | Bypasses Quiet Hours |
|-------------------|----------------------|
| Security alerts | ✅ Yes |
| Sync failures | ✅ Yes |
| Conflict detected | ❌ No (queued) |
| Weekly summary | ❌ No (rescheduled) |
| Price alerts | ❌ No (queued) |

### 23.6 Advanced Settings

| Setting | Type | Options | Default |
|---------|------|---------|---------|
| Debug Mode | Toggle | On/Off | Off |
| Clear Cache | Action | Clears calculations cache | — |
| View Sync Queue | Action | Shows pending items | — |
| Conflict History | Link | Past conflict resolutions | — |
| Error Logs | Action | Export for support | — |

### 23.7 About Section

| Item | Type |
|------|------|
| App Version | Read-only |
| Build Number | Read-only |
| Privacy Policy | Link |
| Terms of Service | Link |
| Open Source Licenses | Link |
| Rate App | Link to store |
| Contact Support | Email/Form |

### 23.8 Confirmation Flows (Critical Actions)

| Action | Confirmation Required | Steps |
|--------|----------------------|-------|
| Sign Out | Yes | "Are you sure? Unsynced data will remain on device." |
| Delete Account | Double confirmation | 1) "This will delete all local data" 2) Type "DELETE" to confirm |
| Delete All Data | Double confirmation | 1) Warning modal 2) Type investment count to confirm |
| Reset Local Data | Yes | "This will clear cache and re-sync from Google Sheet" |
| Change Passcode | Verify old first | Enter current → Enter new → Confirm new |
| Disable Passcode | Verify current | Enter current passcode to disable |
| Recreate Sheet | Yes | "This will create a new sheet. Old sheet will remain in Drive." |
| Import Data | Yes | "This will merge with existing data. Conflicts will be flagged." |
| Clear Cache | Yes | "Calculations will be re-computed on next view." |

### 23.9 Confirmation Modal Templates

```
┌─────────────────────────────────────────────────────────────┐
│  ⚠️ Delete All Data                                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  This action cannot be undone.                              │
│                                                             │
│  You have:                                                  │
│  • 12 investments                                           │
│  • 847 entries                                              │
│  • 3 unsynced changes                                       │
│                                                             │
│  Type "DELETE 12" to confirm:                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                                                     │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌──────────────┐              ┌──────────────┐            │
│  │   Cancel     │              │   Delete     │            │
│  └──────────────┘              └──────────────┘            │
│                                 (disabled until typed)      │
└─────────────────────────────────────────────────────────────┘
```

---

## 24. Data Backup & Recovery

### 24.1 Backup Strategy

| Backup Type | Method | Frequency |
|-------------|--------|-----------|
| Primary | Google Sheet sync | Real-time |
| Secondary | Sheet version history | Automatic (Google) |
| Manual | CSV/PDF export | User-initiated |
| Emergency | Local DB copy | On schema migration |

### 24.2 Recovery Actions

| Scenario | Recovery Steps |
|----------|----------------|
| Local data corrupted | 1) Clear local DB 2) Full re-sync from Sheet |
| Sheet accidentally deleted | 1) Restore from Drive trash 2) Re-link in app |
| Wrong data synced | 1) Use Sheet version history 2) Restore previous version 3) Re-sync |
| App uninstalled | 1) Reinstall 2) Sign in 3) Automatic restore from Sheet |
| New device | 1) Sign in with same Google account 2) Sheet auto-detected 3) Full sync |

### 24.3 Backup Sheet Copy

```
On demand or before risky operations:
1. Create copy: "InvTracker_Backup_YYYY-MM-DD"
2. Store in same Drive folder
3. Keep last 3 backups, delete older
4. Log backup in _meta sheet
```

### 24.4 Rehydration Flow (Restore from Sheet)

```
┌─────────────────────────────────────────────────────────────┐
│                    REHYDRATION FLOW                          │
└─────────────────────────────────────────────────────────────┘

1. User triggers "Restore from Cloud"
2. Confirmation: "This will replace all local data"
3. Create local backup (optional)
4. Clear local DB (keep settings)
5. Fetch all rows from Sheet
6. Validate each row
7. Insert into local DB
8. Rebuild indexes
9. Recalculate all metrics
10. Show completion summary
```

### 24.5 Force Full Reset

| Step | Action |
|------|--------|
| 1 | Export current data to CSV (optional) |
| 2 | Sign out |
| 3 | Clear app data |
| 4 | Reinstall (optional) |
| 5 | Sign in |
| 6 | Choose: Create new sheet OR Link existing |

---

## 25. Google Sheet Validation Rules

### 25.1 Schema Validation on Sync

| Check | Action on Failure |
|-------|-------------------|
| Sheet exists | Prompt to create/restore |
| All required columns present | Add missing columns automatically |
| Column order correct | Reorder silently if data intact |
| _meta sheet exists | Create with defaults |
| schema_version compatible | Trigger migration or block |

### 25.2 Row-Level Validation

| Field | Validation Rule | On Failure |
|-------|-----------------|------------|
| id | UUID format, unique | Reject row, log error |
| investment_id | Must exist in investments | Mark orphaned |
| date | Valid ISO date | Use created_at as fallback |
| type | One of allowed values | Default to "inflow" |
| amount | Positive integer | Absolute value |
| currency | 3-letter code | Default to primary currency |
| created_at | Valid timestamp | Use current time |
| updated_at | Valid timestamp | Use current time |

### 25.3 Corruption Detection

| Corruption Type | Detection Method | Recovery |
|-----------------|------------------|----------|
| Missing columns | Schema diff on sync | Add columns with NULL defaults |
| Extra columns | Ignore unknown columns | No action (forward compatible) |
| Invalid data types | Type coercion failure | Mark row as corrupted, skip |
| Duplicate IDs | ID uniqueness check | Keep row with latest updated_at |
| Orphan entries | Foreign key check | Move to "_orphaned" sheet |
| Checksum mismatch | Compare _meta.checksum | Full re-sync prompt |

### 25.4 Permission Errors

| Error | User Message | Recovery Path |
|-------|--------------|---------------|
| No read access | "Cannot access spreadsheet" | Re-authenticate or share sheet |
| No write access | "Read-only mode enabled" | Request edit access |
| Sheet not shared | "Sheet is private" | Owner must share |
| Drive quota exceeded | "Google Drive full" | Free up space |

### 25.5 Duplicate Prevention

```
For each new entry:
1. Generate UUID client-side
2. Check local DB for UUID collision (regenerate if collision)
3. On sync, check sheet for UUID
4. If duplicate found:
   - Compare created_at timestamps
   - If same source device: merge (keep newer)
   - If different source: flag as conflict
```

---

## 26. Testing Strategy

### 26.1 Unit Tests

| Module | Test Focus | Coverage Target |
|--------|------------|-----------------|
| XIRR Calculator | Edge cases, convergence, accuracy | 100% |
| TWRR Calculator | Period linking, sub-returns | 100% |
| CAGR/MOIC/IRR | Formula accuracy | 100% |
| Date utilities | Parsing, formatting, timezones | 100% |
| Currency conversion | Rounding, precision | 100% |
| Validation | All input validators | 100% |
| Sync queue | FIFO, retry logic | 90% |

### 26.2 Integration Tests

| Integration | Test Scenarios |
|-------------|----------------|
| SQLite operations | CRUD, migrations, indexes |
| Google Sign-In | Success, failure, token refresh |
| Google Sheets API | Read, write, batch, errors |
| Network layer | Timeout, retry, offline detection |
| Keychain/Keystore | Token storage, biometrics |

### 26.3 End-to-End Tests

| Flow | Test Cases |
|------|------------|
| Onboarding | Fresh install → First entry |
| Add Investment | Create → View → Edit → Delete |
| Add Entry | All types, validation errors |
| Sync | Online, offline, conflict |
| Analytics | All graphs render, accurate |
| Settings | All toggles, persistence |

### 26.4 Performance Tests

| Test | Criteria | Method |
|------|----------|--------|
| App cold start | < 2s to dashboard | Profiler |
| Entry list scroll | 60fps, no jank | Frame timing |
| 10k entries query | < 200ms | DB benchmark |
| Graph render (1yr data) | < 500ms | Render timing |
| Sync 1000 entries | < 30s | Network timing |
| Memory usage | < 150MB peak | Memory profiler |

### 26.5 Device Compatibility Tests

| Platform | Devices |
|----------|---------|
| Android | Pixel 6/7/8, Samsung S21-S24, budget devices (Redmi) |
| iOS | iPhone 12-15, iPhone SE, iPad |
| OS Versions | Android 8-14, iOS 13-17 |
| Screen Sizes | 5"-7" phones, 10"+ tablets |

### 26.6 Security Tests

| Test | Method |
|------|--------|
| Token storage | Attempt extraction from device |
| Network traffic | Proxy inspection (no plaintext tokens) |
| Input injection | SQL injection, XSS attempts |
| Biometric bypass | Attempt bypass methods |
| Rate limiting | Brute force passcode |

---

## 27. Security Threat Model

### 27.1 Assets to Protect

| Asset | Sensitivity | Location |
|-------|-------------|----------|
| Investment data | High | Local DB, Google Sheet |
| Google OAuth tokens | Critical | Keychain/Keystore |
| User passcode | Critical | Hashed locally |
| Calculation results | Medium | Local cache |

### 27.2 Attack Vectors & Mitigations

| Vector | Description | Mitigation |
|--------|-------------|------------|
| Device theft | Physical access to unlocked phone | Passcode/biometric lock, auto-lock timer |
| Token theft | Malware extracts tokens | Secure keychain, no logging tokens |
| MITM attack | Intercept API calls | Certificate pinning, HTTPS only |
| Backup extraction | Tokens in cloud backup | Exclude tokens from backup |
| Sheet tampering | User manually edits sheet | Checksums, conflict detection |
| Phishing | Fake Google login | Use official Google SDK only |
| Brute force | Guess passcode | Rate limiting, lockout after 5 attempts |
| Memory dump | Extract data from RAM | Clear sensitive data after use |

### 27.3 Token Security

```
┌─────────────────────────────────────────────────────────────┐
│                    TOKEN LIFECYCLE                           │
└─────────────────────────────────────────────────────────────┘

1. ACQUISITION
   - OAuth flow via Google SDK
   - Tokens never touch app code directly
   - Stored immediately in secure keychain

2. STORAGE
   - Access token: Keychain (iOS) / Keystore (Android)
   - Refresh token: Encrypted, keychain-stored
   - Never in SharedPreferences/UserDefaults
   - Never logged or in crash reports

3. USAGE
   - Retrieved only when needed
   - Not cached in memory longer than request
   - Not passed to analytics

4. ROTATION
   - Access token: Refresh when 401 received
   - Refresh token: Rotate on each use (sliding)
   - Full re-auth: Every 30 days of inactivity

5. REVOCATION
   - On sign-out: Clear all tokens
   - On security alert: Immediate invalidation
   - On account deletion: Full purge
```

### 27.4 Local DB Security

| Measure | Implementation |
|---------|----------------|
| Encryption at rest | SQLCipher (AES-256) |
| Key storage | Derived from device keychain |
| Access control | App sandbox only |
| Backup exclusion | Mark DB as no-backup |

### 27.5 Google Drive Permission Misuse

| Scenario | Prevention |
|----------|------------|
| App requests broad Drive access | Request only Sheets-specific scope |
| User shares sheet publicly | Warn on detection during sync |
| Other apps access sheet | Protected ranges, app-specific columns |

---

## 28. Legal & Compliance

### 28.1 Data Ownership Guarantee

> **User owns 100% of their data.** InvTracker stores no user data on any server. All data resides in the user's local device storage and their personal Google Drive account.

### 28.2 Privacy Policy Requirements

The Privacy Policy must include:

| Section | Content |
|---------|---------|
| Data Collection | Only Google profile (name, email, photo) for identification |
| Data Storage | Local device + user's Google Drive only |
| Data Sharing | None. No third-party access. |
| Data Retention | User controls. Delete anytime. |
| Analytics | Anonymous usage analytics (opt-out available) |
| Advertising | None. No ads. |
| Children | Not intended for users under 13 |

### 28.3 Terms of Service Requirements

| Section | Content |
|---------|---------|
| Service Description | Investment tracking tool, not financial advice |
| Disclaimer | Not a financial advisor; calculations for informational purposes |
| Accuracy | Best-effort calculations; user responsible for verification |
| Liability | Limited liability for data loss or calculation errors |
| User Responsibilities | Accurate data entry, secure device |
| Termination | User can delete account anytime |

### 28.4 Financial Disclaimer

```
IMPORTANT: InvTracker is an investment tracking tool, not a financial advisor.

- Calculations (XIRR, TWRR, CAGR, etc.) are for informational purposes only.
- Do not make financial decisions based solely on this app's calculations.
- Consult a qualified financial advisor for investment advice.
- Past performance does not guarantee future results.
- The developers are not responsible for any financial losses.
```

### 28.5 Data Export/Portability

| Requirement | Implementation |
|-------------|----------------|
| GDPR Article 20 | Export all data to CSV/JSON |
| Data format | Open, machine-readable (CSV, JSON) |
| Export method | In-app Settings → Export Data |
| Timeline | Immediate download |

### 28.6 Data Deletion

| Requirement | Implementation |
|-------------|----------------|
| GDPR Article 17 | Complete data deletion on request |
| Local data | Immediate purge from device |
| Google Sheet | User deletes from own Drive |
| Account deletion | Settings → Delete Account (confirmation required) |
| Verification | Confirmation email |

### 28.7 Regional Compliance

| Region | Requirement | Status |
|--------|-------------|--------|
| EU/EEA | GDPR | Compliant (no server-side data) |
| California | CCPA | Compliant (no data sale) |
| India | DPDP Act 2023 | Compliant (local storage option) |
| Global | Google API ToS | Compliant (limited scopes) |

### 28.8 Google API Disclosure (Required for OAuth Verification)

> **Google API Usage Disclosure**
>
> This application uses Google APIs to provide its functionality:
>
> - **Google Sign-In API**: Used solely to authenticate users with their Google account. We access only basic profile information (name, email, profile photo) to identify the user within the app.
>
> - **Google Drive API**: Used to create and access a single spreadsheet file in the user's Google Drive for data persistence. We request the minimum scope `https://www.googleapis.com/auth/drive.file` which limits access to only files created by this app.
>
> - **Google Sheets API**: Used to read and write investment tracking data to the user's spreadsheet.
>
> **Data Handling:**
> - All data processing occurs locally on the user's device
> - No user data is transmitted to any external servers
> - No user data is shared with third parties
> - Users maintain full ownership and control of their data
> - Users can delete their data at any time by removing the app and deleting the spreadsheet from their Google Drive
>
> This app's use of information received from Google APIs adheres to the [Google API Services User Data Policy](https://developers.google.com/terms/api-services-user-data-policy), including the Limited Use requirements.

---

## 29. Monetization Strategy Framework

### 29.1 Free vs Premium Features

| Feature | Free | Premium |
|---------|------|---------|
| Investments (limit) | 5 | Unlimited |
| Entries (limit) | 100 | Unlimited |
| XIRR/CAGR/MOIC | ✓ | ✓ |
| TWRR | — | ✓ |
| Basic graphs | ✓ | ✓ |
| Advanced analytics | — | ✓ |
| Export CSV | ✓ | ✓ |
| Export PDF reports | — | ✓ |
| Custom categories | 3 | Unlimited |
| Benchmark comparison | — | ✓ |
| Tax reports | — | ✓ |
| Priority support | — | ✓ |

### 29.2 UI Placeholders for Premium

| Location | Placeholder Type |
|----------|------------------|
| Dashboard (TWRR card) | "Upgrade to unlock" overlay |
| Analytics (advanced section) | Blurred with upgrade button |
| Export (PDF option) | Disabled with premium badge |
| Settings (Benchmark) | "Premium Feature" label |
| Investment list (6th item) | "Unlock more with Premium" card |

### 29.3 Pricing Model (Placeholder)

| Tier | Price | Features |
|------|-------|----------|
| Free | $0 | Basic tracking |
| Premium Monthly | $4.99/mo | All features |
| Premium Annual | $39.99/yr | All features (33% off) |
| Lifetime | $99.99 | All features forever |

### 29.4 Premium Architecture Hooks

```dart
// Feature gate example
class FeatureGate {
  static bool isEnabled(Feature feature) {
    if (UserSubscription.isPremium) return true;
    return feature.isFreeFeature;
  }
}

// Usage
if (FeatureGate.isEnabled(Feature.twrrCalculation)) {
  showTWRR();
} else {
  showUpgradePrompt();
}
```

---

## 30. Deliverables

- [x] Full PRD (this document)
- [ ] Technical Specification
- [ ] Wireframes (Low-fidelity)
- [ ] Architecture Diagram
- [ ] Entity-Relationship Diagram (ERD)
- [ ] Sync Flow Sequence Diagrams
- [ ] Hi-Fi UI Mockups
- [ ] API Documentation
- [ ] Test Plan Document
- [ ] Security Assessment Report
- [ ] Privacy Policy Draft
- [ ] Terms of Service Draft

---

## Appendix A: Sample Data

### A.1 Sample Investment

```json
{
  "investment_id": "inv_001",
  "name": "HDFC FlexiCap Fund",
  "category": "Mutual Fund",
  "start_date": "2023-01-01",
  "notes": "Monthly SIP investment"
}
```

### A.2 Sample Entries

| Date | Type | Amount (₹) | Units | Price/Unit | Note |
|------|------|------------|-------|------------|------|
| 2023-01-01 | Inflow | 10,000 | 100.00 | 100.00 | Initial SIP |
| 2023-02-01 | Inflow | 10,000 | 95.24 | 105.00 | Monthly SIP |
| 2023-03-01 | Inflow | 10,000 | 90.91 | 110.00 | Monthly SIP |
| 2023-04-01 | Outflow | 15,000 | 136.36 | 110.00 | Partial redemption |
| 2023-05-01 | Inflow | 10,000 | 86.96 | 115.00 | Monthly SIP |
| 2023-06-01 | Current Value | 25,000 | — | — | NAV update |

### A.3 Sample Calculations

Based on the above entries:

| Metric | Value | Calculation |
|--------|-------|-------------|
| Total Invested | ₹40,000 | Sum of inflows |
| Total Withdrawn | ₹15,000 | Sum of outflows |
| Net Invested | ₹25,000 | Inflows - Outflows |
| Current Value | ₹25,000 | Latest valuation |
| Absolute Return | ₹0 | Current - Net Invested |
| Absolute Return % | 0% | (Current - Net) / Net × 100 |
| XIRR | 12.5% | Newton-Raphson on cash flows |
| MOIC | 1.0x | Current / Net Invested |

### A.4 Sample Google Sheet Structure

**Sheet: Investments**
| investment_id | name | category | start_date | notes | created_at | updated_at |
|---------------|------|----------|------------|-------|------------|------------|
| inv_001 | HDFC FlexiCap Fund | Mutual Fund | 2023-01-01 | Monthly SIP | 2023-01-01T10:00:00Z | 2023-06-01T10:00:00Z |

**Sheet: Entries**
| id | investment_id | date | type | amount | units | price_per_unit | note | created_at | updated_at |
|----|---------------|------|------|--------|-------|----------------|------|------------|------------|
| e_001 | inv_001 | 2023-01-01 | inflow | 10000 | 100.00 | 100.00 | Initial SIP | 2023-01-01T10:00:00Z | 2023-01-01T10:00:00Z |

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **XIRR** | Extended Internal Rate of Return. Annualized return accounting for irregular cash flows with specific dates. Uses Newton-Raphson iteration to solve for the rate. |
| **IRR** | Internal Rate of Return. The discount rate that makes NPV of all cash flows equal to zero. Assumes regular intervals. |
| **TWRR** | Time-Weighted Rate of Return. Measures compound growth rate eliminating the effect of cash flow timing. Used by fund managers. |
| **CAGR** | Compound Annual Growth Rate. Smoothed annualized return assuming single investment at start. Formula: (End/Start)^(1/years) - 1 |
| **MOIC** | Multiple on Invested Capital. Simple ratio of current value to total invested. MOIC of 2x means you doubled your money. |
| **NAV** | Net Asset Value. Per-unit price of a mutual fund or ETF. |
| **SIP** | Systematic Investment Plan. Regular periodic investment (usually monthly) into a fund. |
| **Inflow** | Money invested into an investment (purchase, SIP, additional investment). |
| **Outflow** | Money withdrawn from an investment (redemption, dividend, partial sale). |
| **Drawdown** | Peak-to-trough decline in investment value. Maximum drawdown is the largest historical drop. |
| **Sharpe Ratio** | Risk-adjusted return metric. (Return - Risk-free rate) / Standard deviation. Higher is better. |
| **Volatility** | Standard deviation of returns. Measures how much returns vary from the average. |
| **Sync Queue** | Local queue of pending operations waiting to be synchronized with Google Sheets. |
| **Conflict** | When the same record is modified on multiple devices before sync, requiring resolution. |
| **Rehydration** | Process of restoring local database from Google Sheets (cloud → local). |
| **SQLCipher** | Open-source extension to SQLite providing AES-256 encryption for the database file. |
| **OAuth 2.0** | Authorization framework allowing apps to access user data without exposing passwords. |
| **Keychain/Keystore** | Secure storage provided by iOS/Android for sensitive data like tokens and encryption keys. |

---

*End of Document*

---

**Document Revision History**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | — | — | Initial draft |
| 2.0 | — | — | Added: Acceptance Criteria, Navigation Map, UX Design System, Detailed Sync Diagrams, Analytics Formulas, Notifications Framework, Settings Specification, Sheet Validation Rules, Testing Strategy, Security Threat Model, Legal & Compliance, Monetization Framework |
| 2.1 | — | — | Fixed: Section numbering, Added: Database indexes, Migration policy, Auto-merge rules, Confirmation flows, Backup/Recovery, Quiet hours logic, Google API disclosure, Appendix with sample data, Glossary |
