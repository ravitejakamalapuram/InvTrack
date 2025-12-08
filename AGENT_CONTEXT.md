# InvTracker - Cash Flow Investment Tracker Redesign

## Project Overview

**Goal**: Transform InvTracker from a traditional "investment portfolio tracker" to a "cash flow document" approach for tracking alternative investments.

### Philosophy Shift
| Old Approach | New Approach |
|--------------|--------------|
| Track what you **own** (holdings) | Track what **went out and came back** (cash flows) |
| Focus on current portfolio value | Focus on investment effectiveness |
| Units, prices, market value | Cash out, cash in, returns |
| Always "open" positions | Clear lifecycle: Open → Closed (with reopen capability) |

## User Requirements Summary

1. **Track money going out and coming back** - not units/prices
2. **Add investments, add transactions (cash flows), mark as closed** (with ability to reopen)
3. **See returns at investment level and overall cash in/out**
4. **XIRR calculations** at global and individual investment levels
5. **Single investment list with filter tabs** (All/Open/Closed) - NOT separate bottom navs
6. **Cash flow section embedded inside investment detail** - not a separate nav
7. **Focus on alternative investments** (P2P, FD, Bonds, Real Estate, etc.)
8. **Keep premium features**
9. **Only 3 bottom nav tabs**: Overview, Investments, Settings

## Technical Stack

- **Framework**: Flutter 3.x with Dart
- **State Management**: Riverpod 2.x
- **Database**: Drift ORM with SQLite (schema v3)
- **Navigation**: GoRouter with StatefulShellRoute
- **Build System**: build_runner for Drift code generation

## Data Model (NEW)

### InvestmentType Enum
```dart
enum InvestmentType {
  p2pLending, fixedDeposit, bonds, realEstate, privateEquity,
  angelInvesting, chitFunds, gold, crypto, mutualFunds, stocks, other
}
```

### InvestmentStatus Enum
```dart
enum InvestmentStatus { open, closed }
```

### CashFlowType Enum
```dart
enum CashFlowType {
  invest,      // Money going OUT (outflow)
  returnFlow,  // Money coming back IN (inflow)
  income,      // Dividends, interest (inflow)
  fee          // Fees, charges (outflow)
}
```

### InvestmentEntity
- id, name, type (InvestmentType), status (InvestmentStatus), notes, createdAt, closedAt

### CashFlowEntity
- id, investmentId, date, type (CashFlowType), amount, notes, createdAt
- `signedAmount` getter: negative for outflows (invest, fee), positive for inflows (returnFlow, income)

## Key Providers (in investment_provider.dart)

```dart
// Read providers
allInvestmentsProvider          // Stream<List<InvestmentEntity>>
investmentsByStatusProvider     // Family provider filtered by status
investmentByIdProvider          // Single investment by ID
cashFlowsByInvestmentProvider   // Cash flows for an investment
investmentStatsProvider         // Returns InvestmentStats (cashOut, cashIn, netPosition, xirr, moic)
globalStatsProvider             // Global metrics across all investments

// Mutation provider - EXACT SIGNATURES:
investmentNotifierProvider      // InvestmentNotifier with methods:
  - addInvestment({required String name, required InvestmentType type, String? notes})
  - updateInvestment({required String id, required String name, required InvestmentType type, String? notes})
  - deleteInvestment(String id)
  - closeInvestment(String id)
  - reopenInvestment(String id)
  - addCashFlow({required String investmentId, required CashFlowType type, required double amount, required DateTime date, String? notes})
  - deleteCashFlow(String id)
```

## Files Status

### ✅ COMPLETED
1. `lib/core/database/tables/investments.dart` - New schema
2. `lib/core/database/tables/transactions.dart` - CashFlows table
3. `lib/core/database/app_database.dart` - Schema v3
4. `lib/core/calculations/financial_calculator.dart` - Updated for CashFlowEntity
5. `lib/core/router/app_router.dart` - 3-tab navigation
6. `lib/features/home/presentation/screens/home_shell_screen.dart` - 3 bottom tabs
7. `lib/features/overview/presentation/screens/overview_screen.dart` - NEW file
8. `lib/features/investment/domain/entities/investment_entity.dart` - Updated
9. `lib/features/investment/domain/entities/transaction_entity.dart` - CashFlowEntity added
10. `lib/features/investment/presentation/providers/investment_provider.dart` - Completely rewritten
11. `lib/features/investment/presentation/screens/investment_list_screen.dart` - Updated
12. `lib/features/investment/presentation/screens/investment_detail_screen.dart` - Updated
13. `lib/features/investment/presentation/screens/add_investment_screen.dart` - Updated

### 🔄 IN PROGRESS
14. `lib/features/investment/presentation/screens/add_transaction_screen.dart`
    - **LINES 1-180**: ✅ UPDATED (imports, controllers, _submit, build method start)
    - **LINES 180-235**: ✅ OK (date picker section)
    - **LINES 237-290**: ❌ NEEDS UPDATE (remove quantity/price/fees, add single amount field)
    - **LINES 295-347**: ❌ NEEDS UPDATE (remove old notes field styling if duplicated)
    - **LINES 351-405**: ❌ NEEDS UPDATE (preview card - use _amountController not _totalAmount)
    - **LINES 419-485**: ❌ NEEDS REWRITE (_buildTypeSelector - use CashFlowType.values)
    - **LINES 557-617**: ❌ NEEDS UPDATE (_buildSubmitButton - use CashFlowType)
    - **LINES 620-627**: ❌ DELETE (TransactionTypeOption class - no longer needed)

### ❓ NEEDS REVIEW
15. `lib/features/investment/presentation/screens/edit_investment_screen.dart` - Needs update for new entity

---

## DETAILED NEXT STEPS

### Step 1: Complete add_transaction_screen.dart (Priority: HIGH)

**File**: `lib/features/investment/presentation/screens/add_transaction_screen.dart`

**What's Already Done (Lines 1-180)**:
- Updated imports to include `CashFlowType` from `transaction_entity.dart`
- Changed form controllers: removed `_quantityController`, `_priceController`, `_feesController`; kept `_amountController`, `_notesController`
- Changed `_selectedType` from `String` to `CashFlowType`
- Updated `_submit()` to call `investmentNotifierProvider.notifier.addCashFlow()`
- Updated title to "Add Cash Flow"

**What Needs to Be Done (Lines 237-608)**:

1. **Replace form fields (lines 237-347)** - Remove quantity/price/fees fields, add single amount field:
```dart
// Amount Field
_buildNumberField(
  controller: _amountController,
  label: 'Amount',
  hint: '0.00',
  icon: Icons.attach_money_rounded,
  isDark: isDark,
  prefix: currencySymbol,
  validator: (value) {
    if (value == null || value.isEmpty) return 'Required';
    if (double.tryParse(value) == null) return 'Invalid';
    return null;
  },
),

const SizedBox(height: 20),

// Notes Field (already exists, keep it)
```

2. **Update Total Preview section (lines 351-403)** - Show amount with flow direction:
```dart
GlassCard(
  padding: const EdgeInsets.all(20),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amount', ...),
          ListenableBuilder(
            listenable: _amountController,
            builder: (context, _) {
              final amount = double.tryParse(_amountController.text) ?? 0;
              return Text(
                '${_selectedType.isOutflow ? '-' : '+'}$currencySymbol${amount.toStringAsFixed(0)}',
                style: ...,
              );
            },
          ),
        ],
      ),
      // Icon showing flow direction
    ],
  ),
),
```

3. **Rewrite _buildTypeSelector (lines 419-485)** - Use CashFlowType enum:
```dart
Widget _buildTypeSelector(bool isDark) {
  return Wrap(
    spacing: 10,
    runSpacing: 10,
    children: CashFlowType.values.map((type) {
      final isSelected = _selectedType == type;
      final color = type.isOutflow ? AppColors.errorLight : AppColors.successLight;
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedType = type);
        },
        child: AnimatedContainer(
          // ... similar styling as before but using type.displayName and type.isOutflow
        ),
      );
    }).toList(),
  );
}
```

4. **Update _buildSubmitButton (lines 557-617)** - Use CashFlowType:
```dart
Widget _buildSubmitButton(bool isDark) {
  final color = _selectedType.isOutflow ? AppColors.errorLight : AppColors.successLight;
  // ... rest of button with updated colors and text "Save Cash Flow"
}
```

5. **Remove TransactionTypeOption class (lines 620-627)** - No longer needed

### Step 2: Update edit_investment_screen.dart (Priority: MEDIUM)

**File**: `lib/features/investment/presentation/screens/edit_investment_screen.dart`

**Changes Needed**:
1. Update imports - add `InvestmentType` from investment_entity.dart
2. Remove `_symbolController` and portfolio-related code
3. Change `_selectedType` from `String` to `InvestmentType`
4. Update form to use `InvestmentType.values` for type selector
5. Add `_notesController` for notes field
6. Update `_submit()` to call `investmentNotifierProvider.notifier.updateInvestment()`
7. Remove `InvestmentTypeOption` class at the end

### Step 3: Run Analysis and Fix Errors (Priority: HIGH)

```bash
cd /Users/rkamalapuram/personal-git/InvTrack
flutter analyze 2>&1 | head -100
```

Fix any remaining type errors or undefined references.

### Step 4: Test the App (Priority: HIGH)

```bash
flutter run
```

Test:
1. Overview screen shows global stats
2. Investment list shows with filter tabs (All/Open/Closed)
3. Can add new investment with InvestmentType
4. Can add cash flows to investment
5. Investment detail shows cash flows list
6. Can close/reopen investment
7. Can delete cash flows
8. XIRR calculations work

---

## Important Provider References

When calling providers, use these exact names:

```dart
// Read-only providers
ref.watch(allInvestmentsProvider)
ref.watch(investmentsByStatusProvider(InvestmentStatus.open))
ref.watch(investmentByIdProvider(investmentId))
ref.watch(cashFlowsByInvestmentProvider(investmentId))
ref.watch(investmentStatsProvider(investmentId))
ref.watch(globalStatsProvider)

// Mutation provider
ref.read(investmentNotifierProvider.notifier).addInvestment(...)
ref.read(investmentNotifierProvider.notifier).addCashFlow(...)
ref.read(investmentNotifierProvider.notifier).deleteInvestment(...)
ref.read(investmentNotifierProvider.notifier).deleteCashFlow(...)
ref.read(investmentNotifierProvider.notifier).closeInvestment(...)
ref.read(investmentNotifierProvider.notifier).reopenInvestment(...)
```

## CashFlowType Helper Methods (Already in transaction_entity.dart - DON'T recreate)

```dart
// These are already defined as getters on the CashFlowType enum:
CashFlowType.invest.displayName    // 'Invest'
CashFlowType.returnFlow.displayName // 'Return'
CashFlowType.income.displayName     // 'Income'
CashFlowType.fee.displayName        // 'Fee'

CashFlowType.invest.isOutflow       // true
CashFlowType.returnFlow.isOutflow   // false
CashFlowType.income.isOutflow       // false
CashFlowType.fee.isOutflow          // true

CashFlowType.invest.isInflow        // false
CashFlowType.returnFlow.isInflow    // true
CashFlowType.income.isInflow        // true
CashFlowType.fee.isInflow           // false
```

## InvestmentType Helper Methods

```dart
extension on InvestmentType {
  String get displayName => switch (this) {
    InvestmentType.p2pLending => 'P2P Lending',
    InvestmentType.fixedDeposit => 'Fixed Deposit',
    // ... etc
  };

  IconData get icon => switch (this) {
    InvestmentType.p2pLending => Icons.handshake_rounded,
    // ... etc
  };

  Color get color => switch (this) {
    InvestmentType.p2pLending => AppColors.graphBlue,
    // ... etc
  };
}
```

---

## Files That Should NOT Be Modified

- `lib/core/database/app_database.g.dart` - Auto-generated by build_runner
- `lib/core/database/tables/*.g.dart` - Auto-generated
- Any files in `lib/features/portfolio/` - Portfolio concept removed
- Any files in `lib/features/dashboard/` - Deleted
- Any files in `lib/features/insights/` - Deleted

---

## Commands Reference

```bash
# Generate Drift code
dart run build_runner build --delete-conflicting-outputs

# Analyze code
flutter analyze

# Run app
flutter run

# Run tests
flutter test
```

---

## Current File Contents Reference

### add_transaction_screen.dart Current State (Lines 237-350 need replacement)

The current lines 237-350 have OLD code for quantity/price/fees fields that needs to be replaced with a single amount field. Here's what to replace:

**OLD CODE TO REMOVE (approx lines 237-350)**:
- Row with quantity and price fields
- Fees field
- Notes field section

**NEW CODE TO INSERT**:
```dart
                // Amount Field
                _buildNumberField(
                  controller: _amountController,
                  label: 'Amount',
                  hint: '0.00',
                  icon: Icons.attach_money_rounded,
                  isDark: isDark,
                  prefix: currencySymbol,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid';
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                // Notes Field
                Text(
                  'Notes (Optional)',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  style: AppTypography.body.copyWith(
                    color: isDark ? Colors.white : AppColors.neutral900Light,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add any notes about this cash flow...',
                    hintStyle: AppTypography.body.copyWith(
                      color: isDark ? AppColors.neutral500Dark : AppColors.neutral400Light,
                    ),
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? AppColors.neutral700Dark : AppColors.neutral200Light,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),

                const SizedBox(height: 28),
```

---

## EXACT STEPS FOR NEW AGENT THREAD

### Step 1: Replace Lines 237-283 (Remove quantity/price/fees, add amount field)

**Replace this OLD code (lines 237-283):**
```dart
                // Amount Fields
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberField(
                        controller: _quantityController,
                        ... quantity field ...
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildNumberField(
                        controller: _priceController,
                        ... price field ...
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Fees Field
                _buildNumberField(
                  controller: _feesController,
                  label: 'Fees (Optional)',
                  ...
                ),
```

**With this NEW code:**
```dart
                // Amount Field
                _buildNumberField(
                  controller: _amountController,
                  label: 'Amount',
                  hint: '0.00',
                  icon: Icons.attach_money_rounded,
                  isDark: isDark,
                  prefix: currencySymbol,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (double.tryParse(value) == null) return 'Invalid amount';
                    if (double.parse(value) <= 0) return 'Must be positive';
                    return null;
                  },
                ),
```

### Step 2: Update Notes hint text (line 303)
Change: `'Add any notes about this transaction...'`
To: `'Add any notes about this cash flow...'`

### Step 3: Replace Preview Card (lines 331-383)

**Replace the GlassCard with:**
```dart
                // Amount Preview
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedType.isOutflow ? 'Cash Out' : 'Cash In',
                            style: AppTypography.body.copyWith(
                              color: isDark ? AppColors.neutral400Dark : AppColors.neutral500Light,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ListenableBuilder(
                            listenable: _amountController,
                            builder: (context, _) {
                              final amount = double.tryParse(_amountController.text) ?? 0;
                              return Text(
                                '${_selectedType.isOutflow ? '-' : '+'}$currencySymbol${amount.toStringAsFixed(0)}',
                                style: AppTypography.numberLarge.copyWith(
                                  color: _selectedType.isOutflow ? AppColors.errorLight : AppColors.successLight,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: _selectedType.isOutflow
                              ? AppColors.dangerGradient
                              : AppColors.successGradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _selectedType.isOutflow
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
```

### Step 4: Replace _buildTypeSelector method (lines 399-465)

**Replace the entire method with:**
```dart
  Widget _buildTypeSelector(bool isDark) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: CashFlowType.values.map((type) {
        final isSelected = _selectedType == type;
        final color = type.isOutflow ? AppColors.errorLight : AppColors.successLight;
        final icon = switch (type) {
          CashFlowType.invest => Icons.arrow_upward_rounded,
          CashFlowType.returnFlow => Icons.arrow_downward_rounded,
          CashFlowType.income => Icons.payments_rounded,
          CashFlowType.fee => Icons.receipt_long_rounded,
        };
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedType = type);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: (MediaQuery.of(context).size.width - 60) / 2,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(colors: [color, color.withValues(alpha: 0.8)])
                  : null,
              color: isSelected ? null : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? Colors.transparent : (isDark ? AppColors.neutral700Dark : AppColors.neutral200Light),
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isSelected ? Colors.white : (isDark ? AppColors.neutral400Dark : AppColors.neutral600Light), size: 20),
                const SizedBox(width: 8),
                Text(
                  type.displayName,
                  style: AppTypography.body.copyWith(
                    color: isSelected ? Colors.white : (isDark ? AppColors.neutral300Dark : AppColors.neutral700Light),
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
```

### Step 5: Update _buildSubmitButton method (lines 537-597)

**Replace lines 538-539:**
```dart
    final typeOption = _transactionTypes.firstWhere((t) => t.name == _selectedType);
```
**With:**
```dart
    final color = _selectedType.isOutflow ? AppColors.errorLight : AppColors.successLight;
```

**Then update all references:**
- `typeOption.color` → `color`
- `typeOption.icon` → `_selectedType.isOutflow ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded`
- `'Save ${typeOption.name} Transaction'` → `'Save Cash Flow'`

### Step 6: Delete TransactionTypeOption class (lines 600-608)
Remove the entire class - it's no longer needed.

### Step 7: Run Analysis
```bash
cd /Users/rkamalapuram/personal-git/InvTrack
flutter analyze 2>&1 | head -100
```

### Step 8: Update edit_investment_screen.dart
Follow same patterns:
- Use `InvestmentType` enum instead of string
- Use `investmentNotifierProvider.notifier.updateInvestment()`
- Remove portfolio/symbol fields, add notes field

### Step 9: Final Analysis and Test
```bash
flutter analyze
flutter run
```

---

## Verification Checklist Before Completion

- [ ] add_transaction_screen.dart compiles without errors
- [ ] edit_investment_screen.dart compiles without errors
- [ ] `flutter analyze` shows no errors
- [ ] App runs without crashes
- [ ] Can navigate to all 3 bottom tabs
- [ ] Can add investment with InvestmentType
- [ ] Can add cash flow with CashFlowType
- [ ] Investment detail shows cash flows
- [ ] Can close/reopen investment
- [ ] Stats show correctly (Cash Out, Cash In, XIRR, MOIC)

