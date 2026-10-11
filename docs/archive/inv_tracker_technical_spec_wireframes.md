# InvTracker — Technical Specification & Low-Fidelity Wireframes

**Document owner:** Product Manager
**Date:** 2025-12-03 (Asia/Kolkata)

---

## 1. Purpose
This document contains the engineering-focused technical specification for InvTracker (client-only Flutter mobile app) and low-fidelity wireframes for the major screens. It includes exact Google Sheets API request templates, offline sync mechanics, local DB schema, security notes, calculation pseudocode (XIRR/TWRR), and a UI wireframe guide.

> **Note:** This doc is intended for developers and designers. It assumes Flutter as the implementation platform and a single Google Sheet (`InvTracker_Master`) stored in the user's Drive root.

---

## 2. High-level architecture

- **Flutter Mobile App (Dart)**
  - UI
  - Sync Engine
  - Local DB (SQLite / drift)
  - Calculation module (Dart)
  - Secure storage for tokens
- **Google APIs (Drive & Sheets)**
  - OAuth 2.0 (google_sign_in)
  - REST calls to Sheets & Drive for file create/read/write

No server component.

---

## 3. OAuth & Scopes

**Recommended OAuth scopes** (least privilege):
- `https://www.googleapis.com/auth/drive.file` — create & open files created or opened by the app
- `https://www.googleapis.com/auth/spreadsheets` — full Sheets API access for the sheet

**Sign-in flow (high-level)**
1. User triggers Google Sign-In.
2. Retrieve `access_token` and `refresh_token`.
3. Store tokens in platform secure storage (Keychain/Keystore). Store refresh token encrypted.
4. Use `access_token` for API calls; refresh when expired.

---

## 4. Local DB schema (SQLite)

Tables (DDL-like):

```
-- users
CREATE TABLE users (
  id TEXT PRIMARY KEY, -- uuid
  google_user_id TEXT,
  email TEXT,
  display_name TEXT,
  last_sync TEXT -- ISO timestamp
);

-- investments
CREATE TABLE investments (
  investment_id TEXT PRIMARY KEY,
  name TEXT,
  category TEXT,
  start_date TEXT,
  notes TEXT,
  created_at TEXT,
  updated_at TEXT
);

-- entries (ledger rows)
CREATE TABLE entries (
  id TEXT PRIMARY KEY, -- uuid
  investment_id TEXT,
  investment_name TEXT,
  category TEXT,
  date TEXT, -- ISO date
  type TEXT, -- inflow/outflow/dividend/expense/etc
  amount INTEGER, -- stored as minor units (e.g., paise)
  currency TEXT,
  units REAL,
  price_per_unit REAL,
  transaction_id TEXT,
  note TEXT,
  created_at TEXT,
  updated_at TEXT,
  sync_status TEXT -- pending/synced/conflict
);

-- sync queue
CREATE TABLE sync_queue (
  op_id TEXT PRIMARY KEY,
  target_id TEXT,
  op_type TEXT, -- create/update/delete
  payload TEXT, -- JSON
  created_at TEXT
);

-- settings
CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT);
```

---

## 5. Google Sheet schema & templates

**Sheet name:** `InvTracker_Master` (tab: `Ledger`)

**Header row:**
```
id,user_id,investment_id,investment_name,category,date,type,amount,currency,units,price_per_unit,running_value,transaction_id,note,created_at,updated_at,source,sync_status,meta
```

**Hidden tab:** `_meta` with keys: `sheet_version`, `app_key` (checksum), `last_sync_at`.

**CSV template file** (for import/export) follows same columns.

---

## 6. Sheets API: request examples

> All requests must include `Authorization: Bearer <access_token>` header.

### 6.1 Create spreadsheet (if not present)

**Endpoint:** `POST https://sheets.googleapis.com/v4/spreadsheets`

**Body (example):**

```json
{
  "properties": { "title": "InvTracker_Master" },
  "sheets": [
    { "properties": { "title": "Ledger" } },
    { "properties": { "title": "_meta" } }
  ]
}
```

**Response:** contains `spreadsheetId`.

After creation: write header row to `Ledger` and write `_meta` JSON object to `_meta` tab using batchUpdate or spreadsheets.values.update.

### 6.2 Write header row (values.update)

**Endpoint:** `PUT https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}/values/Ledger!A1:Z1?valueInputOption=RAW`

**Body:**
```json
{ "values": [["id","user_id","investment_id","investment_name","category","date","type","amount","currency","units","price_per_unit","running_value","transaction_id","note","created_at","updated_at","source","sync_status","meta"]] }
```

### 6.3 Append a single ledger row (values.append)

**Endpoint:** `POST https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}/values/Ledger!A:Z:append?valueInputOption=RAW&insertDataOption=INSERT_ROWS`

**Body (example):**
```json
{ "values": [["<id>","<user_id>","<investment_id>","<investment_name>","<category>","2025-12-03","inflow","100000","INR","","","","note","2025-12-03T10:00:00Z","2025-12-03T10:00:00Z","app","synced","{}"]] }
```

**Note:** `amount` is stored as minor units. Use string values or numeric depending on `valueInputOption`.

### 6.4 Batch update multiple rows (recommended for sync)

**Endpoint:** `POST https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}/values:batchUpdate`

**Body:**
```json
{
  "valueInputOption": "RAW",
  "data": [
    { "range": "Ledger!A2:S2", "majorDimension": "ROWS", "values": [[...row1...]] },
    { "range": "Ledger!A3:S3", "majorDimension": "ROWS", "values": [[...row2...]] }
  ]
}
```

**Recommendation:** When appending many rows, compute the destination range carefully using `append` or by retrieving `spreadsheetId` current last row using `spreadsheets.values.get` and then writing.

### 6.5 Retrieve full sheet or range

**Endpoint:** `GET https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}/values/Ledger!A1:Z1000`

Use to fetch remote changes for reconciliation.

### 6.6 Protect range (warning-only)

**Endpoint:** `POST https://sheets.googleapis.com/v4/spreadsheets/{spreadsheetId}:batchUpdate`

**Body (example to add protectedRange with warning):**
```json
{ "requests":[ { "addProtectedRange": { "protectedRange": { "range": { "sheetId": 0, "startRowIndex": 0, "endRowIndex": 10000, "startColumnIndex": 0, "endColumnIndex": 18 }, "description":"Managed by InvTracker - do not edit", "warningOnly": true } } } ] }
```

> `sheetId` is numeric sheet id (get from spreadsheet metadata).

---

## 7. Sync engine and sequence diagrams

### 7.1 Initial sign-in flow
1. Obtain `access_token` + `refresh_token`.
2. Check Drive root for `InvTracker` folder & `InvTracker_Master` sheet using Drive API `files.list` with `q = name='InvTracker_Master' and trashed=false` (or use app-specific file discovery). If not found:
   - Create folder (optional), create spreadsheet, write headers & `_meta`.
3. Pull remote sheet Ledger into local DB (if sheet has existing rows): use `spreadsheets.values.get` and upsert rows into SQLite.
4. Mark `last_sync_at`.

### 7.2 Normal sync (device online)
1. Stop UI write operations? (no — allow concurrent writes; they push to queue)
2. Read `sync_queue` ordered by `created_at`.
3. For each op batch (max N per batch), call Sheets API batchUpdate/append.
4. On success: remove queue entries, mark corresponding entries as `synced` with `updated_at` from server (or local timestamp). On transient failure: retry with backoff.
5. Pull remote changes since `last_sync_at` (or fetch full sheet) and detect conflicts by comparing `updated_at` timestamps and `id`.
6. For rows with `remote_updated_at` > `local_updated_at` and not originated from current device: add to conflict list.
7. Present conflict UI to user.

### 7.3 Conflict resolution strategy
- Each row has `id` and `updated_at`.
- When conflict: show a diff view: local fields vs remote fields. Allow options:
  - Keep Local: overwrite remote row (push update)
  - Keep Remote: overwrite local row (update local DB)
  - Manual Merge: open edit screen with combined values.
- If user does nothing, keep local version unsynced and mark as `conflict`.

---

## 8. Calculation module (Dart) — pseudocode & notes

### 8.1 XIRR (date-aware IRR)

**Approach:** Newton-Raphson with bracketed fallback (Brent) for stability.

**Pseudocode:**

```
function xnpv(rate, cashflows):
  // cashflows: [{date, amount}]
  let t0 = cashflows[0].date
  sum = 0
  for each cf in cashflows:
    dt = days_between(cf.date, t0) / 365.0
    sum += cf.amount / ((1 + rate) ** dt)
  return sum

function xirr(cashflows):
  // initial guess
  rate = 0.1
  for i in 1..maxIter:
    fx = xnpv(rate, cashflows)
    dfx = derivative_of_xnpv(rate, cashflows)
    if abs(fx) < tol: return rate
    rate = rate - fx/dfx
  // fallback: bracket and do bisection or Brent
  return rate
```

**Notes:**
- Use cashflows where outflow (invest) is negative and inflow (payout) is positive by convention.
- If multiple roots or no sign change, return `NaN` or indicate calculation failed.
- Create unit tests with canonical Excel XIRR test vectors.

### 8.2 TWRR

**Approach:** split timeline into subperiods between cashflows. For each subperiod, compute return = (ending_value - starting_value) / starting_value, then compute geometric mean across periods.

**Pseudocode:**
```
function twrr(period_values):
  // period_values: [{start_value, end_value}]
  product = 1
  for p in period_values:
    r = (p.end_value - p.start_value) / p.start_value
    product *= (1 + r)
  return product ** (1/num_periods) - 1
```

**Notes:** require valuation snapshots (either user-provided or estimated) at each cashflow boundary. For MVP, approximate using last known running value.

### 8.3 CAGR, IRR, MOIC

- **CAGR** = (ending_value / starting_value)^(1/years) - 1
- **MOIC** = (total_proceeds / total_invested)
- **IRR (periodic)**: use standard IRR for periodic cashflows (equally spaced), fallback to XIRR when irregular.

---

## 9. UI Wireframes (low-fidelity)

> Below are ASCII-like sketches and descriptions to guide a UI designer. Use them to produce visual mocks.

### 9.1 Onboarding / Sign-in

[Screen]
---------------------------------
| InvTracker logo                 |
| "Track investments. Offline-first." |
| [Sign in with Google] (primary) |
---------------------------------

- After sign-in: show permission explanation modal (scopes) and sheet creation message.

### 9.2 Home / Quick Dashboard

[Top]
---------------------------------------------
| Welcome, <Name>                     [sync icon] |
---------------------------------------------
| KPIs: Total Invested | Portfolio Value | XIRR |
| small sparkline under Portfolio Value               |
---------------------------------------------
| Quick Actions: (+) Add Entry  (+) Add Investment |
---------------------------------------------
| Recent Activity (list of last 5 ledger entries)   |
---------------------------------------------
| Analytics shortcut: View Portfolio | Compare   |
---------------------------------------------

### 9.3 Add Entry (Quick)

---------------------------------
| Investment (dropdown / search)    |
| Date [calendar]  Amount [input]   |
| Type [inflow/outflow]  Note      |
| [Save] [Advanced options...]     |
---------------------------------

### 9.4 Investment List

[List rows: Name | Category | XIRR | small sparkline]

---

### 9.5 Investment Detail

[Header: Investment Name | Edit]
[KPIs row: XIRR | CAGR | MOIC | P/L]
[Chart: Value over time (sparkline big)]
[Ledger: date | type | amount | note]

---

### 9.6 Portfolio Analytics

- TWRR card (period selector)
- Allocation pie
- Contributions vs returns stacked area
- Top contributors list

---

### 9.7 Sync & Conflict Center

- List of pending operations
- List of conflicts -> tap to view diff -> choose keep local/remote/merge

---

### 9.8 Settings

- Sheet location (open in Drive) — shows `InvTracker/InvTracker_Master`
- App passcode & biometric
- Export & backup
- About & privacy

---

## 10. Example Flutter app code snippets (conceptual)

> These are conceptual examples to get started (not full code). Implement with appropriate packages and error handling.

**Google Sign-In using `google_sign_in` plugin**

```dart
final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [
  'https://www.googleapis.com/auth/drive.file',
  'https://www.googleapis.com/auth/spreadsheets',
]);

void signIn() async {
  final account = await _googleSignIn.signIn();
  final auth = await account.authentication;
  final accessToken = auth.accessToken;
  final refreshToken = auth.idToken; // careful: get refresh token via serverless flow or manual user consent
  // store tokens securely
}
```

**Calling Sheets API (http client)**

```dart
final response = await http.post(
  'https://sheets.googleapis.com/v4/spreadsheets',
  headers: {'Authorization': 'Bearer $accessToken', 'Content-Type': 'application/json'},
  body: jsonEncode({ ... })
);
```

---

## 11. Testing & QA checklist

- Unit tests for finance calculations (XIRR, TWRR, CAGR, IRR) against known vectors.
- Offline add/edit/delete -> queue -> sync -> verify rows on remote sheet.
- Conflict scenarios (manual sheet edit) -> detect & present conflict.
- Token expiration & reauth flows.
- Large dataset performance (1k+ entries) for charts and queries.

---

## 12. Developer tasks (initial backlog)

1. Project scaffold (Flutter) + package selection (http, google_sign_in, drift, sqflite, secure_storage).
2. Implement Google Sign-In & token storage.
3. Implement Drive search/create spreadsheet flow.
4. Implement local DB models & CRUD.
5. Implement Add Entry UI & local save.
6. Implement basic dashboard & charts (use a Flutter chart lib).
7. Implement sync engine and batch write flows to Sheets API.
8. Implement calculation module + unit tests.
9. Implement conflict resolution UI.
10. Polish UI, onboarding and analytics screens.

---

## 13. Security checklist
- Use platform secure storage for tokens.
- Encrypt refresh tokens with OS-level API.
- Consider full DB encryption (SQLCipher) if user requests.
- Request least-privilege OAuth scopes.

---

## 14. Deliverables & next steps (actionable)
- Developer: implement auth + sheet create + local DB + one add-entry flow (MVP vertical).
- Designer: convert wireframes to hi-fi UI mocks (Figma) and supply assets.
- PM: review acceptance criteria and UX microcopy for sign-in, conflicts, and onboarding.

---

## 15. Appendix: key API snippets and examples
(Checkpoint: the examples shown in Section 6 are ready to copy into implementation and adapt.)

---

*End of technical spec & wireframes.*



