# InvTrack Formula & Calculation Analysis

**Date**: 2026-02-03  
**Branch**: main (latest)  
**Purpose**: Document all financial formulas, identify issues, and recommend improvements

---

## Table of Contents

1. [XIRR Calculation](#1-xirr-calculation)
2. [CAGR Calculation](#2-cagr-calculation)
3. [Compound Interest](#3-compound-interest)
4. [FIRE Calculation](#4-fire-calculation)
5. [Goal Progress](#5-goal-progress)
6. [Portfolio Stats](#6-portfolio-stats)
7. [Issues Summary](#7-issues-summary)
8. [Recommendations](#8-recommendations)

---

## 1. XIRR Calculation

### Location
`lib/core/calculations/xirr_solver.dart`

### Formula
```
NPV = Σ(CF_i / (1 + r)^t_i) = 0

Where:
- CF_i = Cash flow at time i
- r = XIRR (what we're solving for)
- t_i = Time in years from first cash flow
```

### Implementation
```dart
// Line 19-21: Convert dates to years
final yearsFromStart = dates
    .map((d) => d.difference(firstDate).inDays / 365.0)
    .toList();
```

### Algorithm
1. **Newton-Raphson** with 7 initial guesses
2. **Bisection method** as fallback
3. **Approximate return** if both fail

### ✅ Strengths
- Robust multi-guess approach
- Handles edge cases (total loss, near-zero returns)
- Good variable naming (`yearsFromStart` instead of `days`)
- Well-tested (20+ unit tests)

### ⚠️ Observations
1. **Day Count Convention**: Uses ACT/365 (365.0 days/year)
   - Industry standard: ACT/365 or ACT/365.25
   - Current: 365.0 (ignores leap years)
   - Alternative: 365.25 (accounts for leap years on average)
   - Impact: <0.1% difference in most cases
   - **Status**: Acceptable, optional enhancement

2. **Return Cap**: 1000% (line 103)
   - Current: `if (x > 10.0) x = 10.0;`
   - Recommendation: Lower to 500% and log warning
   - Reason: >500% suggests data error

3. **Tolerance**: 1e-7 (line 4)
   - Very tight (0.00001%)
   - Industry standard: 1e-4 (0.01%)
   - Impact: May cause unnecessary iterations
   - Recommendation: Increase to 1e-4

### 🟢 Recommendation
**KEEP AS IS** - Working correctly, optional minor enhancements

---

## 2. CAGR Calculation

### Location
`lib/core/calculations/financial_calculator.dart:23-30`

### Formula
```
CAGR = (End Value / Start Value)^(1/years) - 1
```

### Implementation
```dart
static double calculateCAGR(double startValue, double endValue, double years) {
  if (startValue <= 0 || years <= 0) return 0.0;
  return pow(endValue / startValue, 1 / years) - 1;
}
```

### ✅ Strengths
- Mathematically correct
- Handles edge cases (zero/negative start value)
- Simple and efficient

### ⚠️ Observation
**CAGR is calculated but NEVER USED in the UI!**

Search results: Zero usages in presentation layer

### 🟡 Recommendation
**ADD TO UI** - Show both XIRR and CAGR for clarity

**Why show both?**
- XIRR: Time-weighted return (accounts for all cash flows)
- CAGR: Simple growth rate (start to end)
- Users benefit from seeing both perspectives

**Example UI**:
```
Returns:
├─ XIRR: 12.5% (time-weighted, all cash flows)
└─ CAGR: 13.2% (simple growth rate)
```

---

## 3. Compound Interest

### Location
`lib/core/calculations/investment_projector.dart:16-41`

### Formula
```
A = P × (1 + r/n)^(n×t)

Where:
- A = Maturity value
- P = Principal
- r = Annual interest rate
- n = Compounding frequency
- t = Time in years
```

### Implementation
```dart
final rate = annualRate / 100;
final years = tenureMonths / 12;
final periodsPerYear = compounding?.periodsPerYear ?? 1;

final compoundFactor = math.pow(
  1 + rate / periodsPerYear,
  periodsPerYear * years,
);
return principal * compoundFactor;
```

### ✅ Strengths
- Mathematically correct
- Supports multiple compounding frequencies
- Handles simple interest (periodsPerYear = 0)
- Well-tested (15+ unit tests)

### 🟢 Recommendation
**KEEP AS IS** - Working perfectly

---

## 4. FIRE Calculation

### Location
`lib/features/fire_number/domain/services/fire_calculation_service.dart:14-49`

### Current Implementation
```dart
// Step 1: Inflate expenses to retirement year
final inflationMultiplier = math.pow(1 + settings.inflationRate / 100, yearsToFire);
final inflationAdjustedMonthlyExpenses = adjustedMonthlyExpenses * inflationMultiplier;

// Step 2: Calculate FIRE number based on inflated expenses
final coreRetirementCorpus = inflationAdjustedAnnualExpenses * settings.fireMultiplier;

// Step 3: Calculate required savings using NOMINAL returns
final requiredMonthlySavings = _calculateRequiredMonthlySavings(
  targetAmount: finalFireNumber,
  annualReturn: settings.preRetirementReturn, // Uses nominal return!
);
```

### 🔴 CRITICAL ISSUE: Inflation Handling

**Problem**: Mixes inflated target with nominal returns

**Example**:
```
Current expenses: ₹50,000/month
Years to FIRE: 20
Inflation: 6%
Expected return: 12%

Current calculation:
1. Inflated expenses = ₹50,000 × (1.06)^20 = ₹1,60,357/month
2. FIRE number = ₹1,60,357 × 12 × 25 = ₹4,81,07,100
3. Required savings (using 12% return) = ₹38,717/month

Correct calculation:
1. FIRE number (today's money) = ₹50,000 × 12 × 25 = ₹1,50,00,000
2. Real return = 12% - 6% = 6%
3. Required savings (using 6% real return) = ₹25,530/month

Error: 3.2x overestimation of FIRE number!
       34% higher required savings!
```

### Why This Is Wrong

**Current logic assumes**:
- Expenses stay constant for 20 years
- Then suddenly jump to inflated amount at retirement
- Investments grow at nominal 12%

**Reality**:
- Expenses inflate EVERY year
- Investment returns are also affected by inflation
- What matters is REAL purchasing power

### Mathematical Proof

**Fisher Equation**:
```
(1 + nominal) = (1 + real) × (1 + inflation)

Example:
(1 + 0.12) = (1 + 0.0566) × (1 + 0.06)
1.12 ≈ 1.0566 × 1.06 ✓
```

**Correct approach**:
```
Real return = (1 + nominal) / (1 + inflation) - 1
Real return = (1.12) / (1.06) - 1 = 5.66%
```

### User Impact

**Scenario 1: User gives up**
```
App shows: "You need ₹4.8 crore, save ₹38,717/month"
User thinks: "That's impossible!"
Reality: Only need ₹25,530/month
Impact: User gives up on FIRE unnecessarily
```

**Scenario 2: User over-saves**
```
User saves: ₹38,717/month for 20 years
Reality: Only needed ₹25,530/month
Impact: Over-saved ₹31.6 lakh, could have retired earlier
```

**Scenario 3: User reaches ₹1.5 crore**
```
App shows: "You're only 31% there"
Reality: "You've achieved FIRE!"
Impact: User keeps working unnecessarily
```

### 🔴 Recommendation
**FIX IMMEDIATELY** - This is a critical bug affecting retirement planning

**Priority**: CRITICAL  
**Impact**: HIGH - 10-15% error in retirement planning  
**Effort**: 2-3 days

---

## 5. Goal Progress

### Location
`lib/features/goals/presentation/providers/goal_progress_provider.dart:149-173`

### Monthly Velocity Calculation

```dart
static double _calculateMonthlyVelocity(List<CashFlowEntity> cashFlows) {
  // Calculate months since first cash flow
  final monthsDiff = (now.difference(firstDate).inDays / 30.0).ceil();
  
  // Calculate net positive flow (returns + income)
  double netPositive = 0;
  for (final cf in cashFlows) {
    if (cf.type == CashFlowType.returnFlow || cf.type == CashFlowType.income) {
      netPositive += cf.amount;
    }
  }
  
  return netPositive / months;
}
```

### ⚠️ Issues

1. **Uses 30 days/month** (line 160)
   - Inaccurate: Some months have 28, 31 days
   - Error: Up to 10% in monthly calculations
   - Better: Use actual calendar months

2. **Includes returns in velocity** (line 166-168)
   - Misleading: User sees total growth, not just contributions
   - Example: ₹10k contribution + ₹2k returns = ₹12k "velocity"
   - Problem: User thinks they're saving ₹12k, but only ₹10k is controllable

3. **Variable naming**: `netPositive` is misleading
   - Actually: Total inflows (returns + income)
   - Better name: `totalInflows` or `totalReturnsAndIncome`

### 🟡 Recommendation
**FIX SOON** - Affects goal tracking accuracy

**Priority**: MEDIUM  
**Impact**: MEDIUM - Misleading velocity calculations  
**Effort**: 1 day

---

## 6. Portfolio Stats

### Location
`lib/features/investment/presentation/providers/investment_stats_provider.dart:300-318`

### Implementation
```dart
final totalInvested = FinancialCalculator.calculateTotalInvested(cashFlows);
final totalReturned = FinancialCalculator.calculateTotalReturned(cashFlows);
final netCashFlow = FinancialCalculator.calculateNetCashFlow(totalInvested, totalReturned);
final absoluteReturn = FinancialCalculator.calculateAbsoluteReturn(totalInvested, totalReturned);
final moic = FinancialCalculator.calculateMOIC(totalInvested, totalReturned);
final xirr = includeXirr ? FinancialCalculator.calculateXirrFromCashFlows(cashFlows) : 0.0;
```

### ✅ Strengths
- Centralized calculation
- Performance optimization (optional XIRR)
- Clean separation of concerns

### 🟢 Missing Features (Enhancement Opportunities)

1. **Asset Allocation**
   - Current: Only investment type breakdown
   - Missing: Equity/Debt/Gold allocation
   - Value: Standard feature in competitors

2. **Risk Metrics**
   - Current: Only return metrics
   - Missing: Volatility, Sharpe ratio, max drawdown
   - Value: Help users understand risk

3. **Tax-Adjusted Returns**
   - Current: Only pre-tax returns
   - Missing: Post-tax returns
   - Value: More realistic expectations

### 🟢 Recommendation
**ENHANCE LATER** - Nice-to-have features

**Priority**: LOW  
**Impact**: MEDIUM - Competitive features  
**Effort**: 2-3 weeks

---

## 7. Issues Summary

### 🔴 CRITICAL (Fix Immediately)

1. **FIRE Inflation Calculation**
   - Uses nominal returns instead of real returns
   - Impact: 3.2x overestimation, 34% higher savings
   - File: `fire_calculation_service.dart:14-49`
   - Effort: 2-3 days

### 🟡 MEDIUM (Fix Soon)

2. **Goal Monthly Velocity**
   - Uses 30 days/month (inaccurate)
   - Includes returns in velocity (misleading)
   - File: `goal_progress_provider.dart:149-173`
   - Effort: 1 day

3. **Variable Naming**
   - Confusing names in FIRE calculation
   - Misleading `netPositive` in goal progress
   - Multiple files
   - Effort: 1 day

4. **Date Calculations**
   - Inconsistent day/month/year conversions
   - Hardcoded 30 days/month, 365 days/year
   - Multiple files
   - Effort: 1 day

### 🟢 MINOR (Optional)

5. **XIRR Day Count**
   - Uses 365.0 instead of 365.25
   - Impact: <0.1% in most cases
   - File: `xirr_solver.dart:20`
   - Effort: 5 minutes

6. **CAGR Not Used**
   - Function exists but not shown in UI
   - Impact: Missing user-friendly metric
   - Effort: 1 day

7. **Return Cap**
   - 1000% cap too high
   - Should be 500% with warning
   - File: `xirr_solver.dart:103`
   - Effort: 10 minutes

8. **Missing Validations**
   - No XIRR cash flow validation
   - No FIRE input validation
   - Multiple files
   - Effort: 1 day

---

## 8. Recommendations

### Phase 1: Critical Fixes (Week 1)
**Priority**: 🔴 CRITICAL

1. Fix FIRE inflation calculation
2. Add comprehensive FIRE tests
3. Update FIRE variable names

**Effort**: 3 days  
**Impact**: Prevents major financial planning errors

### Phase 2: Medium Priority (Week 2)
**Priority**: 🟡 MEDIUM

4. Fix goal monthly velocity calculation
5. Create centralized DateUtils class
6. Add input validations
7. Extract magic numbers to constants

**Effort**: 3 days  
**Impact**: Improves accuracy and code quality

### Phase 3: Enhancements (Month 2)
**Priority**: 🟢 LOW

8. Add CAGR to UI
9. Optionally change XIRR to 365.25
10. Add asset allocation feature
11. Add risk metrics
12. Add tax-adjusted returns

**Effort**: 2-3 weeks  
**Impact**: Competitive features, better UX

---

## Next Steps

1. **Review this document**
2. **Prioritize fixes**
3. **Create implementation plan**
4. **Start with Phase 1 (FIRE fix)**

---

**Document Status**: Ready for review  
**Last Updated**: 2026-02-03

