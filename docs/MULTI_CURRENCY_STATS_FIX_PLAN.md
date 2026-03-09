# Multi-Currency Stats Fix Plan

## Problem
`InvestmentStats` (via `calculateStats`) aggregates cash flow amounts directly without currency conversion, violating Rule 21.3.

**Example Bug:**
- Investment has: $1,000 USD + ₹50,000 INR
- Current behavior: `totalInvested = 51,000` (mixed units!)
- Expected behavior: `totalInvested = ~$1,601.54` (all converted to USD)

## Root Cause
`calculateStats()` in `investment_stats_provider.dart` (lines 331-335):
```dart
if (cf.type.isOutflow) {
  totalInvested += cf.amount;  // ❌ No currency conversion!
}
```

## Solution Strategy

### Option 1: Make `calculateStats` Async (REJECTED)
- **Pros:** Single source of truth
- **Cons:** Breaks 6+ call sites, requires major refactoring, breaks existing tests

### Option 2: Create Multi-Currency Providers (SELECTED ✅)
- **Pros:** Backward compatible, incremental migration, existing tests still pass
- **Cons:** Temporary duplication until full migration

## Implementation Plan

### Step 1: Create Multi-Currency Stats Providers
Create new providers in `multi_currency_providers.dart`:
- `multiCurrencyInvestmentStatsProvider` - Per-investment stats with conversion
- `multiCurrencyGlobalStatsProvider` - Global stats with conversion

These will:
1. Fetch cash flows from existing providers
2. Convert each cash flow to base currency using `CurrencyConversionService`
3. Aggregate converted amounts
4. Return `InvestmentStats` with correct totals

### Step 2: Update UI to Use New Providers
Update screens to watch new providers:
- `InvestmentDetailScreen` → `multiCurrencyInvestmentStatsProvider`
- `PortfolioScreen` → `multiCurrencyGlobalStatsProvider`
- `InvestmentListScreen` → Keep old provider (no multi-currency display)

### Step 3: Add Tests
- Unit tests for new providers
- Widget tests to verify UI shows correct converted amounts
- Integration tests for base currency change

### Step 4: Deprecate Old Providers (Future)
- Mark old providers as `@Deprecated`
- Migrate remaining call sites
- Remove old providers in next major version

## Files to Modify

1. **lib/features/investment/presentation/providers/multi_currency_providers.dart**
   - Add `multiCurrencyInvestmentStatsProvider`
   - Add `multiCurrencyGlobalStatsProvider`

2. **lib/features/investment/presentation/screens/investment_detail_screen.dart**
   - Replace `investmentStatsProvider` with `multiCurrencyInvestmentStatsProvider`

3. **test/features/investment/presentation/providers/multi_currency_stats_test.dart** (NEW)
   - Test multi-currency aggregation
   - Test base currency change impact

## Success Criteria
- ✅ All existing tests pass (backward compatibility)
- ✅ New multi-currency tests pass
- ✅ UI shows correct converted amounts
- ✅ Base currency change updates stats correctly
- ✅ No performance regression (caching works)

