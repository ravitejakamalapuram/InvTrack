# FIRE Number Feature - Comprehensive Implementation Plan

> **Version**: 1.0 | **Created**: 2026-01-06
> **Vision**: "Your Personal Financial Independence GPS"

---

## Executive Summary

FIRE (Financial Independence, Retire Early) Number is the total investment corpus needed to sustain your lifestyle indefinitely without active income. Unlike regular goals, the FIRE Number is a **special default goal** that:
- Is automatically created for every user
- Cannot be deleted (but can be archived)
- Tracks ALL investments by default
- Provides a holistic view of Financial Independence progress

---

## 1. Deep Dive: What is FIRE?

### 1.1 The FIRE Movement

FIRE stands for **Financial Independence, Retire Early**. It's a financial strategy focused on:
- **Extreme savings**: Saving 50-70% of income (vs traditional 10-20%)
- **Aggressive investing**: Maximizing returns through strategic asset allocation
- **Frugal living**: Minimizing lifestyle expenses
- **Early exit**: Retiring decades before traditional retirement age (65)

### 1.2 The FIRE Number Defined

> **FIRE Number** = The total investment corpus that can generate enough passive income to cover your annual expenses indefinitely.

**Core Formula:**
```
FIRE Number = Annual Expenses × (1 / Safe Withdrawal Rate)
FIRE Number = Annual Expenses × 25  (for 4% SWR)
```

### 1.3 The 4% Rule (Trinity Study)

The foundation of FIRE calculations:
- **Origin**: 1998 Trinity Study by three professors at Trinity University
- **Premise**: Withdraw 4% of portfolio in year 1, then adjust for inflation annually
- **Success Rate**: 95% probability of portfolio lasting 30 years
- **Portfolio**: 50-75% stocks, 25-50% bonds

**Safe Withdrawal Rate (SWR) Options:**
| SWR | Multiplier | Risk Level | Horizon |
|-----|------------|------------|---------|
| 4.0% | 25x | Standard | 30 years |
| 3.5% | 28.6x | Conservative | 40+ years |
| 3.0% | 33.3x | Very Safe | 50+ years |
| 2.5% | 40x | Ultra Conservative | 60+ years |

---

## 2. FIRE Variations (Types)

### 2.1 Lean FIRE
- **Definition**: Minimum viable financial independence
- **Target Expenses**: Basic needs only (no luxuries)
- **Typical Range**: ₹3-6 lakh/year (India)
- **FIRE Number**: ₹75L - ₹1.5Cr (at 4% SWR)
- **Lifestyle**: Frugal, minimalist

### 2.2 Regular/Traditional FIRE
- **Definition**: Comfortable independence matching current lifestyle
- **Target Expenses**: Current expenses maintained
- **Typical Range**: ₹6-15 lakh/year (India)
- **FIRE Number**: ₹1.5Cr - ₹3.75Cr (at 4% SWR)
- **Lifestyle**: Comfortable, moderate

### 2.3 Fat FIRE
- **Definition**: Luxurious financial independence
- **Target Expenses**: Above current, with premium lifestyle
- **Typical Range**: ₹15-50+ lakh/year (India)
- **FIRE Number**: ₹3.75Cr - ₹12.5Cr+ (at 4% SWR)
- **Lifestyle**: Premium, travel, luxury

### 2.4 Coast FIRE
- **Definition**: Enough invested that compound growth handles retirement
- **Premise**: Stop aggressive saving, let investments grow to target by traditional retirement
- **Work**: Can take lower-paying passion jobs
- **Key Metric**: Coast Number (current investments that will grow to FIRE Number by retirement age)

### 2.5 Barista FIRE
- **Definition**: Partial financial independence + part-time work
- **Strategy**: Investments cover most expenses; part-time work covers the gap
- **Common Use**: Health insurance coverage in US
- **India Relevance**: Lower healthcare costs make this less necessary

---

## 3. FIRE Number Calculation Factors

### 3.1 Core Inputs (Required)

| Factor | Description | Default | Range |
|--------|-------------|---------|-------|
| **Monthly Expenses** | Current monthly spending | User input | ₹10K - ₹10L |
| **Annual Expenses** | Monthly × 12 | Calculated | - |
| **Safe Withdrawal Rate** | Portfolio withdrawal % | 4% | 2.5% - 5% |
| **Current Age** | User's current age | User input | 18 - 70 |
| **FIRE Age (Target)** | Desired retirement age | 45 | 30 - 65 |

### 3.2 Advanced Factors (Optional but Important)

| Factor | Description | Default | Impact |
|--------|-------------|---------|--------|
| **Inflation Rate** | Annual expense increase | 6% (India) | High |
| **Expected Return** | Pre-retirement investment return | 12% | High |
| **Post-Retirement Return** | Conservative post-FIRE return | 8% | Medium |
| **Life Expectancy** | Expected lifespan | 85 years | Medium |
| **Healthcare Buffer** | Additional healthcare costs | 20% of expenses | Medium |
| **Emergency Buffer** | One-time expense buffer | 6 months | Low |

### 3.3 India-Specific Considerations

| Factor | Description | Typical Value |
|--------|-------------|---------------|
| **Inflation** | Higher than developed markets | 5-7% |
| **Healthcare Costs** | Rising rapidly | 10-15% annual increase |
| **No Social Security** | Limited government support | Factor in 100% self-funding |
| **Real Estate** | Often a large asset but illiquid | Consider rental income only |
| **Gold** | Cultural significance | Include in corpus |
| **Family Support** | Joint family dynamics | May reduce expenses |

---

## 4. FIRE Number Formulas

### 4.1 Basic FIRE Number (Static)

```
FIRE Number = Annual Expenses × (100 / SWR)

Example:
- Monthly Expenses: ₹50,000
- Annual Expenses: ₹6,00,000
- SWR: 4%
- FIRE Number: ₹6,00,000 × 25 = ₹1.5 Crore
```

### 4.2 Inflation-Adjusted FIRE Number

```
Inflation-Adjusted FIRE = Current Annual Expenses × (1 + inflation)^years_to_FIRE × (100 / SWR)

Example:
- Current Annual Expenses: ₹6,00,000
- Years to FIRE: 15
- Inflation: 6%
- SWR: 4%
- Future Annual Expenses: ₹6,00,000 × (1.06)^15 = ₹14,37,894
- FIRE Number: ₹14,37,894 × 25 = ₹3.59 Crore
```

### 4.3 Years to FIRE Calculation

```
Years to FIRE = ln((FIRE_Number × r + Annual_Savings) / (Current_Portfolio × r + Annual_Savings)) / ln(1 + r)

Where r = expected return rate
```

### 4.4 Coast FIRE Number

```
Coast FIRE = FIRE_Number / (1 + return_rate)^years_to_traditional_retirement

Example:
- FIRE Number at 60: ₹3 Crore
- Current Age: 35
- Years to 60: 25
- Expected Return: 10%
- Coast FIRE: ₹3,00,00,000 / (1.10)^25 = ₹27.68 Lakh
```

---

## 5. Data Model

### 5.1 FireNumberSettings Entity

```dart
class FireNumberSettings {
  // Core Inputs
  double monthlyExpenses;           // User's monthly spending
  double safeWithdrawalRate;        // Default: 4.0 (as percentage)
  int currentAge;                   // User's current age
  int targetFireAge;                // Target FIRE age
  int lifeExpectancy;               // Default: 85
  
  // Advanced Inputs
  double inflationRate;             // Default: 6.0 (India)
  double preRetirementReturn;       // Default: 12.0
  double postRetirementReturn;      // Default: 8.0
  double healthcareBuffer;          // Default: 20.0 (percentage)
  double emergencyMonths;           // Default: 6
  
  // FIRE Type Selection
  FireType fireType;                // lean, regular, fat, coast, barista
  
  // Customization
  bool includeRealEstate;           // Include property in corpus?
  bool includeGold;                 // Include gold in corpus?
  double monthlyPassiveIncome;      // Rental, dividends, etc.
  double expectedPension;           // If any pension expected
  
  // Metadata
  DateTime createdAt;
  DateTime updatedAt;
}
```

### 5.2 FireNumberProgress (Calculated)

```dart
class FireNumberProgress {
  // Core Numbers
  double basicFireNumber;           // Without inflation
  double inflationAdjustedFireNumber; // With inflation to FIRE age
  double currentPortfolioValue;     // From linked investments
  double progressPercent;           // 0-100
  
  // Time Projections
  int yearsToFire;                  // Based on current velocity
  DateTime projectedFireDate;       // When FIRE will be achieved
  int targetYearsRemaining;         // Years to target FIRE age
  
  // Velocity Metrics
  double monthlyVelocity;           // Average monthly addition
  double requiredMonthlyVelocity;   // To hit target on time
  double velocityGap;               // Difference (positive = ahead)
  
  // Coast FIRE
  double coastFireNumber;           // Amount needed to coast
  bool isCoastFireAchieved;         // Can stop aggressive saving?
  
  // Status
  FireProgressStatus status;        // onTrack, ahead, behind, achieved
  List<FireMilestone> milestones;   // 10%, 25%, 50%, 75%, 100%
  
  // Breakdown
  double principalContribution;     // Total invested amount
  double projectedGrowth;           // Compound growth expected
}
```

### 5.3 Enums

```dart
enum FireType {
  lean,      // Minimal lifestyle
  regular,   // Current lifestyle
  fat,       // Premium lifestyle
  coast,     // Coast FIRE
  barista,   // Partial FIRE
}

enum FireProgressStatus {
  notStarted,   // No investments yet
  behind,       // Behind schedule
  onTrack,      // Within 10% of target pace
  ahead,        // More than 10% ahead
  achieved,     // 100%+ reached
  coasting,     // Coast FIRE achieved
}

enum FireMilestoneType {
  percent10,    // 10% - Getting started
  percent25,    // 25% - Quarter way
  percent50,    // 50% - Halfway
  percent75,    // 75% - Final stretch
  percent100,   // 100% - FIRE achieved!
  coastAchieved,// Coast FIRE reached
}
```

---

## 6. Feature Specifications

### 6.1 Default Behavior

| Aspect | Specification |
|--------|---------------|
| **Creation** | Auto-created on first app open (after onboarding) |
| **Deletion** | Cannot be deleted, only archived |
| **Tracking Mode** | Always tracks ALL investments |
| **Visibility** | Prominent placement on Dashboard |
| **Goal Type** | Special type: `fireNumber` (not regular goal) |

### 6.2 User Onboarding Flow

1. **First Time Setup** (after sign-in):
   - "Let's calculate your FIRE Number!"
   - Step 1: Monthly expenses input
   - Step 2: Current age & Target FIRE age
   - Step 3: FIRE type selection (lean/regular/fat)
   - Step 4: Advanced settings (optional, collapsible)
   - "Your FIRE Number: ₹X Crore" - Reveal with animation

2. **Skip Option**:
   - Can skip setup, uses sensible defaults
   - Prompt to complete setup periodically

### 6.3 Dashboard Integration

**FIRE Number Card (Prominent)**:
```
┌─────────────────────────────────────────────────┐
│  🔥 Your FIRE Number                    [Edit]  │
│                                                 │
│  ₹3.59 Cr                                       │
│  ━━━━━━━━━━━━━━━━━━○─────────  42%              │
│                                                 │
│  Current: ₹1.51 Cr    Target: ₹3.59 Cr         │
│                                                 │
│  🎯 On track for FIRE by 2038 (Age 47)         │
│  📈 +₹2.1L this month                          │
│                                                 │
│  [Coast FIRE: ✅ Achieved!]                     │
└─────────────────────────────────────────────────┘
```

### 6.4 FIRE Detail Screen

Sections:
1. **Progress Overview** - Large progress ring with milestone markers
2. **Key Numbers** - FIRE Number, Current Value, Gap
3. **Projections** - Years to FIRE, Projected Date
4. **Velocity Analysis** - Monthly pace vs required pace
5. **FIRE Type** - Current selection with ability to switch
6. **Coast FIRE Status** - If achieved, celebration!
7. **What-If Scenarios** - Adjust expenses/return to see impact
8. **Linked Investments** - All investments contributing
9. **Settings** - Edit all parameters

---

## 7. Calculation Engine

### 7.1 Core Calculations

```dart
class FireCalculationService {
  
  FireNumberProgress calculateProgress({
    required FireNumberSettings settings,
    required List<InvestmentEntity> investments,
  }) {
    // 1. Calculate Annual Expenses
    final annualExpenses = settings.monthlyExpenses * 12;
    
    // 2. Calculate years to FIRE age
    final yearsToFire = settings.targetFireAge - settings.currentAge;
    
    // 3. Calculate inflation-adjusted expenses at FIRE
    final futureAnnualExpenses = annualExpenses * 
        pow(1 + settings.inflationRate / 100, yearsToFire);
    
    // 4. Add healthcare buffer
    final totalFutureExpenses = futureAnnualExpenses * 
        (1 + settings.healthcareBuffer / 100);
    
    // 5. Calculate FIRE Number
    final fireNumber = totalFutureExpenses * 
        (100 / settings.safeWithdrawalRate);
    
    // 6. Add emergency buffer
    final fireNumberWithBuffer = fireNumber + 
        (totalFutureExpenses / 12 * settings.emergencyMonths);
    
    // 7. Calculate current portfolio value
    final currentValue = _calculatePortfolioValue(investments);
    
    // 8. Calculate progress
    final progress = (currentValue / fireNumberWithBuffer) * 100;
    
    // 9. Calculate velocity and projections
    final monthlyVelocity = _calculateMonthlyVelocity(investments);
    final projectedDate = _projectFireDate(
      currentValue, 
      fireNumberWithBuffer, 
      monthlyVelocity,
      settings.preRetirementReturn,
    );
    
    // 10. Calculate Coast FIRE
    final coastNumber = _calculateCoastFire(
      fireNumberWithBuffer,
      65 - settings.currentAge, // years to traditional retirement
      settings.preRetirementReturn,
    );
    
    return FireNumberProgress(
      basicFireNumber: annualExpenses * (100 / settings.safeWithdrawalRate),
      inflationAdjustedFireNumber: fireNumberWithBuffer,
      currentPortfolioValue: currentValue,
      progressPercent: progress.clamp(0, 200), // Allow over 100%
      yearsToFire: _calculateYearsToFire(currentValue, fireNumberWithBuffer, ...),
      projectedFireDate: projectedDate,
      coastFireNumber: coastNumber,
      isCoastFireAchieved: currentValue >= coastNumber,
      status: _determineStatus(progress, ...),
      milestones: _generateMilestones(progress),
    );
  }
}
```

---

## 8. Notifications

### 8.1 FIRE-Specific Notifications

| Notification | Trigger | Message Example |
|--------------|---------|-----------------|
| **Milestone** | 10/25/50/75/100% reached | "🔥 You're 25% to FIRE! ₹90L of ₹3.6Cr" |
| **Coast FIRE** | Coast number achieved | "🏖️ Coast FIRE Achieved! You can relax your savings rate" |
| **Behind Schedule** | >20% behind projection | "⚠️ Your FIRE journey is behind. Consider increasing savings." |
| **FIRE Achieved** | 100% reached | "🎉 Congratulations! You've achieved Financial Independence!" |
| **Annual Review** | Yearly on signup anniversary | "📊 FIRE Annual Review: You grew 18% this year!" |
| **Expense Check** | Quarterly | "💰 Time to review: Are your expenses still ₹50K/month?" |

---

## 9. Architecture

### 9.1 Folder Structure

```
lib/features/fire_number/
├── data/
│   ├── models/
│   │   └── fire_settings_model.dart
│   └── repositories/
│       └── fire_settings_repository_impl.dart
├── domain/
│   ├── entities/
│   │   ├── fire_settings_entity.dart
│   │   └── fire_progress_entity.dart
│   ├── repositories/
│   │   └── fire_settings_repository.dart
│   └── services/
│       └── fire_calculation_service.dart
└── presentation/
    ├── providers/
    │   ├── fire_settings_provider.dart
    │   └── fire_progress_provider.dart
    ├── screens/
    │   ├── fire_setup_screen.dart
    │   ├── fire_detail_screen.dart
    │   └── fire_settings_screen.dart
    └── widgets/
        ├── fire_dashboard_card.dart
        ├── fire_progress_ring.dart
        ├── fire_milestone_indicator.dart
        ├── fire_projection_chart.dart
        └── fire_type_selector.dart
```

### 9.2 Firestore Structure

```
users/{userId}/fireSettings (single document)
  - monthlyExpenses: number
  - safeWithdrawalRate: number
  - currentAge: number
  - targetFireAge: number
  - lifeExpectancy: number
  - inflationRate: number
  - preRetirementReturn: number
  - postRetirementReturn: number
  - healthcareBuffer: number
  - emergencyMonths: number
  - fireType: string
  - includeRealEstate: boolean
  - includeGold: boolean
  - monthlyPassiveIncome: number
  - expectedPension: number
  - isArchived: boolean
  - createdAt: timestamp
  - updatedAt: timestamp
```

---

## 10. Implementation Phases

### Phase 1: Core Infrastructure (3 days)
- [ ] FireNumberSettings entity & model
- [ ] FireNumberProgress entity
- [ ] FireSettingsRepository
- [ ] Firestore persistence
- [ ] Basic Riverpod providers

### Phase 2: Calculation Engine (2 days)
- [ ] FireCalculationService
- [ ] Basic FIRE number calculation
- [ ] Inflation adjustment
- [ ] Coast FIRE calculation
- [ ] Velocity projections

### Phase 3: Setup Flow (2 days)
- [ ] FIRE setup wizard screen
- [ ] Expense input with suggestions
- [ ] FIRE type selector
- [ ] Advanced settings (collapsible)
- [ ] Skip/Later functionality

### Phase 4: Dashboard Integration (2 days)
- [ ] FIRE dashboard card widget
- [ ] Progress ring with milestones
- [ ] Quick stats display
- [ ] Link to detail screen

### Phase 5: Detail Screen (2 days)
- [ ] Full FIRE detail screen
- [ ] Projection visualizations
- [ ] Velocity analysis
- [ ] What-if scenarios (basic)
- [ ] Edit settings

### Phase 6: Notifications (1 day)
- [ ] FIRE milestone notifications
- [ ] Coast FIRE celebration
- [ ] Behind schedule alerts
- [ ] Annual review reminders

### Phase 7: Polish & Testing (2 days)
- [ ] Error handling
- [ ] Edge cases
- [ ] Unit tests
- [ ] Integration with existing goals
- [ ] Analytics events

---

## 11. UI Wireframes

### 11.1 FIRE Setup Wizard

```
┌─────────────────────────────────────────────┐
│ ← Let's Calculate Your FIRE Number    Skip │
├─────────────────────────────────────────────┤
│                                             │
│  What are your monthly expenses?            │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │  ₹  [50,000_____________]           │   │
│  └─────────────────────────────────────┘   │
│                                             │
│  💡 Include rent, food, utilities,         │
│     insurance, and regular spending        │
│                                             │
│  Quick Select:                              │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ ₹30K │ │ ₹50K │ │ ₹75K │ │₹1L  │       │
│  └──────┘ └──────┘ └──────┘ └──────┘       │
│                                             │
│  [━━━━━━━○────────────] Step 1 of 4         │
│                                             │
│  ┌─────────────────────────────────────┐   │
│  │          Continue →                  │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

### 11.2 FIRE Dashboard Card

```
┌─────────────────────────────────────────────┐
│  🔥 FIRE Number                   [Details] │
│                                             │
│     ┌───────────────────┐                   │
│     │                   │                   │
│     │    42%            │   ₹3.59 Cr        │
│     │    ┌─────┐        │   Your Target     │
│     │    │     │        │                   │
│     │    └─────┘        │   ₹1.51 Cr        │
│     │                   │   Current Value   │
│     └───────────────────┘                   │
│                                             │
│  🎯 FIRE by 2038 • Coast FIRE ✅           │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 12. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Setup Completion | 70% | Users completing FIRE setup |
| Weekly Engagement | 50% | Users viewing FIRE card weekly |
| Settings Adjustment | 20% | Users adjusting settings after setup |
| Milestone Celebrations | 80% | Users seeing milestone notifications |
| Coast FIRE Awareness | 60% | Users understanding Coast FIRE concept |

---

## 13. Premium Considerations

> **Initial Launch**: All FIRE features FREE
> **Future Premium Options** (if monetizing):

| Feature | Free | Premium |
|---------|------|---------|
| Basic FIRE Number | ✅ | ✅ |
| FIRE Type Selection | ✅ | ✅ |
| Progress Tracking | ✅ | ✅ |
| Coast FIRE | ✅ | ✅ |
| What-If Scenarios | Basic | Advanced |
| Projection Charts | Simple | Detailed |
| Historical Tracking | 1 year | Unlimited |
| Export Reports | ❌ | ✅ |

---

## 14. Competitive Advantage

### Why InvTrack's FIRE Number is Unique:

1. **Tied to Real Data**: Unlike standalone calculators, tracks against actual investments
2. **Alternative Investment Focus**: Designed for P2P, FDs, Real Estate - not just stocks
3. **India-First**: Appropriate inflation, no Social Security assumptions
4. **Coast FIRE**: Unique feature not common in other apps
5. **Non-Deletable**: Always present as a guiding north star
6. **Cash-Flow Based**: Uses XIRR for accurate progress tracking

---

## 15. Open Questions

1. Should FIRE Number be visible before sign-in (as a teaser)?
2. Should we offer multiple FIRE scenarios (lean + fat) simultaneously?
3. Should passive income (rental) be factored into reducing FIRE number?
4. Should we integrate with existing Goals or keep completely separate?
5. What's the default behavior for users who skip setup?

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-06 | CEO Research | Initial comprehensive plan |

---

## 16. Detailed UI Specifications

### 16.1 Design System Reference

Based on existing InvTrack design patterns:

| Element | Specification |
|---------|---------------|
| **Font** | Plus Jakarta Sans (headings), Inter (body) |
| **Primary Color** | `#5B4CDB` (Light), `#7C3AED` (Dark) |
| **Success Color** | `#10B981` (Positive/FIRE achieved) |
| **Warning Color** | `#F59E0B` (Behind schedule) |
| **Danger Color** | `#EF4444` (Negative/Critical) |
| **Card Style** | GlassCard with blur, 20px radius |
| **Spacing** | 8px grid (xs:8, sm:12, md:16, lg:24, xl:32) |
| **Progress Ring** | Custom painter with stroke 6-12px |

### 16.2 FIRE Dashboard Card (Overview Screen)

**Location**: Below Portfolio Summary, above Goals card
**Component**: `FireDashboardCard` extends `ConsumerWidget`

```
┌─────────────────────────────────────────────────────────────┐
│  GlassCard (onTap: navigate to FIRE detail)                 │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Row                                                  │   │
│  │  ┌────────┐                                          │   │
│  │  │ 🔥     │  Text: "FIRE Number"  [AppTypography.h4] │   │
│  │  │ Icon   │                                          │   │
│  │  └────────┘                    [Coast FIRE Badge] ✅  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Row                                                  │   │
│  │  ┌───────────────┐   ┌────────────────────────────┐  │   │
│  │  │               │   │  Column                     │  │   │
│  │  │  Progress     │   │  ₹3.59 Cr  [numberMedium]  │  │   │
│  │  │    Ring       │   │  Target    [caption]        │  │   │
│  │  │    42%        │   │                             │  │   │
│  │  │               │   │  ₹1.51 Cr  [body, primary] │  │   │
│  │  │  80x80        │   │  Current   [small, gray]   │  │   │
│  │  └───────────────┘   └────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Row (Status footer)                                  │   │
│  │  🎯 FIRE by 2038 (Age 47)      +₹2.1L/mo velocity    │   │
│  │  [caption, gray]               [small, success]       │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

**States**:
1. **Not Setup**: Show setup prompt card (similar to Goals empty state)
2. **Loading**: Skeleton with shimmer effect
3. **Normal**: Progress display with metrics
4. **Achieved**: Celebration style with confetti accent

### 16.3 FIRE Setup Wizard (Multi-Step)

**Route**: `/fire/setup`
**Component**: `FireSetupScreen` (PageView with step indicator)

#### Step 1: Monthly Expenses

```
┌─────────────────────────────────────────────────────────────┐
│  AppBar: "Let's Calculate Your FIRE Number"   [Skip]        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Illustration: Money/savings illustration (Lottie)      │ │
│  │  Height: 200px                                          │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Text: "What are your monthly expenses?"                    │
│  [AppTypography.h2, center]                                 │
│                                                              │
│  Text: "Include rent, food, utilities, insurance..."        │
│  [AppTypography.caption, center, gray]                      │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  AppTextField                                           │ │
│  │  Prefix: "₹"                                            │ │
│  │  Keyboard: Number                                        │ │
│  │  Hint: "50,000"                                         │ │
│  │  Suffix: "/month"                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Quick Select Chips:                                         │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐              │
│  │ ₹25K │ │ ₹50K │ │ ₹75K │ │ ₹1L  │ │ ₹1.5L│              │
│  └──────┘ └──────┘ └──────┘ └──────┘ └──────┘              │
│                                                              │
│  ━━━━━━━━━○──────────────  Step 1 of 4                      │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  GradientButton: "Continue"                             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### Step 2: Age Information

```
┌─────────────────────────────────────────────────────────────┐
│  AppBar: "Let's Calculate Your FIRE Number"   [Back]        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Text: "Your age & FIRE target"                              │
│  [AppTypography.h2, center]                                  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  GlassCard: Current Age                                 │ │
│  │                                                          │ │
│  │  Row:                                                    │ │
│  │  "Your current age"          NumberPicker: [30]          │ │
│  │                               Years                       │ │
│  │                                                          │ │
│  │  Slider: 18 ────●───────────────────────── 70            │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  SizedBox(height: 24)                                        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  GlassCard: Target FIRE Age                             │ │
│  │                                                          │ │
│  │  Row:                                                    │ │
│  │  "Target FIRE age"           NumberPicker: [45]          │ │
│  │                               Years                       │ │
│  │                                                          │ │
│  │  Slider: (currentAge+5) ───●───────────── 65             │ │
│  │                                                          │ │
│  │  Helper: "15 years from now"                             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ━━━━━━━━━━━━━━━━○────────  Step 2 of 4                     │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  GradientButton: "Continue"                             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### Step 3: FIRE Type Selection

```
┌─────────────────────────────────────────────────────────────┐
│  AppBar: "Let's Calculate Your FIRE Number"   [Back]        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Text: "Choose your FIRE lifestyle"                          │
│  [AppTypography.h2, center]                                  │
│                                                              │
│  Text: "This affects your target FIRE number"               │
│  [AppTypography.caption, center, gray]                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  TypeSelectorCard: LEAN FIRE (selected: border glow)    │ │
│  │                                                          │ │
│  │  🪶  Lean FIRE                          [Radio Button]   │ │
│  │      Minimalist lifestyle                                │ │
│  │      Est: ₹75L - ₹1.5Cr                                  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  TypeSelectorCard: REGULAR FIRE                         │ │
│  │                                                          │ │
│  │  ⚖️  Regular FIRE                       [Radio Button]   │ │
│  │      Maintain current lifestyle                          │ │
│  │      Est: ₹1.5Cr - ₹3.75Cr                              │ │
│  │      RECOMMENDED                                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  TypeSelectorCard: FAT FIRE                             │ │
│  │                                                          │ │
│  │  💎  Fat FIRE                           [Radio Button]   │ │
│  │      Premium lifestyle + travel                          │ │
│  │      Est: ₹3.75Cr - ₹12.5Cr+                            │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ━━━━━━━━━━━━━━━━━━━━━━━━○─  Step 3 of 4                    │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  GradientButton: "Continue"                             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### Step 4: Advanced Settings (Optional)

```
┌─────────────────────────────────────────────────────────────┐
│  AppBar: "Fine-tune Your FIRE Plan"          [Back]         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Text: "Advanced Settings"                                   │
│  [AppTypography.h2, center]                                  │
│                                                              │
│  Text: "Optional - We've set sensible defaults for India"   │
│  [AppTypography.caption, center, gray]                       │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  ExpansionTile: Withdrawal & Returns                    │ │
│  │  ├─ Safe Withdrawal Rate: 4.0% (slider 2.5-5%)          │ │
│  │  ├─ Pre-retirement Return: 12% (slider 8-15%)           │ │
│  │  └─ Post-retirement Return: 8% (slider 5-10%)           │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  ExpansionTile: Inflation & Buffer                      │ │
│  │  ├─ Inflation Rate: 6% (slider 4-10%)                   │ │
│  │  ├─ Healthcare Buffer: 20% (slider 0-50%)               │ │
│  │  └─ Emergency Months: 6 (slider 3-12)                   │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  ExpansionTile: Other Income                            │ │
│  │  ├─ Monthly Passive Income: ₹0                          │ │
│  │  ├─ Expected Pension: ₹0                                │ │
│  │  └─ Life Expectancy: 85 years                           │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━●  Step 4 of 4                 │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  GradientButton: "Calculate My FIRE Number 🔥"          │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  TextButton: "Skip - Use Defaults"                          │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

#### Step 5: FIRE Number Reveal (Celebration Screen)

```
┌─────────────────────────────────────────────────────────────┐
│  (Fullscreen, no AppBar - immersive)                        │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Lottie: Celebration/confetti animation (300x300)       │ │
│  │  Auto-play on entry                                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Text: "Your FIRE Number is"                                 │
│  [AppTypography.h3, center, gray]                            │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  AnimatedNumber: ₹3.59 Crore                            │ │
│  │  [AppTypography.displayLarge, primary]                   │ │
│  │  Count-up animation from 0 to target                     │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  GlassCard: Summary                                     │ │
│  │                                                          │ │
│  │  📅 Target Age: 45 (15 years)                           │ │
│  │  💰 Monthly Expenses: ₹50,000                           │ │
│  │  📈 SWR: 4%                                              │ │
│  │  🔥 FIRE Type: Regular                                   │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  Text: "You can do this! 💪"                                │
│  [AppTypography.body, center]                                │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  GradientButton: "Start Tracking"                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  TextButton: "Adjust Settings"                               │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 16.4 FIRE Detail Screen

**Route**: `/fire`
**Component**: `FireDetailScreen`

```
┌─────────────────────────────────────────────────────────────┐
│  SliverAppBar (expandedHeight: 300)                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  FlexibleSpaceBar                                       │ │
│  │                                                          │ │
│  │  ┌────────────────────────────────────────────────────┐ │ │
│  │  │  FireProgressRingLarge (180x180)                   │ │ │
│  │  │                                                      │ │ │
│  │  │     ┌─────────────────────┐                         │ │ │
│  │  │     │                     │                         │ │ │
│  │  │     │       42%           │                         │ │ │
│  │  │     │   ₹1.51 Cr          │                         │ │ │
│  │  │     │  of ₹3.59 Cr        │                         │ │ │
│  │  │     │                     │                         │ │ │
│  │  │     └─────────────────────┘                         │ │ │
│  │  │                                                      │ │ │
│  │  │  Milestones: ●─────●─────●─────○─────○               │ │ │
│  │  │              10%  25%   50%   75%  100%             │ │ │
│  │  └────────────────────────────────────────────────────┘ │ │
│  │                                                          │ │
│  │  Actions: [Edit Settings] [Share]                        │ │
│  └────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│  SliverList                                                  │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: Key Numbers                                   │ │
│  │                                                          │ │
│  │  Row of MetricTiles (3 columns):                        │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐                 │ │
│  │  │ Target   │ │ Current  │ │ Gap      │                 │ │
│  │  │ ₹3.59Cr  │ │ ₹1.51Cr  │ │ ₹2.08Cr  │                 │ │
│  │  └──────────┘ └──────────┘ └──────────┘                 │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: Projections                                   │ │
│  │                                                          │ │
│  │  GlassCard:                                             │ │
│  │  🎯 Projected FIRE Date: March 2041                     │ │
│  │     At age 50 (5 years after target)                    │ │
│  │                                                          │ │
│  │  Status Badge: [🟡 Slightly Behind - Adjust savings]    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: Coast FIRE                                    │ │
│  │                                                          │ │
│  │  GlassCard:                                             │ │
│  │  🏖️ Coast FIRE Number: ₹85L                            │ │
│  │                                                          │ │
│  │  Progress: ━━━━━━━━━━━━━━━━━━━━● 178%                   │ │
│  │                                                          │ │
│  │  ✅ Coast FIRE Achieved!                                │ │
│  │  You could stop saving aggressively and still reach     │ │
│  │  ₹3.59Cr by age 60 through compound growth alone.       │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: Velocity Analysis                             │ │
│  │                                                          │ │
│  │  Row of MetricTiles (2 columns):                        │ │
│  │  ┌─────────────────┐ ┌─────────────────┐                │ │
│  │  │ Current Pace    │ │ Required Pace   │                │ │
│  │  │ +₹1.8L/mo       │ │ +₹2.3L/mo       │                │ │
│  │  │ 🔴 -₹50K gap    │ │                 │                │ │
│  │  └─────────────────┘ └─────────────────┘                │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: What-If Scenarios                             │ │
│  │                                                          │ │
│  │  Interactive Card:                                       │ │
│  │  "What if I reduce expenses by ₹10K?"                   │ │
│  │  → FIRE Number: ₹2.99Cr (-₹60L)                         │ │
│  │  → FIRE by: 2038 (3 years earlier!)                     │ │
│  │                                                          │ │
│  │  [Explore More Scenarios →]                             │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: Linked Investments                            │ │
│  │                                                          │ │
│  │  Text: "All 12 investments are tracking towards FIRE"   │ │
│  │                                                          │ │
│  │  [View All Investments →]                               │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: Your Settings                                 │ │
│  │                                                          │ │
│  │  ListTiles:                                              │ │
│  │  ├─ Monthly Expenses: ₹50,000                           │ │
│  │  ├─ FIRE Type: Regular                                  │ │
│  │  ├─ Target Age: 45                                      │ │
│  │  ├─ Safe Withdrawal Rate: 4%                            │ │
│  │  └─ Inflation Rate: 6%                                  │ │
│  │                                                          │ │
│  │  [Edit Settings]                                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  SizedBox(height: 100) // Bottom padding                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 16.5 FIRE Settings Screen

**Route**: `/fire/settings`
**Component**: `FireSettingsScreen`

```
┌─────────────────────────────────────────────────────────────┐
│  AppBar: "FIRE Settings"                                    │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: Basic Settings                                │ │
│  │                                                          │ │
│  │  ListTile: Monthly Expenses                              │ │
│  │  ₹50,000                                    [Edit Icon] │ │
│  │                                                          │ │
│  │  Divider                                                 │ │
│  │                                                          │ │
│  │  ListTile: Current Age                                   │ │
│  │  30 years                                   [Edit Icon] │ │
│  │                                                          │ │
│  │  Divider                                                 │ │
│  │                                                          │ │
│  │  ListTile: Target FIRE Age                               │ │
│  │  45 years                                   [Edit Icon] │ │
│  │                                                          │ │
│  │  Divider                                                 │ │
│  │                                                          │ │
│  │  ListTile: FIRE Type                                     │ │
│  │  Regular FIRE                               [Selector]  │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: Advanced Settings                             │ │
│  │                                                          │ │
│  │  SliderTile: Safe Withdrawal Rate                        │ │
│  │  4.0%                                                    │ │
│  │  ━━━━━━━━━━●━━━━━━━━━━ (2.5% - 5.0%)                     │ │
│  │                                                          │ │
│  │  SliderTile: Pre-retirement Return                       │ │
│  │  12%                                                     │ │
│  │  ━━━━━━━━━━━━━●━━━━━━ (8% - 15%)                         │ │
│  │                                                          │ │
│  │  SliderTile: Post-retirement Return                      │ │
│  │  8%                                                      │ │
│  │  ━━━━━━━━━●━━━━━━━━━━ (5% - 10%)                         │ │
│  │                                                          │ │
│  │  SliderTile: Inflation Rate                              │ │
│  │  6%                                                      │ │
│  │  ━━━━━━━━━●━━━━━━━━━━ (4% - 10%)                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: Buffers                                       │ │
│  │                                                          │ │
│  │  SliderTile: Healthcare Buffer                           │ │
│  │  20%                                                     │ │
│  │  ━━━━━━━●━━━━━━━━━━━━ (0% - 50%)                         │ │
│  │                                                          │ │
│  │  SliderTile: Emergency Months                            │ │
│  │  6 months                                                │ │
│  │  ━━━━━━●━━━━━━━━━━━━━ (3 - 12 months)                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Section: Other Income                                  │ │
│  │                                                          │ │
│  │  ListTile: Monthly Passive Income                        │ │
│  │  ₹0                                         [Edit Icon] │ │
│  │                                                          │ │
│  │  ListTile: Expected Pension                              │ │
│  │  ₹0                                         [Edit Icon] │ │
│  │                                                          │ │
│  │  ListTile: Life Expectancy                               │ │
│  │  85 years                                   [Edit Icon] │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  GradientButton: "Save Changes"                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                                                              │
│  TextButton: "Reset to Defaults"                            │ │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 16.6 Custom Widgets Specifications

#### 16.6.1 FireProgressRing

```dart
/// Large FIRE progress ring with milestone markers
class FireProgressRing extends StatelessWidget {
  final double progress;           // 0-100+
  final double size;               // 180 default
  final Color progressColor;       // Based on status
  final List<double> milestones;   // [10, 25, 50, 75, 100]
  final bool showMilestoneMarkers; // true

  // Colors based on progress:
  // < 25%: primaryLight (purple)
  // 25-50%: amber
  // 50-75%: success light
  // > 100%: success with glow effect
}
```

#### 16.6.2 FireTypeSelectorCard

```dart
/// Selectable card for FIRE type with radio button
class FireTypeSelectorCard extends StatelessWidget {
  final FireType type;
  final bool isSelected;
  final VoidCallback onTap;
  final String title;              // "Lean FIRE"
  final String description;        // "Minimalist lifestyle"
  final String estimatedRange;     // "₹75L - ₹1.5Cr"
  final IconData icon;             // 🪶 🎯 💎
  final bool isRecommended;        // Show badge

  // When selected:
  // - Border glow with primaryLight
  // - Radio button filled
  // - Slight background tint
}
```

#### 16.6.3 CoastFireBadge

```dart
/// Small badge showing Coast FIRE status
class CoastFireBadge extends StatelessWidget {
  final bool isAchieved;

  // If achieved:
  // - Green background with checkmark
  // - "Coast FIRE ✅"
  // If not:
  // - Gray background
  // - "Coast: 65%"
}
```

#### 16.6.4 FireMilestoneIndicator

```dart
/// Horizontal milestone indicator with dots
class FireMilestoneIndicator extends StatelessWidget {
  final double progress;           // 0-100
  final List<int> milestones;      // [10, 25, 50, 75, 100]

  // Visual:
  // ●─────●─────●─────○─────○
  // Filled dots for achieved, empty for pending
  // Progress line fills between dots
}
```

#### 16.6.5 FireStatusCard

```dart
/// Status card with projection info
class FireStatusCard extends StatelessWidget {
  final FireProgressStatus status;
  final DateTime projectedDate;
  final int projectedAge;
  final int yearsFromTarget;       // Can be negative (ahead)

  // Status colors:
  // ahead: success green
  // onTrack: primary purple
  // behind: warning amber
  // achieved: success with celebration
}
```

### 16.7 Animation Specifications

| Element | Animation | Duration | Curve |
|---------|-----------|----------|-------|
| Progress Ring | Draw from 0 | 1200ms | easeOutCubic |
| FIRE Number Reveal | Count up | 1500ms | easeOut |
| Milestone Dot | Scale pop | 300ms | elasticOut |
| Status Badge | Fade + Slide | 400ms | easeOutCubic |
| Card Entry | Fade + SlideUp | 300ms | easeOut |
| Celebration Confetti | Lottie | 2500ms | - |

### 16.8 Accessibility Requirements

| Requirement | Implementation |
|-------------|----------------|
| Screen Reader | All interactive elements have semantic labels |
| Progress Ring | Announces "FIRE progress: 42%" |
| Milestones | "Milestone 50% achieved, 75% pending" |
| Color Contrast | Min 4.5:1 for text on all backgrounds |
| Touch Targets | Minimum 48x48dp for all buttons |
| Reduce Motion | Skip animations if system setting enabled |

---

*This document is the single source of truth for FIRE Number feature development.*

