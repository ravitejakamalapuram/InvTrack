# InvTracker — Product Requirements Document (PRD)

> **Version 3.0** — Simplified & Focused Edition

---

## 1. Overview

**InvTracker** is a mobile app for tracking personal investments with powerful return metrics (XIRR, CAGR, MOIC) and beautiful analytics — all without a backend server.

### Core Principles
- **Offline-first**: Works 100% without internet
- **Privacy-first**: Your data stays on your device + your Google Drive
- **Simple**: Minimal input, maximum insights
- **Beautiful**: Premium UI/UX inspired by apps like CRED

### Data Storage
- **Primary**: Local encrypted SQLite database (SQLCipher)
- **Backup**: User's own Google Sheet in Google Drive

---

## 2. Problem Statement

Retail investors track investments in fragmented ways — spreadsheets, notes, random apps. Existing tools are:
- Overly complex with too many features
- Not offline-friendly
- Require yet another account
- Lock data inside the app
- Lack real metrics like XIRR

**InvTracker solves this:**
> Simple entry + Powerful analytics + Full data ownership

---

## 3. Target Users

| Persona | Need |
|---------|------|
| **DIY Investor** | Track stocks, mutual funds, crypto, gold manually |
| **Finance Professional** | Accurate XIRR/CAGR calculations |
| **Casual Saver** | "How much did I invest? What's it worth now?" |
| **Privacy-conscious** | No external servers, own my data |

---

## 4. App Navigation (4 Tabs)

```
┌─────────────────────────────────────────────────────────────┐
│                       INVTRACKER                            │
├──────────┬──────────┬──────────────┬────────────────────────┤
│   Home   │  Assets  │   Insights   │       Settings         │
│    🏠    │    📈    │      📊      │          ⚙️            │
└──────────┴──────────┴──────────────┴────────────────────────┘
```

### Tab 1: Home (Dashboard)
**Purpose**: At-a-glance portfolio health

| Section | Content |
|---------|---------|
| Hero Card | Total portfolio value + daily/overall change |
| Quick Stats | 3 tiles: Invested, Returns, XIRR |
| Sparkline | 7-day mini chart (tap for full) |
| Recent Activity | Last 5 transactions |
| FAB | Quick add transaction |

### Tab 2: Assets (Investments)
**Purpose**: Manage individual investments

| Section | Content |
|---------|---------|
| Search/Filter | By type, performance, alphabetical |
| Asset Cards | Each investment with current value + return % |
| Tap → Detail | Full history, chart, transactions |
| FAB | Add new investment |

### Tab 3: Insights (Analytics)
**Purpose**: Deep portfolio analysis

| Section | Content |
|---------|---------|
| Period Selector | 1M, 3M, 6M, 1Y, ALL |
| Performance Card | XIRR, TWRR, CAGR, MOIC |
| Allocation Chart | Interactive donut/pie |
| Contribution vs Returns | Visual comparison |
| Investment Ranking | Sorted by performance |
| Top Movers | Best & worst performers |

### Tab 4: Settings
**Purpose**: App configuration

| Section | Content |
|---------|---------|
| Account | Profile, sign out |
| Portfolios | Create/manage portfolios |
| Data | Sync, export CSV, import |
| Security | Passcode, biometrics, auto-lock |
| Appearance | Theme (light/dark/system), currency |
| About | Version, privacy policy, terms |

---

## 5. Core Features

### 5.1 Investment (Asset) Management
- Create with just a name (minimum)
- Optional: Category, symbol, notes
- Edit/archive anytime
- Soft delete (preserves history)

### 5.2 Transactions (Ledger Entries)

| Field | Required | Description |
|-------|----------|-------------|
| Date | ✓ | When it happened |
| Type | ✓ | Inflow / Outflow / Dividend / Current Value |
| Amount | ✓ | Transaction amount |
| Units | ○ | Number of units |
| Price/Unit | ○ | Auto-calculated if units provided |
| Notes | ○ | Free text |

**Transaction Types:**
- **Inflow**: Money invested (buy, SIP, deposit)
- **Outflow**: Money withdrawn (sell, redemption)
- **Dividend**: Income received
- **Current Value**: Mark-to-market valuation

### 5.3 Calculations

| Metric | Description | When Shown |
|--------|-------------|------------|
| **XIRR** | Annualized return with exact dates | Always |
| **CAGR** | Compound annual growth rate | Always |
| **MOIC** | Multiple on invested capital | Always |
| **TWRR** | Time-weighted return | Premium |
| **Total Return** | Current value - invested | Always |
| **Return %** | Percentage gain/loss | Always |

### 5.4 Offline-First

All operations work offline:
- ✓ Add/edit investments
- ✓ Add/edit transactions
- ✓ View all analytics
- ✓ Sync queues when online

### 5.5 Google Sheets Sync
- Auto-creates sheet on first sync
- Background sync when online
- Conflict detection with resolution UI
- Manual sync trigger in Settings

### 5.6 Security
- Google OAuth sign-in (or guest mode)
- Optional 6-digit passcode
- Biometric unlock (Face ID / Touch ID)
- Encrypted local database (SQLCipher)

---

## 6. Screen Specifications

### 6.1 Home Screen (Dashboard)

```
┌─────────────────────────────────────────────┐
│ Good Morning              [Sync Icon]       │
│ Your Portfolio                              │
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │  💰 ₹12,45,678                          │ │
│ │  Total Value              ▲ 2.4% today  │ │
│ │  ───────────────────────────────────    │ │
│ │  [Mini sparkline chart]                 │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────┐ ┌─────────┐ ┌─────────┐        │
│ │Invested │ │ Returns │ │  XIRR   │        │
│ │ ₹10L    │ │ ₹2.4L   │ │  18.2%  │        │
│ └─────────┘ └─────────┘ └─────────┘        │
│                                             │
│ Recent Activity                  See all → │
│ ├─ Bought HDFC Bank      ₹10,000    Today  │
│ ├─ Dividend INFY           ₹500  Yesterday │
│ └─ Sold Gold              ₹25,000   3d ago │
│                                             │
│                              [+ Add FAB]    │
├──────────┬──────────┬──────────┬───────────┤
│   Home   │  Assets  │ Insights │ Settings  │
└──────────┴──────────┴──────────┴───────────┘
```

### 6.2 Assets Screen (Investment List)

```
┌─────────────────────────────────────────────┐
│ Assets                        [Search] [+]  │
├─────────────────────────────────────────────┤
│ [All] [Stocks] [MF] [Crypto] [Other]       │
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │ 📈 HDFC Bank                            │ │
│ │    ₹1,25,000          ▲ 24.5% │ ₹24,500 │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ 📊 Axis Bluechip MF                     │ │
│ │    ₹2,50,000          ▲ 18.2% │ ₹38,636 │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ ₿ Bitcoin                               │ │
│ │    ₹45,000            ▼ -5.2% │ -₹2,468 │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ 🥇 Gold                                 │ │
│ │    ₹1,00,000          ▲ 12.0% │ ₹10,714 │ │
│ └─────────────────────────────────────────┘ │
├──────────┬──────────┬──────────┬───────────┤
│   Home   │  Assets  │ Insights │ Settings  │
└──────────┴──────────┴──────────┴───────────┘
```

### 6.3 Insights Screen (Analytics)

```
┌─────────────────────────────────────────────┐
│ Insights                                    │
├─────────────────────────────────────────────┤
│ [1M] [3M] [6M] [1Y] [ALL]                  │
├─────────────────────────────────────────────┤
│ Performance Metrics                         │
│ ┌──────────┬──────────┬──────────┐         │
│ │  XIRR    │   CAGR   │   MOIC   │         │
│ │  18.2%   │  15.4%   │   1.24x  │         │
│ └──────────┴──────────┴──────────┘         │
│                                             │
│ Allocation                                  │
│ ┌─────────────────────────────────────────┐ │
│ │     ╭───────╮                           │ │
│ │   ╱   MF     ╲   Stocks 25%             │ │
│ │  │   48%      │  MF 48%                 │ │
│ │   ╲  Stocks  ╱   Crypto 12%             │ │
│ │     ╰───────╯    Gold 15%               │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Contribution vs Returns                     │
│ ┌─────────────────────────────────────────┐ │
│ │ Invested  [████████████      ] ₹10L     │ │
│ │ Returns   [████              ] ₹2.4L    │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ Top Performers                              │
│ 1. HDFC Bank    ████████████  +24.5%       │
│ 2. Axis MF      █████████     +18.2%       │
│ 3. Gold         ██████        +12.0%       │
│                                             │
│ Underperformers                             │
│ 1. Bitcoin      ████          -5.2%        │
├──────────┬──────────┬──────────┬───────────┤
│   Home   │  Assets  │ Insights │ Settings  │
└──────────┴──────────┴──────────┴───────────┘
```

### 6.4 Settings Screen

```
┌─────────────────────────────────────────────┐
│ Settings                                    │
├─────────────────────────────────────────────┤
│ ACCOUNT                                     │
│ ├─ [Avatar] John Doe                        │
│ │           john@gmail.com                  │
│ └─ Sign Out                                 │
├─────────────────────────────────────────────┤
│ PORTFOLIOS                                  │
│ ├─ Main Portfolio ✓                         │
│ └─ + Create New Portfolio                   │
├─────────────────────────────────────────────┤
│ DATA                                        │
│ ├─ Sync Now                    Last: 2m ago │
│ ├─ Sync Issues                          (3) │
│ ├─ Export to CSV                            │
│ └─ Import Data                              │
├─────────────────────────────────────────────┤
│ SECURITY                                    │
│ ├─ Passcode                              ON │
│ ├─ Face ID                               ON │
│ └─ Auto-Lock                          1 min │
├─────────────────────────────────────────────┤
│ APPEARANCE                                  │
│ ├─ Theme                             System │
│ └─ Currency                             INR │
├─────────────────────────────────────────────┤
│ ABOUT                                       │
│ ├─ Version                            1.0.0 │
│ ├─ Privacy Policy                           │
│ └─ Terms of Service                         │
├──────────┬──────────┬──────────┬───────────┤
│   Home   │  Assets  │ Insights │ Settings  │
└──────────┴──────────┴──────────┴───────────┘
```

---

## 7. User Flows

### 7.1 First-Time User Flow
```
Open App → Welcome Screen → Sign in with Google →
Permission Explanation → Create Default Portfolio →
Home (Empty State) → Prompt to Add First Investment
```

### 7.2 Add Investment Flow
```
Assets Tab → Tap + → Enter Name → Select Type →
(Optional: Add initial transaction) → Save →
Returns to Assets List with new item
```

### 7.3 Record Transaction Flow
```
Any Tab → Tap FAB → Select Investment →
Enter Amount → Select Type (Inflow/Outflow) →
Pick Date → Save → Dashboard updates
```

### 7.4 Check Performance Flow
```
Home Tab (quick glance) → Tap Insights Tab →
Select Period (1M/3M/1Y/ALL) → View Metrics →
Scroll to see Allocation & Rankings
```

---

## 8. Technical Architecture

### Stack
- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Database**: Drift + SQLCipher (encrypted)
- **Routing**: GoRouter
- **Charts**: fl_chart

### Data Flow
```
User Action → Provider/Notifier → Repository →
Local DB (Drift) → Sync Queue → Google Sheets API
```

### Offline Strategy
| Action | Offline | Online |
|--------|---------|--------|
| Add data | Write local + queue | Process queue |
| View data | From local cache | Background refresh |
| Sync | Queue pending | Process immediately |

---

## 9. Calculations Reference

### XIRR (Primary Metric)
```
Σ (Cashflow_i / (1 + XIRR)^((Date_i - Date_0) / 365)) = 0
```
- Newton-Raphson iteration
- Shows "N/A" if < 2 cashflows

### CAGR
```
CAGR = (End_Value / Start_Value)^(1/Years) - 1
```

### MOIC
```
MOIC = (Distributions + Current_Value) / Total_Invested
```

### Allocation %
```
Allocation = Investment_Value / Portfolio_Total × 100
```

---

## 10. Sync Engine

### Sync Queue
Operations are queued locally and processed when online:
- `create` - New investment or transaction
- `update` - Modified record
- `delete` - Removed record

### Sync Cycle
1. Check network availability
2. Dequeue items in batches (50 items max)
3. Push to Google Sheet
4. Pull remote changes
5. Detect and resolve conflicts

### Conflict Resolution
| Severity | Fields | Action |
|----------|--------|--------|
| Critical | amount, date, type | Prompt user |
| Low | note, category | Auto-merge |

### Failure Recovery
| Scenario | Recovery |
|----------|----------|
| Network timeout | Retry with backoff (2s→4s→8s) |
| Token expired | Silent refresh, then retry |
| Sheet deleted | Prompt to recreate |

---

## 11. Data Model

### Local Database (SQLite + SQLCipher)

**Investments Table**
```sql
investment_id, name, category, start_date, notes,
created_at, updated_at, sync_status
```

**Entries Table**
```sql
id, investment_id, date, type, amount, units,
price_per_unit, note, created_at, updated_at, sync_status
```

**Sync Queue Table**
```sql
op_id, target_id, op_type, payload_json, created_at
```

### Google Sheet Schema

**Main Sheet: `InvTracker_Data`**
| Column | Type |
|--------|------|
| id | UUID |
| investment_id | UUID |
| investment_name | Text |
| category | Text |
| date | Date |
| type | Enum |
| amount | Number |
| units | Number |
| note | Text |
| created_at | Timestamp |
| updated_at | Timestamp |

**Meta Sheet: `_meta`**
- `schema_version`
- `last_sync_at`

---

## 12. Calculations Reference

### XIRR (Primary Metric)
```
Σ (Cashflow_i / (1 + XIRR)^((Date_i - Date_0) / 365)) = 0
```
- Newton-Raphson iteration (max 1000 iterations)
- Returns "N/A" if < 2 cashflows or no convergence

### CAGR
```
CAGR = (End_Value / Start_Value)^(1/Years) - 1
```

### MOIC
```
MOIC = (Distributions + Current_Value) / Total_Invested
```
| MOIC | Meaning |
|------|---------|
| < 1.0 | Loss |
| = 1.0 | Break-even |
| > 1.0 | Profit |

### TWRR (Premium)
```
TWRR = [(1 + R_1) × (1 + R_2) × ... × (1 + R_n)] - 1
```

### Allocation
```
Allocation_% = Investment_Value / Portfolio_Total × 100
```

### Contribution vs Return
```
Contribution = Total_Inflows - Total_Outflows
Return = Current_Value - Contribution
Return_% = Return / Contribution × 100
```

---

## 13. Security

### Database Encryption
| Component | Implementation |
|-----------|----------------|
| Library | SQLCipher (AES-256) |
| Key storage | iOS Keychain / Android Keystore |
| Key rotation | On passcode change |

### Authentication
- Google OAuth 2.0 (primary)
- Guest mode (local only, no sync)
- Optional 6-digit passcode
- Biometric unlock (Face ID / Touch ID)

---

## 14. Routes

| Route | Screen | Access |
|-------|--------|--------|
| `/` | Redirect | → `/home` or `/auth` |
| `/auth` | Welcome/Sign-in | Unauthenticated |
| `/home` | Dashboard | Authenticated |
| `/assets` | Investment List | Authenticated |
| `/assets/:id` | Investment Detail | Authenticated |
| `/insights` | Analytics | Authenticated |
| `/settings` | Settings | Authenticated |
| `/add-transaction` | Add Transaction | Modal |
| `/add-investment` | Add Investment | Modal |

---

## 15. Design System

### Colors
| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| Primary | #2563EB | #3B82F6 | Actions, links |
| Success | #10B981 | #34D399 | Positive returns |
| Danger | #EF4444 | #F87171 | Negative returns |
| Background | #F3F4F6 | #111827 | Screen background |
| Surface | #FFFFFF | #1F2937 | Cards |

### Typography
| Style | Size | Usage |
|-------|------|-------|
| Display | 32px | Portfolio value |
| H1 | 24px | Screen titles |
| Body | 16px | Content |
| Caption | 14px | Labels |

### Spacing (8px Grid)
- xs: 8px, sm: 12px, md: 16px, lg: 24px, xl: 32px

### Chart Colors
```
#2563EB (Blue)    #7C3AED (Purple)
#EC4899 (Pink)    #F59E0B (Amber)
#10B981 (Emerald) #06B6D4 (Cyan)
```

---

## 16. Roadmap

### Phase 1 (MVP) ✅ Complete
- [x] Local encrypted database
- [x] Investment CRUD
- [x] Transaction ledger
- [x] XIRR/CAGR/MOIC calculations
- [x] Dashboard with charts
- [x] Insights/Analytics screen
- [x] Google Sign-In
- [x] Google Sheets sync (one-way: app → sheet)

### Phase 2 (Next Release)
- [ ] **Investment Projections & Analytics**
  - [ ] Capture rate of interest for investments
  - [ ] Investment type classification:
    - Fixed monthly return (e.g., FD, P2P with fixed interest)
    - Dynamic monthly return (e.g., MF SIPs)
    - One-time invest & close (e.g., bonds, debentures)
  - [ ] Expected close date projection
  - [ ] Expected XIRR projection for dynamic investments
  - [ ] Visual projection charts (waterfall, trajectory)
- [ ] **Two-way Google Sheets Sync**
  - [ ] Pull changes from Google Sheets back to app
  - [ ] Conflict detection and resolution UI
  - [ ] Last-write-wins vs manual merge options
- [ ] TWRR calculation
- [ ] Export to CSV/PDF
- [ ] Multi-currency support

### Phase 3
- [ ] Benchmark comparison (Nifty, S&P, Gold, etc.)
- [ ] Price alerts & notifications
- [ ] Auto-import from brokers (Zerodha, Groww, etc.)
- [ ] Tax reports (capital gains summary)

### Phase 4
- [ ] Premium subscription tier
- [ ] Family/shared portfolios
- [ ] Goal-based tracking (retirement, house, education)

---

## 17. Risks & Mitigation

| Risk | Mitigation |
|------|------------|
| Sheet manually edited | Conflict detection + resolution UI |
| Token expiry | Silent refresh + re-auth prompt |
| Large dataset | DB indexes + pagination |
| Offline usage | Queue operations + sync on reconnect |

---

## 18. Legal

### Data Ownership
> User owns 100% of their data. InvTracker stores no data on external servers.

### Disclaimer
> InvTracker is a tracking tool, not financial advice. Consult a qualified advisor for investment decisions.

---

## 19. Glossary

| Term | Definition |
|------|------------|
| **XIRR** | Extended Internal Rate of Return - annualized return with exact dates |
| **CAGR** | Compound Annual Growth Rate - smoothed annual return |
| **MOIC** | Multiple on Invested Capital - total value / total invested |
| **TWRR** | Time-Weighted Rate of Return - eliminates cash flow timing effects |
| **Inflow** | Money invested (buy, deposit, SIP) |
| **Outflow** | Money withdrawn (sell, redemption) |
| **Current Value** | Mark-to-market valuation |

---

*End of Document*

**Version History**
| Version | Date | Changes |
|---------|------|---------|
| 1.0 | - | Initial AI-generated draft |
| 2.0 | - | Added detailed specs |
| 3.0 | 2024-12 | Simplified & focused - new 4-tab navigation (Home, Assets, Insights, Settings) |
| 3.1 | 2024-12 | Updated roadmap: Phase 1 complete, added investment projections & two-way sync to Phase 2 |
