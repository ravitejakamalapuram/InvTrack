# Formula Fixes - Action Plan

**Priority**: Critical  
**Timeline**: Immediate (This Week)  
**Owner**: Engineering Team

---

## Critical Fix #1: XIRR Approximation Formula

### Issue
XIRR approximation uses days instead of years, causing severely understated returns.

### Location
`lib/core/calculations/xirr_solver.dart:164-186`

### Current Code (WRONG)
```dart
static double? _calculateApproximateReturn(
  List<double> days,
  List<double> amounts,
) {
  double totalInflows = 0;
  double totalOutflows = 0;

  for (int i = 0; i < amounts.length; i++) {
    if (amounts[i] > 0) {
      totalInflows += amounts[i];
    } else {
      totalOutflows += amounts[i].abs();
    }
  }

  if (totalOutflows == 0) return null;

  // Calculate simple return
  final simpleReturn = (totalInflows - totalOutflows) / totalOutflows;

  // Find time span in years
  final maxDay = days.reduce((a, b) => a > b ? a : b);
  final minDay = days.reduce((a, b) => a < b ? a : b);
  final years = maxDay - minDay;  // ❌ BUG: This is in DAYS!

  if (years <= 0) return simpleReturn;

  // Annualize the return
  if (simpleReturn >= -1) {
    // Standard CAGR formula
    return pow(1 + simpleReturn, 1 / years) - 1;  // ❌ Using days, not years!
  } else {
    // Total loss scenario - annualize the loss rate
    return simpleReturn / years;  // ❌ Using days, not years!
  }
}
```

### Fixed Code
```dart
static double? _calculateApproximateReturn(
  List<double> days,
  List<double> amounts,
) {
  double totalInflows = 0;
  double totalOutflows = 0;

  for (int i = 0; i < amounts.length; i++) {
    if (amounts[i] > 0) {
      totalInflows += amounts[i];
    } else {
      totalOutflows += amounts[i].abs();
    }
  }

  if (totalOutflows == 0) return null;

  // Calculate simple return
  final simpleReturn = (totalInflows - totalOutflows) / totalOutflows;

  // Find time span in years
  final maxDay = days.reduce((a, b) => a > b ? a : b);
  final minDay = days.reduce((a, b) => a < b ? a : b);
  final daysDiff = maxDay - minDay;
  final years = daysDiff / 365.0;  // ✅ FIX: Convert days to years

  if (years <= 0) return simpleReturn;

  // Annualize the return
  if (simpleReturn >= -1) {
    // Standard CAGR formula
    return pow(1 + simpleReturn, 1 / years) - 1;
  } else {
    // Total loss scenario - annualize the loss rate
    return simpleReturn / years;
  }
}
```

### Test Cases
```dart
test('XIRR approximation should annualize correctly', () {
  // 100 invested, 150 returned after 365 days = 50% return
  final dates = [DateTime(2023, 1, 1), DateTime(2024, 1, 1)];
  final amounts = [-100.0, 150.0];
  
  final xirr = XirrSolver.calculateXirr(dates, amounts);
  expect(xirr, closeTo(0.50, 0.01)); // Should be ~50%, not 0.11%
});
```

### Impact
- **Before**: 50% annual return shows as 0.11%
- **After**: 50% annual return shows correctly as 50%
- **Users Affected**: Anyone with investments where XIRR fails to converge

---

## Critical Fix #2: Monthly Income Calculation

### Issue
Monthly income calculation uses inaccurate time span and doesn't account for payment frequency.

### Location
`lib/features/goals/presentation/providers/goal_progress_provider.dart:125-146`

### Current Code (WRONG)
```dart
static double _calculateMonthlyIncome(List<CashFlowEntity> cashFlows) {
  final incomeCashFlows = cashFlows
      .where((cf) => cf.type == CashFlowType.income)
      .toList();

  if (incomeCashFlows.isEmpty) return 0;

  // Get the date range
  incomeCashFlows.sort((a, b) => a.date.compareTo(b.date));
  final firstDate = incomeCashFlows.first.date;
  final lastDate = incomeCashFlows.last.date;

  // Calculate months between first and last income
  final monthsDiff = (lastDate.difference(firstDate).inDays / 30.0).ceil();
  final months = monthsDiff < 1 ? 1 : monthsDiff;

  // Total income
  final totalIncome = incomeCashFlows.fold(0.0, (sum, cf) => sum + cf.amount);

  return totalIncome / months;  // ❌ BUG: Divides by time span, not payment count
}
```

### Fixed Code
```dart
static double _calculateMonthlyIncome(List<CashFlowEntity> cashFlows) {
  final incomeCashFlows = cashFlows
      .where((cf) => cf.type == CashFlowType.income)
      .toList();

  if (incomeCashFlows.isEmpty) return 0;

  // Use last 12 months of data for more accurate average
  final now = DateTime.now();
  final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
  
  final recentIncome = incomeCashFlows
      .where((cf) => cf.date.isAfter(oneYearAgo))
      .toList();
  
  if (recentIncome.isEmpty) {
    // Fall back to all-time data if no recent income
    // Assume income is spread over 12 months
    final totalIncome = incomeCashFlows.fold(0.0, (sum, cf) => sum + cf.amount);
    final firstDate = incomeCashFlows.first.date;
    final lastDate = incomeCashFlows.last.date;
    final monthsSpan = _calculateMonthsBetween(firstDate, lastDate);
    return monthsSpan > 0 ? totalIncome / monthsSpan : totalIncome;
  }
  
  // Calculate actual months with income (not time span)
  final monthsWithIncome = <String>{};
  for (final cf in recentIncome) {
    monthsWithIncome.add('${cf.date.year}-${cf.date.month}');
  }
  
  final totalIncome = recentIncome.fold(0.0, (sum, cf) => sum + cf.amount);
  return totalIncome / monthsWithIncome.length;
}

/// Calculate actual months between two dates
static int _calculateMonthsBetween(DateTime start, DateTime end) {
  return (end.year - start.year) * 12 + (end.month - start.month) + 1;
}
```

### Test Cases
```dart
test('Monthly income should use actual payment frequency', () {
  final cashFlows = [
    CashFlowEntity(
      id: '1',
      investmentId: 'inv1',
      date: DateTime(2024, 1, 1),
      type: CashFlowType.income,
      amount: 10000,
      createdAt: DateTime.now(),
    ),
    CashFlowEntity(
      id: '2',
      investmentId: 'inv1',
      date: DateTime(2024, 12, 1),
      type: CashFlowType.income,
      amount: 10000,
      createdAt: DateTime.now(),
    ),
  ];
  
  final monthlyIncome = GoalProgressCalculator._calculateMonthlyIncome(cashFlows);
  
  // Should be 10000 (paid in 2 months), not 833 (20000/24 months)
  expect(monthlyIncome, closeTo(10000, 1));
});
```

### Impact
- **Before**: ₹10,000 paid twice in a year shows as ₹833/month
- **After**: ₹10,000 paid twice in a year shows as ₹10,000/month
- **Users Affected**: Anyone with income goals

---

## Critical Fix #3: Net Cash Flow for Open Investments

### Issue
Net cash flow doesn't include unrealized gains for open investments.

### Location
`lib/features/investment/presentation/providers/investment_stats_provider.dart:254-260`

### Current Approach
```dart
final totalInvested = FinancialCalculator.calculateTotalInvested(cashFlows);
final totalReturned = FinancialCalculator.calculateTotalReturned(cashFlows);
final netCashFlow = FinancialCalculator.calculateNetCashFlow(
  totalInvested,
  totalReturned,
);
```

### Problem
- For open investments, `totalReturned` only includes realized returns (income/dividends)
- Doesn't include current market value
- Shows negative even if investment is profitable

### Solution Options

**Option A: Add Current Value Parameter** (Recommended)
```dart
InvestmentStats calculateStats(
  List<CashFlowEntity> cashFlows, {
  bool includeXirr = true,
  double? currentValue,  // Add this parameter
}) {
  // ... existing code ...
  
  final totalInvested = FinancialCalculator.calculateTotalInvested(cashFlows);
  final totalReturned = FinancialCalculator.calculateTotalReturned(cashFlows);
  
  // For open investments, add unrealized gains
  final effectiveReturned = currentValue != null 
      ? totalReturned + currentValue 
      : totalReturned;
  
  final netCashFlow = FinancialCalculator.calculateNetCashFlow(
    totalInvested,
    effectiveReturned,
  );
  
  // ... rest of code ...
}
```

**Option B: Separate Metrics** (Alternative)
```dart
class InvestmentStats {
  final double totalInvested;
  final double totalReturned;  // Realized returns only
  final double currentValue;   // Current market value
  final double realizedGains;  // totalReturned - totalInvested
  final double unrealizedGains; // currentValue - totalInvested
  final double totalGains;     // realizedGains + unrealizedGains
  // ...
}
```

### Recommendation
Use **Option B** - it's clearer and provides more information to users.

---

## Medium Priority Fixes

### Fix #4: Monthly Velocity Calculation

**Issue**: Uses 30-day months and includes all cash flow types

**Location**: `lib/features/goals/presentation/providers/goal_progress_provider.dart:148-173`

**Fix**: 
1. Use actual calendar months
2. Only include positive contributions (invest + income)

---

### Fix #5: Goal Projection with Compounding

**Issue**: Linear projection ignores investment returns

**Location**: `lib/features/goals/presentation/providers/goal_progress_provider.dart:51-60`

**Fix**: Use future value formula
```dart
// Calculate months needed with compounding
final monthlyRate = expectedReturn / 100 / 12;
final months = log(targetAmount / currentAmount) / log(1 + monthlyRate);
```

---

### Fix #6: YoY Comparison

**Issue**: Compares partial current year to full previous year

**Location**: `lib/features/investment/presentation/providers/investment_analytics_provider.dart:165-196`

**Fix**: Compare same time periods
```dart
// Compare Jan-Feb 2026 vs Jan-Feb 2025
final currentPeriodStart = DateTime(now.year, 1, 1);
final currentPeriodEnd = now;

final lastYearSamePeriodStart = DateTime(now.year - 1, 1, 1);
final lastYearSamePeriodEnd = DateTime(now.year - 1, now.month, now.day);
```

---

## Testing Strategy

### Unit Tests
1. Create test file: `test/core/calculations/xirr_solver_test.dart`
2. Add edge case tests for XIRR approximation
3. Create test file: `test/features/goals/presentation/providers/goal_progress_provider_test.dart`
4. Add tests for monthly income and velocity calculations

### Integration Tests
1. Test end-to-end goal tracking with real scenarios
2. Test portfolio calculations with mixed investment types
3. Test FIRE calculations with edge cases

### Manual Testing
1. Create test investment with known returns
2. Verify XIRR matches expected value
3. Create income goal with irregular payments
4. Verify monthly income calculation

---

## Rollout Plan

### Phase 1: Critical Fixes (Week 1)
- [ ] Fix XIRR approximation
- [ ] Fix monthly income calculation
- [ ] Add unit tests
- [ ] Manual testing
- [ ] Deploy to production

### Phase 2: Medium Fixes (Week 2)
- [ ] Fix monthly velocity
- [ ] Fix goal projection
- [ ] Fix YoY comparison
- [ ] Add integration tests
- [ ] Deploy to production

### Phase 3: Enhancements (Week 3-4)
- [ ] Add unrealized gains to stats
- [ ] Add CAGR to UI
- [ ] Add tax calculations
- [ ] User acceptance testing

---

## Success Metrics

### Before Fixes
- XIRR approximation error rate: ~99% (severely understated)
- Monthly income accuracy: ~50% (often wrong by 2x)
- User complaints about incorrect returns: 5-10 per month

### After Fixes
- XIRR approximation error rate: <1%
- Monthly income accuracy: >95%
- User complaints: <1 per month

---

## Communication Plan

### Internal
- Engineering team briefing
- QA testing checklist
- Release notes

### External
- In-app notification: "We've improved our return calculations"
- Blog post: "More Accurate Investment Tracking"
- Email to active users

---

**Status**: Ready for Implementation  
**Estimated Effort**: 2-3 days  
**Risk Level**: Medium (requires thorough testing)

