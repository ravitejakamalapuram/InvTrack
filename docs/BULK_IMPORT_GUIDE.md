# Bulk Import Guide

> **Version 2.0** — December 2024

---

## 1. Overview

InvTrack supports bulk importing investment data via CSV files. This allows users to quickly import historical investment data from spreadsheets or exported data from other platforms.

### Key Features
- **CSV Import**: Upload CSV files with investment cash flow data
- **Smart Date Parsing**: Automatically detects various date formats
- **Flexible Type Mapping**: Recognizes common transaction type names
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
| **Amount** | Transaction amount | `10000`, `₹5,000`, `$1000.50` |

### Optional Columns

| Column | Description |
|--------|-------------|
| **Notes** | Additional notes for the transaction |

### Sample CSV

```csv
Date,Investment Name,Type,Amount,Notes
2024-01-15,HDFC FD,invest,100000,Initial deposit
2024-04-15,HDFC FD,income,1750,Q1 interest
2024-07-15,HDFC FD,income,1750,Q2 interest
Jan-24,Groww P2P,invest,50000,
Feb-24,Groww P2P,income,625,Monthly payout
Mar-24,Groww P2P,income,625,Monthly payout
```

---

## 3. Supported Date Formats

The parser automatically detects these date formats:

| Format | Example |
|--------|---------|
| ISO | `2024-01-15` |
| DD/MM/YYYY | `15/01/2024` |
| MM/DD/YYYY | `01/15/2024` |
| DD-MMM-YYYY | `15-Jan-2024` |
| MMM-YY | `Jan-24` (uses 1st of month) |
| Excel Serial | `45307` (days since 1899-12-30) |

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

## 5. Import Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         IMPORT FLOW                              │
├─────────────────────────────────────────────────────────────────┤
│  1. User taps "Import" on Investments screen                    │
│  2. User selects CSV file from device                           │
│  3. App parses CSV and validates data                           │
│  4. User reviews parsed entries (grouped by investment)         │
│  5. User confirms import                                        │
│  6. App batch-writes all data to Firestore                      │
│  7. Success! Investments appear in list                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 6. Architecture

### Components

| Component | Location | Purpose |
|-----------|----------|---------|
| `SimpleCsvParser` | `bulk_import/domain/services/` | Parses CSV content |
| `CsvTemplateService` | `bulk_import/domain/services/` | Generates template CSV |
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

## 7. Performance Optimizations

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

## 8. Error Handling

| Error | User Message |
|-------|--------------|
| Empty file | "Empty file" |
| Missing columns | "Missing required columns. Required: Date, Investment Name, Type, Amount" |
| Invalid date | "Row X: Invalid date: [value]" |
| Invalid type | "Row X: Invalid type: [value]" |
| Invalid amount | "Row X: Invalid amount: [value]" |

---

## 9. Code Reuse

The `bulkImport()` method is used across the app:

1. **CSV Import** - `ImportConfirmationScreen`
2. **Demo Data Seeding** - `SeedDataService`
3. **Investment Merging** - `mergeInvestments()`

---

## 10. Future Enhancements

- [ ] Excel (.xlsx) file support
- [ ] Drag-and-drop import on web
- [ ] Import history/undo
- [ ] Column mapping UI for non-standard CSVs
- [ ] AI-assisted parsing for unstructured documents

---

*End of Document*

