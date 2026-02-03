# InvTrack Formula & Calculation Analysis Report

**Date**: 2026-02-02  
**Analyst**: Business Analyst & Product Manager Review  
**Scope**: Complete analysis of all financial formulas, calculations, and business logic

---

## Executive Summary

This report provides a comprehensive analysis of all formulas and calculations in InvTrack, identifying:
- ✅ **Strengths**: Well-implemented features
- ⚠️ **Issues**: Errors or inconsistencies found
- 💡 **Opportunities**: Improvements and new features

### Key Findings

| Category | Count | Severity |
|----------|-------|----------|
| Critical Issues | 3 | 🔴 High |
| Medium Issues | 5 | 🟡 Medium |
| Minor Issues | 4 | 🟢 Low |
| Opportunities | 8 | 💡 Enhancement |

---

## 1. Investment Return Calculations

### 1.1 XIRR (Internal Rate of Return)

**Location**: `lib/core/calculations/xirr_solver.dart`

**Formula**: Newton-Raphson method with bisection fallback

**Analysis**:
✅ **Strengths**:
- Robust implementation with multiple initial guesses
- Fallback to bisection method for edge cases
- Handles edge cases (single cash flow, all same sign)
- Approximate return calculation when no solution found

⚠️ **CRITICAL ISSUE #1: XIRR Approximation Formula Error**

**Line 168-185**:
```dart
// Calculate simple return
final simpleReturn = (totalInflows - totalOutflows) / totalOutflows;

// Annualize the return
if (simpleReturn >= -1) {
  // Standard CAGR formula
  return pow(1 + simpleReturn, 1 / years) - 1;
} else {
  // Total loss scenario - annualize the loss rate
  return simpleReturn / years;
}
```

**Problem**: The `years` variable is calculated as:
```dart
final years = maxDay - minDay;  // This is in DAYS, not years!
```

**Impact**: 
- If investment spans 365 days, `years = 365`, not `1.0`
- CAGR formula becomes: `pow(1 + simpleReturn, 1/365) - 1`
- This gives DAILY return, not annual return
- Result is severely understated (e.g., 50% return shows as ~0.11%)

**Fix Required**:
```dart
final years = (maxDay - minDay) / 365.0;  // Convert days to years
```

**Business Impact**: 
- Users see incorrect returns when XIRR fails to converge
- Affects trust in the app's calculations
- May cause users to make wrong investment decisions

---

### 1.2 CAGR (Compound Annual Growth Rate)

**Location**: `lib/core/calculations/financial_calculator.dart:22-30`

**Formula**: `CAGR = (endValue / startValue)^(1/years) - 1`

**Analysis**:
✅ **Correct implementation**
✅ **Proper edge case handling** (startValue <= 0, years <= 0)

⚠️ **ISSUE #2: CAGR Not Used Anywhere**

**Finding**: CAGR function exists but is never called in the codebase

**Opportunity**: 
- Add CAGR to investment detail screens
- Show CAGR alongside XIRR for comparison
- CAGR is simpler to understand for non-finance users

---

### 1.3 MOIC (Multiple on Invested Capital)

**Location**: `lib/core/calculations/financial_calculator.dart:32-37`

**Formula**: `MOIC = Total Returned / Total Invested`

**Analysis**:
✅ **Correct implementation**
✅ **Displayed prominently in UI**

💡 **OPPORTUNITY #1: Add MOIC Benchmarks**

**Suggestion**: Show industry benchmarks for MOIC by investment type
- P2P Lending: 1.2x - 1.5x (typical)
- Equity: 2x - 3x (good)
- Real Estate: 1.5x - 2.5x (typical)

**Value**: Helps users understand if their returns are good or bad

---

### 1.4 Absolute Return

**Location**: `lib/core/calculations/financial_calculator.dart:66-70`

**Formula**: `((returned - invested) / invested) * 100`

**Analysis**:
✅ **Correct implementation**

⚠️ **ISSUE #3: Confusing Terminology**

**Problem**: "Absolute Return" typically means total return without annualization
- Current implementation is correct
- But name might confuse users who expect annualized return

**Suggestion**: Rename to "Total Return %" or "Simple Return %"

---

## 2. Goal Tracking Calculations

### 2.1 Goal Progress Calculation

**Location**: `lib/features/goals/presentation/providers/goal_progress_provider.dart`

**Analysis**:

✅ **Strengths**:
- Supports multiple tracking modes (all, byType, selected)
- Handles both corpus and income goals
- Calculates monthly velocity for projections

⚠️ **CRITICAL ISSUE #4: Monthly Income Calculation Error**

**Line 126-146**:
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

  return totalIncome / months;
}
```

**Problems**:
1. **Inaccurate month calculation**: Uses 30 days per month (should use actual calendar months)
2. **Includes entire time span**: If user got income in Jan 2023 and Jan 2024, it divides by 12 months
   - But if they only got income in those 2 months, average should be based on 2 months, not 12
3. **Doesn't account for frequency**: Monthly income should be recent average, not lifetime average

**Example**:
- User gets ₹10,000 in Jan 2023
- User gets ₹10,000 in Dec 2024
- Current calculation: ₹20,000 / 24 months = ₹833/month ❌
- Reality: User gets ₹10,000/month (or ₹0 most months) ✅

**Fix Required**:
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
    // Fall back to all-time average if no recent data
    final totalIncome = incomeCashFlows.fold(0.0, (sum, cf) => sum + cf.amount);
    return totalIncome / 12; // Assume annual income spread over 12 months
  }
  
  // Calculate actual months with income
  final monthsWithIncome = <String>{};
  for (final cf in recentIncome) {
    monthsWithIncome.add('${cf.date.year}-${cf.date.month}');
  }
  
  final totalIncome = recentIncome.fold(0.0, (sum, cf) => sum + cf.amount);
  return totalIncome / monthsWithIncome.length;
}
```

**Business Impact**:
- Income goals show incorrect progress
- Users may think they're closer/farther from goal than reality
- Affects retirement planning decisions

---

### 2.2 Monthly Velocity Calculation

**Line 148-173**:

⚠️ **ISSUE #5: Similar Month Calculation Problem**

**Problem**: Same 30-day month assumption as above

**Additional Issue**: Includes ALL cash flows (invest, return, income, fees)
- Should only include positive contributions (invest + income)
- Currently includes returns, which inflates velocity

**Fix**: Filter to only investment and income cash flows

---

### 2.3 Goal Projection

**Line 51-60**:
```dart
DateTime? projectedDate;
if (monthlyVelocity > 0 && currentAmount < targetAmount) {
  final remaining = targetAmount - currentAmount;
  final monthsNeeded = remaining / monthlyVelocity;
  projectedDate = DateTime.now().add(
    Duration(days: (monthsNeeded * 30).round()),
  );
}
```

⚠️ **ISSUE #6: Linear Projection (No Compounding)**

**Problem**: Assumes linear growth, ignores investment returns

**Example**:
- Goal: ₹10,00,000
- Current: ₹2,00,000
- Monthly savings: ₹10,000
- Current calculation: 80 months (6.7 years)
- With 10% returns: ~60 months (5 years) ✅

**Fix**: Use future value formula with compounding

---

## 3. FIRE Number Calculations

### 3.1 Core FIRE Number

**Location**: `lib/features/fire_number/domain/services/fire_calculation_service.dart:14-49`

**Analysis**:

✅ **Strengths**:
- Comprehensive calculation including inflation
- Accounts for emergency fund and healthcare
- Adjusts for passive income and pension
- Supports different FIRE types (lean, regular, fat)

⚠️ **ISSUE #7: Healthcare Buffer Applied to Wrong Base**

**Line 36-37**:
```dart
final healthcareCorpusNeeded =
    coreRetirementCorpus * (settings.healthcareBuffer / 100);
```

**Problem**: Healthcare buffer is % of retirement corpus
- If corpus is ₹2 crore and buffer is 20%
- Healthcare = ₹40 lakhs
- But healthcare costs are typically fixed, not % of corpus

**Better Approach**: 
- Ask for estimated annual healthcare costs
- Multiply by years of retirement
- Or use industry standard (₹5-10 lakhs per year in India)

---

### 3.2 Coast FIRE Calculation

**Line 136-145**:
```dart
double _calculateCoastFireNumber({
  required double targetAmount,
  required int yearsToGrow,
  required double returnRate,
}) {
  if (yearsToGrow <= 0) return targetAmount;
  final rate = returnRate / 100;
  return targetAmount / math.pow(1 + rate, yearsToGrow).toDouble();
}
```

✅ **Correct implementation** - Present value formula

💡 **OPPORTUNITY #2: Add Coast FIRE Age**

**Suggestion**: Show the age at which user reaches Coast FIRE
- Currently only shows the number
- Users want to know "when can I stop saving?"

---

### 3.3 Required Monthly Savings

**Line 147-172**:

✅ **Correct PMT formula implementation**

⚠️ **ISSUE #8: Doesn't Account for Salary Growth**

**Problem**: Assumes constant monthly savings
- Reality: Salaries typically grow 5-10% per year
- Current calculation is pessimistic

**Opportunity**: Add optional salary growth rate parameter

---

### 3.4 Projected FIRE Age

**Line 174-196**:
```dart
int _calculateProjectedFireAge({
  required double targetAmount,
  required double currentAmount,
  required double monthlySavings,
  required double annualReturn,
  required int currentAge,
}) {
  if (currentAmount >= targetAmount) return currentAge;
  if (monthlySavings <= 0) return 100; // Never if not saving

  final monthlyRate = annualReturn / 100 / 12;
  var balance = currentAmount;
  var months = 0;
  const maxMonths = 600; // 50 years max

  while (balance < targetAmount && months < maxMonths) {
    balance = balance * (1 + monthlyRate) + monthlySavings;
    months++;
  }

  return currentAge + (months / 12).ceil();
}
```

✅ **Correct iterative calculation**

⚠️ **ISSUE #9: Performance Concern**

**Problem**: Iterative loop for up to 600 months
- Could use closed-form formula instead
- Current approach is O(n), formula is O(1)

**Fix**: Use future value of annuity formula

---

## 4. Investment Projections

### 4.1 Maturity Value Calculation

**Location**: `lib/core/calculations/investment_projector.dart:16-41`

**Formula**: `A = P * (1 + r/n)^(n*t)`

✅ **Correct compound interest formula**
✅ **Handles simple interest when periodsPerYear = 0**

💡 **OPPORTUNITY #3: Add Tax Impact**

**Suggestion**: Calculate post-tax returns
- TDS on FD interest (10% or 30%)
- LTCG/STCG on equity
- Shows realistic returns

---

### 4.2 Effective Annual Rate

**Line 59-77**:

✅ **Correct EAR formula**

💡 **OPPORTUNITY #4: Show EAR Prominently**

**Finding**: EAR calculated but not displayed in UI
- Users see nominal rate (e.g., 8%)
- Don't realize effective rate is higher with compounding (e.g., 8.3%)

---

## 5. Portfolio Aggregations

### 5.1 Total Invested Calculation

**Location**: `lib/core/calculations/financial_calculator.dart:44-53`

```dart
static double calculateTotalInvested(List<CashFlowEntity> cashFlows) {
  double total = 0.0;
  for (final cf in cashFlows) {
    if (cf.type.isOutflow) {
      total += cf.amount;
    }
  }
  return total;
}
```

✅ **Correct**: Includes INVEST + FEE

⚠️ **ISSUE #10: Fees Included in "Invested"**

**Problem**: Semantically confusing
- User invests ₹1,00,000
- Pays ₹1,000 fee
- App shows "Total Invested: ₹1,01,000"
- User expects ₹1,00,000

**Suggestion**: 
- Show "Total Outflow: ₹1,01,000"
- Show "Principal Invested: ₹1,00,000"
- Show "Fees Paid: ₹1,000"

---

### 5.2 Net Cash Flow

**Line 39-42**:
```dart
static double calculateNetCashFlow(double invested, double returned) {
  return returned - invested;
}
```

✅ **Correct for closed investments**

⚠️ **ISSUE #11: Misleading for Open Investments**

**Problem**: For open investments, "returned" only includes income/dividends
- Doesn't include current market value
- Shows negative even if investment is profitable

**Example**:
- Invested: ₹1,00,000
- Current value: ₹1,50,000
- Income received: ₹5,000
- Net cash flow: ₹5,000 - ₹1,00,000 = -₹95,000 ❌
- Reality: User is up ₹55,000 ✅

**Fix**: For open investments, add unrealized gains

---

## 6. Type Distribution

**Location**: `lib/features/investment/presentation/providers/investment_analytics_provider.dart:114-162`

✅ **Correct aggregation by type**

💡 **OPPORTUNITY #5: Add Asset Allocation View**

**Suggestion**: Group by asset class, not just investment type
- Equity: Stocks, Mutual Funds, ETFs
- Debt: FDs, Bonds, Debt Funds
- Alternative: P2P, Real Estate, Gold

**Value**: Better portfolio diversification insights

---

## 7. Year-over-Year Comparison

**Line 165-196**:

✅ **Correct YoY calculation**

⚠️ **ISSUE #12: Incomplete Year Comparison**

**Problem**: Compares partial current year to full previous year
- Jan-Feb 2026 vs Jan-Dec 2025
- Not apples-to-apples comparison

**Fix**: Compare same period (Jan-Feb 2026 vs Jan-Feb 2025)

---

## 8. Missing Calculations

### 8.1 Sharpe Ratio

**Status**: ❌ Not implemented

**Value**: Risk-adjusted returns
- Shows return per unit of risk
- Industry standard metric

**Formula**: `(Return - Risk-Free Rate) / Standard Deviation`

---

### 8.2 Drawdown Analysis

**Status**: ❌ Not implemented

**Value**: Shows maximum loss from peak
- Critical for risk assessment
- Helps users understand volatility

---

### 8.3 Asset Correlation

**Status**: ❌ Not implemented

**Value**: Shows diversification effectiveness
- Are investments truly diversified?
- Or moving together?

---

### 8.4 Tax Calculations

**Status**: ❌ Not implemented

**Value**: Post-tax returns
- TDS on interest
- Capital gains tax
- Shows realistic returns

---

## 9. Data Quality Issues

### 9.1 Month Calculations

**Pattern**: Multiple places use `days / 30.0` for months
- Inaccurate (months have 28-31 days)
- Should use actual calendar months

**Locations**:
- Goal progress (line 139)
- Monthly velocity (line 160)
- Goal projection (line 56)

---

### 9.2 Year Calculations

**Pattern**: Multiple places use `days / 365.0` for years
- Ignores leap years
- Should use actual date arithmetic

**Locations**:
- XIRR approximation (line 173)
- Investment stats duration (line 70)
- FIRE projection (line 94)

---

## 10. Recommendations

### Priority 1 (Critical - Fix Immediately)

1. **Fix XIRR approximation formula** (Issue #1)
   - Impact: Incorrect returns shown to users
   - Effort: 5 minutes
   - Risk: Low

2. **Fix monthly income calculation** (Issue #4)
   - Impact: Wrong goal progress
   - Effort: 30 minutes
   - Risk: Medium (test thoroughly)

3. **Fix net cash flow for open investments** (Issue #11)
   - Impact: Confusing UI, users think they're losing money
   - Effort: 1 hour
   - Risk: Medium (requires UI changes)

### Priority 2 (Important - Fix Soon)

4. **Fix monthly velocity calculation** (Issue #5)
5. **Add compounding to goal projections** (Issue #6)
6. **Fix YoY comparison** (Issue #12)
7. **Standardize month/year calculations** (Issues #9.1, #9.2)

### Priority 3 (Enhancement - Plan for Future)

8. **Add CAGR to UI** (Issue #2)
9. **Add MOIC benchmarks** (Opportunity #1)
10. **Add Coast FIRE age** (Opportunity #2)
11. **Add tax calculations** (Opportunity #3)
12. **Show EAR prominently** (Opportunity #4)
13. **Add asset allocation view** (Opportunity #5)
14. **Add Sharpe ratio** (Section 8.1)
15. **Add drawdown analysis** (Section 8.2)

---

## 11. Testing Recommendations

### Unit Tests Needed

1. **XIRR edge cases**:
   - Single cash flow
   - All outflows
   - All inflows
   - Very long time periods (>10 years)
   - Very short time periods (<1 month)

2. **Goal calculations**:
   - Monthly income with irregular payments
   - Velocity with mixed cash flow types
   - Projection with zero velocity

3. **FIRE calculations**:
   - Edge case: Already achieved FIRE
   - Edge case: Negative savings rate
   - Edge case: Very high return rates (>20%)

### Integration Tests Needed

1. **End-to-end return calculations**:
   - Create investment → Add cash flows → Verify stats
   - Test with real-world scenarios

2. **Goal tracking**:
   - Create goal → Link investments → Verify progress
   - Test all tracking modes

---

## 12. Conclusion

### Summary

InvTrack has a **solid foundation** for financial calculations with:
- ✅ Robust XIRR implementation
- ✅ Comprehensive FIRE calculations
- ✅ Good separation of concerns

However, there are **critical issues** that need immediate attention:
- 🔴 XIRR approximation formula error
- 🔴 Monthly income calculation error
- 🔴 Net cash flow misleading for open investments

### Business Impact

**Current State**:
- Users may see incorrect returns (XIRR approximation)
- Goal progress is inaccurate (monthly income)
- Open investments appear to be losing money (net cash flow)

**After Fixes**:
- Accurate return calculations
- Reliable goal tracking
- Clear portfolio performance

### Next Steps

1. **Immediate** (This Week):
   - Fix XIRR approximation
   - Fix monthly income calculation
   - Add unit tests for edge cases

2. **Short Term** (This Month):
   - Fix net cash flow for open investments
   - Standardize date calculations
   - Add missing UI elements (CAGR, EAR)

3. **Long Term** (Next Quarter):
   - Add tax calculations
   - Add risk metrics (Sharpe, drawdown)
   - Add asset allocation view

---

**Report Prepared By**: AI Business Analyst  
**Review Status**: Ready for Engineering Review  
**Confidence Level**: High (based on comprehensive code analysis)

