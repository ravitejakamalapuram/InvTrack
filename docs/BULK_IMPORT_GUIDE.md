# Bulk Import Guide

> **Version 2.1** — October 2026

---

## 1. Overview

InvTrack supports bulk importing investment data via CSV files. This allows users to quickly import historical investment data from spreadsheets or exported data from other platforms.

### Key Features
- **CSV Import**: Upload CSV files with investment cash flow data
- **Smart Date Parsing**: Reads every date in a file the same way, and asks when day and month could be swapped
- **Multi-Currency**: Each row can name its currency; rows without one use your base currency
- **Flexible Type Mapping**: Recognizes common transaction and investment type names
- **Duplicate Check**: Flags rows that match cash flows you already have
- **Batch Processing**: Efficient Firestore batch writes for fast imports
- **Preview & Confirm**: Review parsed data before saving

---

## 2. CSV Format

### Required Columns

| Column | Description | Example Values |
|--------|-------------|----------------|
| **Date** | Transaction date | `2024-01-15`, `15/01/2024`, `Jan-24` |
| **Investment Name** | Name of the investment | `HDFC FD`, `Groww P2P`, `SBI Bonds` |
| **Type** | Transaction type | `invest`, `return`, `income`, `fee` |
| **Amount** | Transaction amount, in the row's currency | `10000`, `1,00,000`, `1000.50` |

### Optional Columns

| Column | Description | Example Values |
|--------|-------------|----------------|
| **Currency** | ISO 4217 code of the amount. Blank or missing means your base currency. An unknown code is reported as an error. | `INR`, `USD`, `aed` |
| **Notes** | Additional notes for the transaction | `Q1 interest` |
| **Investment Type** | Kind of investment (see section 5) | `fixedDeposit`, `p2pLending`, `fd` |
| **Investment Status** | `open` or `closed` | `open` |

The columns can be in any order. The in-app template has all eight, in the order of the sample below.

> **The Currency column sets the currency, not a symbol.** A symbol in the Amount (`$1000.50`, `₹5,000`) is ignored, so a USD amount without `USD` in the Currency column is imported in your base currency.

### Amounts

- Use a dot for decimals. Commas may group thousands or lakhs: `1,234.56` and `1,23,456.78` both work.
- A file whose amounts use a decimal comma (`"1.234,56"`, `"12,50"`) is read that way, as long as more of its amounts can only be read with a comma than only with a dot. Put such amounts in quotes, because the comma also separates columns.
- An amount that does not fit the file's decimal mark is reported as an error, never read as a different number.
- A leading minus or parentheses make an amount negative: `-5000`, `(5000)`.

### Sample CSV

```csv
Date,Investment Name,Type,Amount,Currency,Notes,Investment Type,Investment Status
2024-01-15,HDFC FD,invest,100000,INR,Initial deposit,fixedDeposit,open
2024-04-15,HDFC FD,income,1750,INR,Q1 interest,fixedDeposit,open
2024-07-15,HDFC FD,income,1750,INR,Q2 interest,fixedDeposit,open
2024-01-10,Groww P2P,invest,50000,,,p2pLending,open
2024-02-10,Groww P2P,income,625,,Monthly payout,p2pLending,open
2024-03-01,US Treasury Bill,invest,1000.50,USD,Bought through a US broker,bonds,open
```

The two Groww P2P rows have no currency, so they are imported in your base currency. The treasury bill stays in USD.

---

## 3. Supported Date Formats

| Format | Example |
|--------|---------|
| ISO (recommended) | `2024-01-15` |
| Day/month/year | `15/01/2024`, `15-01-2024`, `15/01/24` |
| Month/day/year | `01/15/2024` |
| Day, month name, year | `15-Jan-2024`, `5-Mar-24` |
| Month name, day, year | `Jan 15, 2024` |
| Month and year | `Jan-24`, `September-25` (uses the 1st of the month) |
| Excel serial | `45306` (2024-01-15, days since 1899-12-30) |

How dates are read:

- **One day/month order per file.** Dates such as `13/02/2024` (day first) or `01/13/2024` (month first) fit only one order. The order more of them fit is used for the whole file. A date that only fits the other order is reported as an error instead of being read differently.
- **When every date fits both orders** (for example `05/03/2024` and `04/02/2024`), the app asks whether the file is day-first or month-first before importing.
- **Two-digit years** are in this century: `24` is 2024. A year more than 10 years ahead is read as 19xx instead, so `99` is 1999.
- **Dates before 1950, or more than 10 years ahead,** are reported as errors.

---

## 4. Transaction Types

The parser recognizes these type variations:

| Type | Recognized Values |
|------|-------------------|
| **INVEST** | `invest`, `investment`, `invested`, `deposit` |
| **RETURN** | `return`, `withdrawal`, `withdraw`, `maturity`, `exit` |
| **INCOME** | `income`, `interest`, `dividend`, `payout` |
| **FEE** | `fee`, `fees`, `charge`, `expense` |

---

## 5. Investment Types

The Investment Type column takes the names below, ignoring case, spaces and punctuation. The display names shown in the app (`P2P Lending`, `Fixed Deposit`) also work. Any other value is imported as `other`.

| Investment Type | Also accepted |
|-----------------|---------------|
| `p2pLending` | `p2p` |
| `fixedDeposit` | `fd` |
| `bonds` | `bond` |
| `realEstate` | `property` |
| `privateEquity`, `angelInvesting`, `gold`, `crypto`, `invoiceDiscounting`, `financing`, `other` | |
| `chitFunds` | `chit`, `chitFund` |
| `mutualFunds` | `mutualFund`, `mf` |
| `stocks` | `stock` |

---

## 6. Import Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         IMPORT FLOW                              │
├─────────────────────────────────────────────────────────────────┤
│  1. User taps "Import" on Investments screen                    │
│  2. User selects CSV file from device                           │
│  3. App parses CSV and validates data                           │
│  4. If day and month could be swapped, user picks the order     │
│  5. User reviews parsed entries (grouped by investment)         │
│     Likely duplicates are marked and skipped unless allowed     │
│  6. User confirms import                                        │
│  7. App batch-writes all data to Firestore                      │
│  8. Success! Investments appear in list                         │
└─────────────────────────────────────────────────────────────────┘
```

A row is a **likely duplicate** when one of your investments with the same name (ignoring case) already has a cash flow with the same date, type, amount and currency. The confirmation screen says how many there are and skips them by default; turn off **Skip these rows** to import them anyway.

---

## 7. Architecture

### Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `SimpleCsvParser` | `bulk_import/data/services/` | Parses CSV content |
| `CsvTemplateService` | `bulk_import/data/services/` | Generates template CSV |
| `findLikelyDuplicateRows` | `bulk_import/data/services/` | Flags rows already imported |
| `BulkImportScreen` | `bulk_import/presentation/screens/` | File picker UI |
| `ImportConfirmationScreen` | `bulk_import/presentation/screens/` | Preview & confirm UI |
| `bulkImport()` | `investment_provider.dart` | Batch save to Firestore |

### Data Flow

```
CSV File → SimpleCsvParser → ParsedCsvResult → ImportConfirmationScreen
                                                        ↓
                                              InvestmentNotifier.bulkImport()
                                                        ↓
                                              FirestoreInvestmentRepository
                                                        ↓
                                              Firestore (batch writes)
```

---

## 8. Performance Optimizations

| Optimization | Description |
|--------------|-------------|
| **Batch Writes** | Uses Firestore batches (max 500 ops per batch) |
| **Single Invalidation** | Providers invalidated only once after all writes |
| **Async XIRR** | XIRR calculations happen after UI renders |
| **Memory Efficient** | Data prepared in memory before any writes |

### Before vs After Optimization

| Metric | Before | After |
|--------|--------|-------|
| 1000 rows import | ~60 seconds | ~3 seconds |
| Provider invalidations | 1000+ | 1 |
| Firestore writes | 1000+ individual | 2-3 batches |

---

## 9. Error Handling

| Error | User Message |
|-------|--------------|
| Empty file | "Empty file" |
| Missing columns | "Missing required columns. Required: Date, Investment Name, Type, Amount" |
| Invalid date | "Row X: Invalid date: [value]" |
| Date in the other day/month order | "Row X: Date [value] does not match the day/month order of the other dates in this file" |
| Date before 1950 or too far ahead | "Row X: Date out of range (1950 to [year]): [value]" |
| Unknown currency code | "Row X: Invalid currency code: [value]" |
| Invalid type | "Row X: Invalid type: [value]" |
| Invalid amount | "Row X: Invalid amount: [value]" |

---

## 10. Code Reuse

The `bulkImport()` method is used across the app:

1. **CSV Import** - `ImportConfirmationScreen`
2. **Demo Data Seeding** - `SeedDataService`
3. **Investment Merging** - `mergeInvestments()`

---

## 11. Future Enhancements

- [ ] Excel (.xlsx) file support
- [ ] Drag-and-drop import on web
- [ ] Import history/undo
- [ ] Column mapping UI for non-standard CSVs
- [ ] AI-assisted parsing for unstructured documents

---

*End of Document*

