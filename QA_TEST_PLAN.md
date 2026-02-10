# QA Test Plan - FIRE Calculation Fix

## 🎯 Objective
Verify that the FIRE calculation fix works correctly and provides accurate, user-friendly results.

## 📋 Test Environment
- **Branch**: `fix/fire-calculation-real-returns`
- **PR**: #167
- **Flutter Version**: 3.32+
- **Test Data**: Standard test scenarios with known expected values

## ✅ Pre-Test Checklist
- [ ] Pull latest code from branch
- [ ] Run `flutter pub get`
- [ ] Run `flutter clean`
- [ ] Ensure Firebase is configured

## 🧪 Unit Tests

### Test Suite 1: Core Calculation Service
```bash
flutter test test/features/fire_number/domain/services/fire_calculation_service_test.dart
```

**Expected Results**:
- ✅ All tests pass
- ✅ FIRE number calculated in today's money
- ✅ Real return calculation is correct
- ✅ Inflation-adjusted values are accurate
- ✅ Edge cases handled properly

**Verification**:
- [ ] All tests pass without errors
- [ ] No warnings or deprecations
- [ ] Test coverage is comprehensive

### Test Suite 2: All FIRE Tests
```bash
flutter test test/features/fire_number/
```

**Expected Results**:
- ✅ All FIRE-related tests pass
- ✅ Entity tests pass
- ✅ Repository tests pass
- ✅ Provider tests pass

**Verification**:
- [ ] All tests pass
- [ ] No regressions in other components

### Test Suite 3: Full Test Suite
```bash
flutter test
```

**Expected Results**:
- ✅ All 868+ tests pass
- ✅ No new failures introduced

**Verification**:
- [ ] All tests pass
- [ ] Test count matches or exceeds baseline

## 📱 Manual Testing

### Scenario 1: Standard FIRE Calculation
**Setup**:
- Monthly expenses: ₹50,000
- Current age: 30
- Target FIRE age: 50 (20 years)
- Inflation: 6%
- Nominal return: 12%
- Current portfolio: ₹10,00,000
- Current savings: ₹25,000/month

**Expected Results**:
- FIRE Number: ~₹18,30,000 (₹1.83 crore in today's money)
  - Core corpus: ₹15,00,000
  - Emergency fund: ₹3,00,000
  - Healthcare buffer: ₹3,00,000
- Inflation-adjusted FIRE: ~₹43,85,000 (₹4.39 crore in future money)
- Required monthly savings: ~₹25,000-₹30,000
- Real return used: ~5.66%

**Test Steps**:
1. [ ] Navigate to FIRE setup
2. [ ] Enter test data
3. [ ] Complete setup
4. [ ] Verify FIRE dashboard shows correct values
5. [ ] Check tooltip explanations
6. [ ] Verify "in today's money" is displayed

**Verification**:
- [ ] FIRE number is in expected range
- [ ] Required savings are reasonable
- [ ] Tooltips explain the calculation
- [ ] UI is clear and understandable

### Scenario 2: Zero Inflation
**Setup**:
- Monthly expenses: ₹50,000
- Inflation: 0%
- Nominal return: 12%

**Expected Results**:
- Real return = Nominal return (12%)
- FIRE number same as before
- Required savings lower (due to higher real return)

**Test Steps**:
1. [ ] Update settings with 0% inflation
2. [ ] Verify calculations update
3. [ ] Check real return equals nominal

**Verification**:
- [ ] Calculations are correct
- [ ] No division by zero errors
- [ ] UI handles edge case gracefully

### Scenario 3: High Inflation
**Setup**:
- Monthly expenses: ₹50,000
- Inflation: 10%
- Nominal return: 12%

**Expected Results**:
- Real return: ~1.8%
- FIRE number: ~₹18,30,000 (same in today's money)
- Required savings: Much higher (due to low real return)

**Test Steps**:
1. [ ] Update settings with 10% inflation
2. [ ] Verify real return is calculated correctly
3. [ ] Check required savings increase

**Verification**:
- [ ] Real return calculation is correct
- [ ] Required savings reflect low real return
- [ ] User understands why savings are higher

### Scenario 4: Existing User Migration
**Setup**:
- User with existing FIRE settings
- Old calculation showed ₹4.8cr FIRE number

**Expected Results**:
- FIRE number updates to ~₹1.5cr
- Progress percentage increases
- Required savings decrease
- No errors or data loss

**Test Steps**:
1. [ ] Load existing user data
2. [ ] Verify automatic recalculation
3. [ ] Check all values update correctly
4. [ ] Ensure no data corruption

**Verification**:
- [ ] Migration is seamless
- [ ] User data is preserved
- [ ] Calculations are correct

## 🎨 UI/UX Testing

### Test 1: FIRE Dashboard
**Checks**:
- [ ] FIRE number displays with "in today's money" subtitle
- [ ] Tooltip shows both today's and future values
- [ ] Coast FIRE tooltip mentions real returns
- [ ] All numbers are formatted correctly
- [ ] Privacy mask works on sensitive data

### Test 2: FIRE Stats Card
**Checks**:
- [ ] FIRE Number row shows correct value
- [ ] Tooltip is informative and accurate
- [ ] Coast FIRE explanation is clear
- [ ] Barista FIRE calculation is correct
- [ ] Icons and colors are appropriate

### Test 3: Tooltips and Help Text
**Checks**:
- [ ] Tooltips explain real vs nominal returns
- [ ] "In today's money" is clearly explained
- [ ] Future value is shown for context
- [ ] Fisher equation is mentioned (optional)
- [ ] User can understand the calculation

## 🔍 Edge Cases

### Edge Case 1: Very High Inflation
- Inflation: 20%, Nominal: 12%
- Expected: Negative real return, very high required savings
- [ ] Handles gracefully without errors

### Edge Case 2: Inflation > Nominal Return
- Inflation: 15%, Nominal: 12%
- Expected: Negative real return
- [ ] Calculation still works
- [ ] User is warned about unrealistic assumptions

### Edge Case 3: Very Long Time Horizon
- Years to FIRE: 40
- Expected: Large inflation multiplier
- [ ] No overflow errors
- [ ] Calculations remain accurate

### Edge Case 4: Very Short Time Horizon
- Years to FIRE: 1
- Expected: Minimal inflation impact
- [ ] Calculations are correct
- [ ] No division by zero

## 📊 Performance Testing

### Test 1: Calculation Speed
- [ ] FIRE calculation completes in <100ms
- [ ] No UI lag when updating settings
- [ ] Projections generate quickly

### Test 2: Memory Usage
- [ ] No memory leaks
- [ ] Efficient calculation
- [ ] Proper disposal of resources

## 🐛 Regression Testing

### Test 1: Other Features
- [ ] Investment tracking still works
- [ ] Goal tracking unaffected
- [ ] Overview screen displays correctly
- [ ] Notifications still trigger

### Test 2: Data Persistence
- [ ] FIRE settings save correctly
- [ ] Settings load on app restart
- [ ] Sync works across devices

## ✅ Acceptance Criteria

### Must Pass
- [x] All unit tests pass
- [ ] Manual test scenarios pass
- [ ] No regressions in other features
- [ ] UI is clear and understandable
- [ ] Documentation is complete

### Should Pass
- [ ] Performance is acceptable
- [ ] Edge cases handled gracefully
- [ ] User feedback is positive
- [ ] No confusion about new calculation

## 📝 Test Results

### Summary
- **Total Tests**: ___
- **Passed**: ___
- **Failed**: ___
- **Blocked**: ___

### Issues Found
1. ___
2. ___
3. ___

### Sign-Off
- [ ] QA Engineer: _______________
- [ ] Product Owner: _______________
- [ ] Tech Lead: _______________

---

**Status**: Ready for Testing
**Priority**: CRITICAL
**Estimated Time**: 2-3 hours

