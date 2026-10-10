# InvTracker — Technical Specification

## 1. Architecture
- Flutter app (Dart)
- SQLite local DB
- Google Sheets + Google Drive API
- Offline-first sync engine
- Secure storage for tokens

## 2. Sheets Schema
Columns:
id, user_id, investment_id, investment_name, category, date, type, amount,
currency, units, price_per_unit, running_value, transaction_id, note,
created_at, updated_at, source, sync_status, meta

## 3. Sync Engine
- Queue-based sync
- Conflict detection using updated_at timestamps
- Sheet protection + hidden _meta tab

## 4. Calculations
- XIRR (Newton-Raphson)
- TWRR (geometric linked returns)
- CAGR, IRR, MOIC
- P/L (realized + unrealized)

## 5. Security
- OAuth scopes: drive.file & spreadsheets
- Tokens stored in secure keystore
