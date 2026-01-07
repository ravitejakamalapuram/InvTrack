# FIRE Number Feature - Knowledge Transfer Document

## Overview

The FIRE (Financial Independence, Retire Early) Number feature allows users to calculate their target retirement corpus and track progress towards financial independence. This feature is India-focused with defaults optimized for Indian investors (INR currency, 6% inflation, etc.).

## Architecture

```
lib/features/fire_number/
├── data/
│   ├── models/           # Firestore models
│   └── repositories/     # Data access layer
├── domain/
│   ├── entities/         # Core business entities
│   ├── repositories/     # Repository interfaces
│   └── services/         # Business logic
└── presentation/
    ├── extensions/       # UI helper extensions
    ├── providers/        # Riverpod state management
    ├── screens/          # UI screens
    └── widgets/          # Reusable UI components
```

## Core Entities

### 1. FireSettingsEntity
User's FIRE configuration with the following inputs:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| monthlyExpenses | double | ₹50,000 | Current monthly expenses |
| safeWithdrawalRate | double | 4.0% | Annual withdrawal rate (4% rule) |
| currentAge | int | - | User's current age |
| targetFireAge | int | +15 years | Target retirement age |
| lifeExpectancy | int | 85 | Expected lifespan |
| inflationRate | double | 6.0% | Annual inflation (India-specific) |
| preRetirementReturn | double | 12.0% | Expected returns before FIRE |
| postRetirementReturn | double | 8.0% | Expected returns after FIRE |
| healthcareBuffer | double | 20.0% | Additional corpus for healthcare |
| emergencyMonths | double | 6 | Months of emergency fund |
| fireType | FireType | regular | Type of FIRE (see below) |
| monthlyPassiveIncome | double | 0 | Rental, dividends, etc. |
| expectedPension | double | 0 | Expected pension income |

### 2. FireType Enum

| Type | Expense Multiplier | Description |
|------|-------------------|-------------|
| lean | 0.7x (70%) | Minimalist lifestyle - basic needs only |
| regular | 1.0x (100%) | Maintain current lifestyle |
| fat | 1.5x (150%) | Premium lifestyle with luxuries |
| coast | 1.0x | Stop saving, let compound growth work |
| barista | 1.0x | Partial independence + part-time work |

### 3. FireProgressStatus

| Status | Condition | Description |
|--------|-----------|-------------|
| notStarted | progress ≤ 0% | No investments yet |
| behind | progress < 25% | Significantly behind schedule |
| onTrack | 25% ≤ progress < 75% | Reasonable trajectory |
| ahead | progress ≥ 75% | Ahead of schedule |
| coasting | reached Coast FIRE | Can stop saving, growth will handle it |
| achieved | progress ≥ 100% | FIRE goal reached! |

---

## Calculation Logic

### Step 1: Inflation-Adjusted Expenses

```
Adjusted Monthly Expenses = Monthly Expenses × FireType.expenseMultiplier
Inflation Multiplier = (1 + inflationRate/100)^yearsToFire
Inflation-Adjusted Monthly Expenses = Adjusted Monthly Expenses × Inflation Multiplier
```

**Example:**
- Monthly Expenses: ₹50,000
- Fire Type: Regular (1.0x)
- Inflation Rate: 6%
- Years to FIRE: 15

```
Adjusted Monthly = ₹50,000 × 1.0 = ₹50,000
Inflation Multiplier = (1.06)^15 = 2.3966
Inflation-Adjusted Monthly = ₹50,000 × 2.3966 = ₹1,19,830
```

### Step 2: Core FIRE Number (25x Rule)

```
FIRE Multiplier = 100 / Safe Withdrawal Rate
Core Retirement Corpus = Inflation-Adjusted Annual Expenses × FIRE Multiplier
```

**Example:**
- SWR: 4% → Multiplier = 100/4 = 25x
- Inflation-Adjusted Annual = ₹1,19,830 × 12 = ₹14,37,960

```
Core Corpus = ₹14,37,960 × 25 = ₹3,59,49,000 (₹3.59 Cr)
```

### Step 3: Emergency Fund

```
Emergency Fund = Inflation-Adjusted Monthly Expenses × Emergency Months
```

**Example:**
```
Emergency Fund = ₹1,19,830 × 6 = ₹7,18,980
```

### Step 4: Healthcare Buffer

```
Healthcare Corpus = Core Retirement Corpus × (Healthcare Buffer % / 100)
```

**Example:**
```
Healthcare Corpus = ₹3,59,49,000 × 0.20 = ₹71,89,800
```

### Step 5: Total FIRE Number

```
Total FIRE = Core Corpus + Emergency Fund + Healthcare Corpus
```

**Example:**
```
Total FIRE = ₹3,59,49,000 + ₹7,18,980 + ₹71,89,800 = ₹4,38,57,780 (₹4.39 Cr)
```

### Step 6: Adjust for Passive Income

```
Annual Other Income = (Monthly Passive Income + Expected Pension) × 12
Adjusted FIRE = Total FIRE - (Annual Other Income × FIRE Multiplier)
```

**Example (with ₹10,000/month passive income):**
```
Annual Other Income = ₹10,000 × 12 = ₹1,20,000
Reduction = ₹1,20,000 × 25 = ₹30,00,000
Adjusted FIRE = ₹4,38,57,780 - ₹30,00,000 = ₹4,08,57,780 (₹4.09 Cr)
```

---

## Advanced Calculations

### Coast FIRE Number
The amount needed today that will grow to your FIRE number by retirement (no additional savings needed).

```
Coast FIRE = FIRE Number / (1 + returnRate/100)^yearsToFire
```

**Example:**
- FIRE Number: ₹4.09 Cr
- Pre-retirement Return: 12%
- Years: 15

```
Coast FIRE = ₹4,08,57,780 / (1.12)^15 = ₹4,08,57,780 / 5.4736 = ₹74,65,000 (₹74.65 L)
```

**Interpretation:** If you have ₹74.65L today, you can "coast" - stop aggressive saving and let compound growth reach your FIRE number.

### Barista FIRE Number
50% of your full FIRE number - allows part-time work to cover half your expenses.

```
Barista FIRE = FIRE Number × 0.5
```

**Example:**
```
Barista FIRE = ₹4,08,57,780 × 0.5 = ₹2,04,28,890 (₹2.04 Cr)
```

### Required Monthly Savings
Uses the PMT (Payment) formula to calculate required monthly investment.

```
Future Value of Current = Current Portfolio × (1 + monthlyRate)^months
Amount Needed = FIRE Number - Future Value of Current
Required Monthly = Amount Needed × monthlyRate / ((1 + monthlyRate)^months - 1)
```

**Example:**
- FIRE Number: ₹4.09 Cr
- Current Portfolio: ₹50 L
- Annual Return: 12% (1% monthly)
- Years: 15 (180 months)

```
FV of Current = ₹50,00,000 × (1.01)^180 = ₹50,00,000 × 5.996 = ₹2,99,80,000
Amount Needed = ₹4,08,57,780 - ₹2,99,80,000 = ₹1,08,77,780
Required Monthly = ₹1,08,77,780 × 0.01 / ((1.01)^180 - 1)
                 = ₹1,08,778 / 4.996
                 = ₹21,773/month
```

### Projected FIRE Age
Iteratively calculates when portfolio will reach FIRE number based on current savings rate.

```
Algorithm:
1. Start with current portfolio
2. Each month: balance = balance × (1 + monthlyRate) + monthlySavings
3. Count months until balance >= FIRE number
4. Projected Age = Current Age + (months / 12)
```

---

## Progress Status Logic

```dart
if (progressPercentage >= 100) → achieved
if (currentValue >= coastNumber) → coasting
if (progressPercentage <= 0) → notStarted
if (progressPercentage >= 75) → ahead
if (progressPercentage >= 25) → onTrack
else → behind
```

---

## Milestones

| Milestone | Percentage | Label |
|-----------|------------|-------|
| percent10 | 10% | Getting Started |
| percent25 | 25% | Quarter Way |
| percent50 | 50% | Halfway There |
| percent75 | 75% | Final Stretch |
| percent100 | 100% | FIRE Achieved! |

---

## Complete Calculation Example

### Input Parameters
| Parameter | Value |
|-----------|-------|
| Monthly Expenses | ₹75,000 |
| Fire Type | Regular |
| Current Age | 35 |
| Target FIRE Age | 50 |
| SWR | 4% |
| Inflation | 6% |
| Pre-retirement Return | 12% |
| Healthcare Buffer | 20% |
| Emergency Months | 6 |
| Monthly Passive Income | ₹15,000 |
| Current Portfolio | ₹1.5 Cr |
| Current Monthly Investment | ₹50,000 |

### Calculations

**Step 1: Inflation-Adjusted Expenses**
```
Years to FIRE = 50 - 35 = 15 years
Inflation Multiplier = (1.06)^15 = 2.3966
Monthly at Retirement = ₹75,000 × 2.3966 = ₹1,79,745
Annual at Retirement = ₹1,79,745 × 12 = ₹21,56,940
```

**Step 2: Core FIRE Number**
```
FIRE Multiplier = 100 / 4 = 25
Core Corpus = ₹21,56,940 × 25 = ₹5,39,23,500
```

**Step 3: Emergency Fund**
```
Emergency = ₹1,79,745 × 6 = ₹10,78,470
```

**Step 4: Healthcare Buffer**
```
Healthcare = ₹5,39,23,500 × 0.20 = ₹1,07,84,700
```

**Step 5: Total Before Adjustments**
```
Total = ₹5,39,23,500 + ₹10,78,470 + ₹1,07,84,700 = ₹6,57,86,670
```

**Step 6: Adjust for Passive Income**
```
Annual Passive = ₹15,000 × 12 = ₹1,80,000
Reduction = ₹1,80,000 × 25 = ₹45,00,000
Final FIRE Number = ₹6,57,86,670 - ₹45,00,000 = ₹6,12,86,670 (₹6.13 Cr)
```

**Step 7: Coast FIRE**
```
Coast FIRE = ₹6,12,86,670 / (1.12)^15 = ₹1,11,97,000 (₹1.12 Cr)
```

**Step 8: Barista FIRE**
```
Barista FIRE = ₹6,12,86,670 × 0.5 = ₹3,06,43,335 (₹3.06 Cr)
```

**Step 9: Progress**
```
Progress = (₹1,50,00,000 / ₹6,12,86,670) × 100 = 24.5%
Status = Behind (< 25%)
```

**Step 10: Required Monthly Investment**
```
FV of Current = ₹1,50,00,000 × (1.01)^180 = ₹8,99,40,000
Amount Needed = ₹6,12,86,670 - ₹8,99,40,000 = -₹2,86,53,330
Required Monthly = ₹0 (current growth exceeds target!)
```

**Step 11: Projected FIRE Age**
With ₹50,000/month savings and 12% returns:
- Starting: ₹1.5 Cr
- After iterative calculation: ~47 years old (3 years early!)

---

## User Experience (UX)

### Screens

1. **FIRE Setup Wizard** (`fire_setup_screen.dart`)
   - 4-step onboarding wizard
   - Step 1: Basic Info (age, expenses)
   - Step 2: FIRE Type selection
   - Step 3: Advanced settings (SWR, inflation)
   - Step 4: Review & confirm

2. **FIRE Dashboard** (`fire_dashboard_screen.dart`)
   - Hero card with progress ring
   - FIRE number display
   - Status badge (Behind/On Track/Ahead/Coasting/Achieved)
   - Gap analysis section
   - Next milestone card
   - Breakdown cards (Core/Emergency/Healthcare)

### Widgets

- `FireDashboardCard` - Summary card for profile screen
- `FireStatsCard` - Individual stat display with comparison
- `FireProgressRing` - Circular progress indicator

### Navigation

- Access from Profile tab → "FIRE Dashboard"
- First-time users see Setup Wizard
- Returning users see Dashboard directly

---

## Data Persistence

- **Firestore Collection:** `users/{userId}/fire_settings`
- **Local Cache:** Riverpod state with Firestore sync
- **Delete Account:** FIRE settings are deleted with user data

---

## Testing

- Unit tests: `test/features/fire_number/`
- Domain tests: Calculation service, entity validation
- Repository tests: Fake repository for CRUD operations
- UI extension tests: Color and icon mappings

---

## Future Enhancements

1. **What-If Scenarios** - Adjust parameters and see impact
2. **Historical Tracking** - Track progress over time
3. **Projections Chart** - Visual chart of growth trajectory
4. **Multiple FIRE Goals** - Support for multiple scenarios
5. **Export/Import** - Include in data export/import

