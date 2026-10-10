# Multi-Currency Support - PR Checklist

> **Comprehensive checklist for P0 Task 2: Multi-Currency Support**
> 
> This document tracks all tasks required to make the multi-currency feature production-ready.

---

## 📋 **Status Overview**

**Overall Progress:** 🟡 **85% Complete**

| Phase | Status | Progress |
|-------|--------|----------|
| Core Infrastructure | ✅ Complete | 100% |
| UI Integration | ✅ Complete | 100% |
| Data Lifecycle | 🟡 In Progress | 60% |
| Import/Export | 🔴 Not Started | 0% |
| Sample Data | 🔴 Not Started | 0% |
| Testing | 🔴 Not Started | 0% |

---

## ✅ **Phase 1: Core Infrastructure (COMPLETE)**

### 1.1 Currency Conversion Service
- [x] Three-tier caching (Memory → Firestore → API)
- [x] Historical rate support (immutable, cached forever)
- [x] Live rate support (expires end of day)
- [x] Dual API support (Frankfurter + ExchangeRate-API fallback)
- [x] Rate limiting (Token Bucket: 10 calls/min)
- [x] LRU eviction (max 100 entries in memory)
- [x] Offline-first pattern (Firestore cache)
- [x] Analytics tracking (cache hits, failures)

**Files:**
- ✅ `lib/core/services/currency_conversion_service.dart`
- ✅ `lib/core/services/currency_conversion_service.g.dart`

### 1.2 Data Model
- [x] `InvestmentEntity` has `currency` field
- [x] `CashFlowEntity` has `currency` field
- [x] Firestore schema updated
- [x] Backward compatibility (defaults to 'USD')

**Files:**
- ✅ `lib/features/investment/domain/entities/investment_entity.dart`
- ✅ `lib/features/investment/domain/entities/transaction_entity.dart`
- ✅ `lib/features/investment/data/repositories/firestore_investment_repository.dart`

### 1.3 Settings Integration
- [x] Base currency selection (35+ currencies)
- [x] Currency locale provider
- [x] Currency symbol provider
- [x] Persistent storage (SharedPreferences)

**Files:**
- ✅ `lib/features/settings/presentation/providers/currency_providers.dart`
- ✅ `lib/features/settings/presentation/screens/currency_selection_screen.dart`

---

## ✅ **Phase 2: UI Integration (COMPLETE)**

### 2.1 Forms
- [x] Add Investment Form (currency dropdown)
- [x] Add Cash Flow Form (currency dropdown)
- [x] Edit Investment Form (currency dropdown)
- [x] Edit Cash Flow Form (currency dropdown)

**Files:**
- ✅ `lib/features/investment/presentation/screens/add_investment_screen.dart`
- ✅ `lib/features/investment/presentation/widgets/add_cash_flow_sheet.dart`

### 2.2 Display
- [x] Investment cards show converted values
- [x] Cash flow cards show exchange rates
- [x] Portfolio totals in base currency
- [x] XIRR/CAGR calculations use converted amounts

**Files:**
- ✅ `lib/features/investment/presentation/widgets/investment_card.dart`
- ✅ `lib/features/investment/presentation/widgets/cash_flow_card_widget.dart`

### 2.3 Transparency
- [x] Exchange rate info in cash flow cards
- [x] Format: "1 USD = 83.50 INR • ₹8,350"
- [x] Only shows when currency differs from base

**Files:**
- ✅ `lib/features/investment/presentation/widgets/cash_flow_card_widget.dart`

### 2.4 Manual Refresh
- [x] Pull-to-refresh on investment list
- [x] Pull-to-refresh on overview screen
- [x] Smart throttling (1-hour minimum)

**Files:**
- ✅ `lib/features/investment/presentation/screens/investment_list_screen.dart`
- ✅ `lib/features/overview/presentation/screens/overview_screen.dart`

---

## 🟡 **Phase 3: Data Lifecycle (IN PROGRESS)**

### 3.1 Cache Initialization
- [x] Preload common rates on app start
- [x] Smart refresh (only if >1 hour stale)
- [x] Non-blocking initialization

**Files:**
- ✅ `lib/core/widgets/currency_cache_initializer.dart`

### 3.2 Cache Cleanup
- [ ] 🔴 **CRITICAL:** Delete exchange rate cache on user data deletion
- [ ] Add to `deleteAllUserData()` flow
- [ ] Batch delete all documents in `users/{userId}/exchangeRates`

**Files:**
- 🔴 `lib/features/settings/presentation/screens/data_management_screen.dart`

---

## 🔴 **Phase 4: Import/Export (NOT STARTED)**

### 4.1 CSV Export Enhancement
- [ ] 🔴 **CRITICAL:** Add currency column to CSV export
- [ ] Update header: `Date, Investment Name, Type, Amount, Currency, Notes`
- [ ] Include currency for each cash flow
- [ ] Maintain backward compatibility

**Files:**
- 🔴 `lib/features/settings/data/services/export_service.dart`

### 4.2 CSV Import Enhancement
- [ ] 🔴 **CRITICAL:** Parse currency column from CSV
- [ ] Default to base currency if column missing (backward compat)
- [ ] Validate currency codes (ISO 4217)
- [ ] Show currency in preview screen

**Files:**
- 🔴 `lib/features/bulk_import/data/services/simple_csv_parser.dart`
- 🔴 `lib/features/bulk_import/presentation/screens/import_confirmation_screen.dart`

### 4.3 ZIP Export Enhancement
- [ ] 🟡 Add currency column to `cashflows.csv`
- [ ] Add currency column to `cashflows_archived.csv`
- [ ] Include currency in metadata.json
- [ ] Update import service to read currency

**Files:**
- 🔴 `lib/features/settings/data/services/data_export_service.dart`
- 🔴 `lib/features/settings/data/services/data_import_service.dart`

---

## 🔴 **Phase 5: Sample Data (NOT STARTED)**

### 5.1 Multi-Currency Portfolio
- [ ] 🔴 **CRITICAL:** Create diverse sample portfolio
- [ ] US Stocks (USD) - $1,000
- [ ] Indian FD (INR) - ₹2,00,000
- [ ] European Bonds (EUR) - €800
- [ ] Gold SGB (INR) - ₹50,000
- [ ] Demonstrate currency conversion in UI
- [ ] Show exchange rate transparency

**Files:**
- 🔴 `lib/features/settings/data/services/sample_data_service.dart`

---

## 🔴 **Phase 6: Testing (NOT STARTED)**

### 6.1 Unit Tests
- [ ] Currency conversion service tests
- [ ] Cache hit/miss scenarios
- [ ] API fallback logic
- [ ] Rate limiting tests
- [ ] LRU eviction tests

### 6.2 Widget Tests
- [ ] Currency selection UI
- [ ] Exchange rate display
- [ ] Base currency change updates display
- [ ] Original data unchanged after currency change

### 6.3 Integration Tests
- [ ] End-to-end conversion flow
- [ ] Import/export with currency
- [ ] Sample data creation
- [ ] Cache cleanup on delete

---

## 📊 **Critical Path Items**

**Must complete before PR merge:**

1. 🔴 **Exchange Rate Cache Cleanup** (Rule 21.6)
   - File: `data_management_screen.dart`
   - Effort: 1 hour
   - Impact: Data lifecycle violation

2. 🔴 **CSV Import/Export Currency Column** (Rule 21.4)
   - Files: `export_service.dart`, `simple_csv_parser.dart`
   - Effort: 4 hours
   - Impact: Data loss on export/import

3. 🔴 **Multi-Currency Sample Data** (Rule 21.5)
   - File: `sample_data_service.dart`
   - Effort: 2 hours
   - Impact: Poor UX for new users

**Total Critical Path Effort:** ~7 hours

---

## 🎯 **Next Steps**

1. ✅ Complete Task 3: Exchange Rate Cache Cleanup
2. ✅ Complete Task 1: CSV Import/Export Enhancement
3. ✅ Complete Task 2: Multi-Currency Sample Data
4. ⏭️ Add ZIP export/import support
5. ⏭️ Write comprehensive tests
6. ⏭️ Update documentation
7. ⏭️ Create PR for review

---

**Last Updated:** 2026-02-27
**Status:** Ready to complete critical path items

