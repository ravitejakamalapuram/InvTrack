# FIRE Calculation Fix - Implementation Guide

**Issue**: FIRE calculation uses nominal returns instead of real returns
**Impact**: 3.2x overestimation of FIRE number, 34% higher required savings
**Priority**: 🔴 CRITICAL
**File**: `lib/features/fire_number/domain/services/fire_calculation_service.dart`

---

## The Problem Explained

### Current Logic (WRONG)

```dart
// Step 1: Inflate expenses to retirement year
inflationMultiplier = (1.06)^20 = 3.207
futureExpenses = ₹50,000 × 3.207 = ₹1,60,357/month

// Step 2: Calculate FIRE number based on future expenses
fireNumber = ₹1,60,357 × 12 × 25 = ₹4,81,07,100

// Step 3: Calculate savings needed using NOMINAL returns (12%)
requiredSavings = calculateWithNominalReturn(12%)
```

### Why This Is Wrong

**The fundamental error**: Mixing inflated target with nominal returns

**What this assumes**:
1. Your expenses stay at ₹50,000 for 20 years
2. Then suddenly jump to ₹1,60,357 at retirement
3. Your investments grow at 12% nominal

**Reality**:
1. Expenses inflate EVERY year (not just at retirement)
2. Investment returns are also affected by inflation
3. What matters is REAL purchasing power, not nominal amounts

---

## The Correct Approach

### Option 1: Real Returns (RECOMMENDED)

**Concept**: Work in today's money, use real returns

```dart
// Step 1: Calculate FIRE number in TODAY'S money (no inflation)
currentAnnualExpenses = ₹50,000 × 12 = ₹6,00,000
fireNumber = ₹6,00,000 × 25 = ₹1,50,00,000

// Step 2: Calculate REAL return
realReturn = nominalReturn - inflation
realReturn = 12% - 6% = 6%

// Step 3: Calculate savings using REAL returns
requiredSavings = calculateWithRealReturn(6%)
```

**Result**:
- FIRE number: ₹1.5 crore (in today's money)
- Required savings: ₹25,530/month
- At retirement: This ₹1.5cr will have same purchasing power as today

### Option 2: Inflate Everything (Alternative)

**Concept**: Inflate both target and current value

```dart
// Step 1: Inflate target (as current code does)
futureFireNumber = ₹4,81,07,100

// Step 2: Also inflate current portfolio value
inflatedCurrentValue = ₹10,00,000 × (1.06)^20 = ₹32,07,135

// Step 3: Calculate gap in future money
gap = ₹4,81,07,100 - ₹32,07,135 = ₹4,48,99,965

// Step 4: Use REAL returns to calculate savings
requiredSavings = calculateWithRealReturn(6%)
```

**Result**: Same as Option 1 (mathematically equivalent)

---

## Mathematical Proof

### Fisher Equation

```
(1 + nominal) = (1 + real) × (1 + inflation)

Example:
(1 + 0.12) = (1 + 0.06) × (1 + 0.0566)
1.12 ≈ 1.06 × 1.0566 ✓
```

### Future Value Equivalence

**With Inflation Adjustment**:
```
FV = PV × (1 + nominal)^n
FV = ₹10L × (1.12)^20 = ₹96.46L
```

**With Real Returns**:
```
FV_real = PV × (1 + real)^n
FV_real = ₹10L × (1.06)^20 = ₹32.07L

But this ₹32.07L in future has same purchasing power as:
₹32.07L / (1.06)^20 = ₹10L today ✓
```

---

## Real-World Example

### Scenario
- **Current age**: 30
- **Target FIRE age**: 50 (20 years)
- **Current expenses**: ₹50,000/month
- **Current portfolio**: ₹10,00,000
- **Inflation**: 6%
- **Expected return**: 12%
- **FIRE multiplier**: 25x

### Current Calculation (WRONG)

```
Future expenses = ₹50,000 × (1.06)^20 = ₹1,60,357/month
FIRE number = ₹1,60,357 × 12 × 25 = ₹4,81,07,100

FV of current = ₹10,00,000 × (1.12)^20 = ₹96,46,293
Gap = ₹4,81,07,100 - ₹96,46,293 = ₹3,84,60,807

Monthly savings = ₹3,84,60,807 × 0.01 / ((1.01)^240 - 1)
                = ₹38,717/month
```

### Correct Calculation

```
FIRE number (today's money) = ₹50,000 × 12 × 25 = ₹1,50,00,000

FV of current (real) = ₹10,00,000 × (1.06)^20 = ₹32,07,135
Gap = ₹1,50,00,000 - ₹32,07,135 = ₹1,17,92,865

Monthly savings = ₹1,17,92,865 × 0.005 / ((1.005)^240 - 1)
                = ₹25,530/month
```

### Comparison

| Metric | Current (Wrong) | Correct | Difference |
|--------|----------------|---------|------------|
| FIRE Number | ₹4.81 cr | ₹1.50 cr | **3.2x too high** |
| Required Savings | ₹38,717/mo | ₹25,530/mo | **34% too high** |
| Interpretation | "I need ₹4.8cr" | "I need ₹1.5cr in today's money" | Huge difference! |

---

## User Impact

### Scenario 1: User Gives Up

```
User sees: "You need ₹4.8 crore, save ₹38,717/month"
User thinks: "That's impossible, I can't save that much"
Reality: They only need ₹25,530/month
Impact: User gives up on FIRE unnecessarily
```

### Scenario 2: User Over-Saves

```
User follows app: Saves ₹38,717/month for 20 years
Reality: Only needed ₹25,530/month
Impact: User over-saved ₹13,187/month × 240 months = ₹31.6 lakh
        Could have retired earlier or enjoyed life more
```

### Scenario 3: User Reaches ₹1.5 Crore

```
App shows: "You're only 31% there (₹1.5cr / ₹4.8cr)"
Reality: "You've achieved FIRE!"
Impact: User keeps working unnecessarily
```

---

## The Fix

### Code Changes Required

**File**: `lib/features/fire_number/domain/services/fire_calculation_service.dart`

### Change 1: Calculate Real Return

```dart
// Add this helper method
double _calculateRealReturn(double nominalReturn, double inflationRate) {
  // Fisher equation: (1 + nominal) = (1 + real) × (1 + inflation)
  // Solving for real: real = (1 + nominal) / (1 + inflation) - 1
  final nominal = nominalReturn / 100;
  final inflation = inflationRate / 100;
  final real = (1 + nominal) / (1 + inflation) - 1;
  return real * 100; // Convert back to percentage
}
```

### Change 2: Use Today's Money for FIRE Number

```dart
// BEFORE (lines 14-29)
final adjustedMonthlyExpenses = settings.monthlyExpenses * settings.fireType.expenseMultiplier;
final inflationMultiplier = math.pow(1 + settings.inflationRate / 100, yearsToFire);
final inflationAdjustedMonthlyExpenses = adjustedMonthlyExpenses * inflationMultiplier;
final inflationAdjustedAnnualExpenses = inflationAdjustedMonthlyExpenses * 12;
final coreRetirementCorpus = inflationAdjustedAnnualExpenses * settings.fireMultiplier;

// AFTER
final fireTypeAdjustedExpenses = settings.monthlyExpenses * settings.fireType.expenseMultiplier;
final currentAnnualExpenses = fireTypeAdjustedExpenses * 12;
final coreRetirementCorpus = currentAnnualExpenses * settings.fireMultiplier;

// Note: We keep expenses in TODAY'S money, not inflated
```

### Change 3: Use Real Returns for Calculations

```dart
// Calculate real return
final realReturn = _calculateRealReturn(
  settings.preRetirementReturn,
  settings.inflationRate,
);

// Use real return for all projections
final requiredMonthlySavings = _calculateRequiredMonthlySavings(
  targetAmount: finalFireNumber,
  currentAmount: currentPortfolioValue,
  years: yearsToFire,
  annualReturn: realReturn, // Use real return, not nominal
);

final coastFireNumber = _calculateCoastFireNumber(
  targetAmount: finalFireNumber,
  yearsToGrow: yearsToFire,
  returnRate: realReturn, // Use real return
);

final projectedFireAge = _calculateProjectedFireAge(
  targetAmount: finalFireNumber,
  currentAmount: currentPortfolioValue,
  monthlySavings: currentMonthlySavings,
  annualReturn: realReturn, // Use real return
  currentAge: settings.currentAge,
);
```

### Change 4: Update Emergency Fund and Healthcare

```dart
// Emergency fund should also be in today's money
final emergencyFundNeeded = fireTypeAdjustedExpenses * settings.emergencyMonths;

// Healthcare buffer as percentage of core corpus
final healthcareCorpusNeeded = coreRetirementCorpus * (settings.healthcareBuffer / 100);
```

### Change 5: Update UI Display

The UI should clearly communicate:
```
FIRE Number: ₹1,50,00,000 (in today's money)

At retirement (age 50), this will be equivalent to:
₹4,81,07,100 in future money

But you only need to save for ₹1.5 crore because:
- Your investments grow at 12% nominal
- Inflation is 6%
- Real growth is 6%
```

---

## Testing the Fix

### Test Case 1: Basic FIRE

```dart
test('FIRE calculation uses real returns', () {
  final settings = FireSettingsEntity(
    monthlyExpenses: 50000,
    currentAge: 30,
    targetFireAge: 50,
    inflationRate: 6,
    preRetirementReturn: 12,
    fireMultiplier: 25,
  );
  
  final result = FireCalculationService().calculate(
    settings: settings,
    currentPortfolioValue: 1000000,
    currentMonthlySavings: 25000,
  );
  
  // FIRE number should be in today's money
  expect(result.fireNumber, closeTo(15000000, 100000)); // ₹1.5cr ± 1L
  
  // Required savings should use real returns
  expect(result.requiredMonthlySavings, closeTo(25530, 1000)); // ~₹25.5k
});
```

### Test Case 2: High Inflation

```dart
test('FIRE calculation handles high inflation', () {
  final settings = FireSettingsEntity(
    monthlyExpenses: 50000,
    inflationRate: 10, // High inflation
    preRetirementReturn: 12,
    fireMultiplier: 25,
  );
  
  final realReturn = (1.12 / 1.10) - 1; // ~1.8%
  
  // With low real return, savings should be much higher
  // This is correct - high inflation means you need to save more
});
```

---

## Migration Strategy

### For Existing Users

**Problem**: Users already have FIRE numbers calculated with old logic

**Solution**: Recalculate on next app open

```dart
// Add version field to FireSettingsEntity
class FireSettingsEntity {
  final int calculationVersion; // Add this
  
  // Current version uses real returns
  static const int currentCalculationVersion = 2;
}

// On app open, check version
if (settings.calculationVersion < FireSettingsEntity.currentCalculationVersion) {
  // Recalculate with new logic
  // Show user a message explaining the change
}
```

### User Communication

Show a one-time message:
```
📊 FIRE Calculation Update

We've improved our FIRE number calculation to be more accurate!

Your new FIRE number: ₹1,50,00,000 (in today's money)
Previous estimate: ₹4,81,07,100

Don't worry! The new number is more realistic. At retirement,
₹1.5 crore will have the same purchasing power as ₹4.8 crore
in future money.

Your required monthly savings: ₹25,530 (down from ₹38,717)

This means you can achieve FIRE sooner! 🎉
```

---

## Summary

### The Bug
- Uses nominal returns with inflated target
- Causes 3.2x overestimation of FIRE number
- Leads to 34% higher required savings

### The Fix
- Use real returns (nominal - inflation)
- Keep FIRE number in today's money
- Mathematically correct and user-friendly

### Impact
- More realistic FIRE goals
- Lower required savings
- Better user experience
- Prevents discouragement

---

**Ready to implement?** This fix is critical for accurate retirement planning!

