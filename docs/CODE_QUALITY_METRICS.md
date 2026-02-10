# Code Quality Metrics - InvTrack

## Overview

InvTrack uses **industry-standard quality metrics** instead of arbitrary file size limits. This document explains what we measure and why it matters.

---

## 🎯 Why We Changed

### ❌ Old Approach: File Size Limits
- **Problem**: Lines of code ≠ code quality
- **Issue**: 25+ files exceeded limits (unrealistic thresholds)
- **Result**: Busywork splitting files that didn't need splitting

### ✅ New Approach: Quality Metrics
- **Cyclomatic Complexity**: Measures actual code complexity
- **Code Coverage**: Ensures code is tested
- **Architecture Boundaries**: Enforces Clean Architecture
- **Static Analysis**: Catches real bugs

---

## 📊 Metrics We Enforce

### 1. Cyclomatic Complexity

**What It Measures:**
- Number of decision points in code
- Counts: `if`, `for`, `while`, `switch`, `&&`, `||`, `??`, `? :`

**Thresholds:**
- **<10**: Simple, easy to test ✅
- **10-15**: Moderate complexity ⚠️
- **15-20**: High complexity, consider refactoring 🔶
- **>20**: Critical, must refactor before merge ❌

**Why It Matters:**
- High complexity = more bugs
- High complexity = harder to test
- High complexity = harder to maintain
- Industry-standard metric (used by Google, Microsoft, etc.)

**Example:**
```dart
// BAD: Complexity = 8
if (user != null && user.isActive && user.hasPermission('edit') && 
    document != null && !document.isLocked && document.owner == user.id) {
  // complex logic
}

// GOOD: Complexity = 1
final canEdit = _canUserEditDocument(user, document);
if (canEdit) {
  // complex logic
}
```

---

### 2. Code Coverage

**What It Measures:**
- Percentage of code executed by tests
- Line coverage, branch coverage

**Thresholds:**
- **Minimum**: 60% (enforced by CI) ❌
- **Target**: 80% for new code ✅
- **Ideal**: 90% for critical business logic 🌟

**What Must Be Tested:**
- ✅ All business logic (domain layer)
- ✅ All data transformations
- ✅ All validation logic
- ✅ All error handling paths
- ✅ Bug fixes (regression tests)

**What Can Be Skipped:**
- ⏭️ UI widgets (use widget tests)
- ⏭️ Generated code (`*.g.dart`)
- ⏭️ Simple getters/setters

**Why It Matters:**
- Catches bugs before production
- Enables confident refactoring
- Documents expected behavior
- Reduces debugging time

**Running Coverage:**
```bash
# Generate coverage
flutter test --coverage

# View summary
lcov --summary coverage/lcov.info

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

### 3. Architecture Boundaries

**What It Checks:**
- ❌ No API calls in widgets (should be in repositories)
- ❌ No navigation in domain layer (should be in presentation)
- ❌ No `ref.read` in build methods (use `ref.watch`)
- ❌ No business logic in widgets (should be in domain)

**Why It Matters:**
- Enforces Clean Architecture
- Makes code testable
- Separates concerns
- Improves maintainability

**Clean Architecture Layers:**
```
UI (Presentation) → State (Providers) → Domain (Business Logic) → Data (Repositories)
```

---

### 4. Static Analysis

**What It Checks:**
- Dart analyzer errors/warnings
- Linting rules
- Type safety
- Unused code

**Threshold:**
- **Zero errors/warnings** ❌

**Why It Matters:**
- Catches bugs at compile time
- Enforces best practices
- Improves code consistency
- Prevents runtime errors

**Running Analysis:**
```bash
flutter analyze
dart fix --apply  # Auto-fix issues
```

---

## 🚀 How CI Enforces These

### Automated Checks (Every PR)

1. **Static Analysis** (`flutter analyze`)
   - Must pass with zero errors/warnings

2. **Cyclomatic Complexity**
   - Warns if >15 per 100 lines
   - Fails if >20 per 100 lines

3. **Code Coverage**
   - Warns if <60%
   - Fails if <60% (enforced)

4. **Architecture Boundaries**
   - Scans for violations
   - Fails if violations found

5. **All Tests**
   - Must pass 100%
   - Bug fixes must include tests

---

## 💡 Best Practices

### Reducing Complexity

1. **Extract Complex Conditions**
   ```dart
   // Before
   if (a && b && c && d) { }
   
   // After
   final isValid = _checkValidity(a, b, c, d);
   if (isValid) { }
   ```

2. **Use Early Returns**
   ```dart
   // Before
   if (condition) {
     // 50 lines
   } else {
     return;
   }
   
   // After
   if (!condition) return;
   // 50 lines
   ```

3. **Break Large Functions**
   - Functions >50 lines should be reviewed
   - Extract logical chunks into helper methods

### Improving Coverage

1. **Test Business Logic First**
   - Domain layer is most critical
   - Services and repositories next
   - UI last (use widget tests)

2. **Test Edge Cases**
   - Null values
   - Empty lists
   - Boundary conditions
   - Error paths

3. **Write Meaningful Tests**
   - Test behavior, not implementation
   - Use descriptive test names
   - Keep tests independent

---

## 📈 Monitoring Quality

### View Current Metrics

```bash
# Complexity (manual check)
grep -rn "if\|for\|while\|switch" lib/ --include="*.dart" | wc -l

# Coverage
flutter test --coverage
lcov --summary coverage/lcov.info

# Static Analysis
flutter analyze
```

### CI Dashboard

Check PR comments for automated quality report:
- ✅ All checks passing
- ⚠️ Warnings (review recommended)
- ❌ Failures (must fix before merge)

---

## 🎓 Further Reading

- [Cyclomatic Complexity](https://en.wikipedia.org/wiki/Cyclomatic_complexity)
- [Code Coverage Best Practices](https://martinfowler.com/bliki/TestCoverage.html)
- [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Dart Linting](https://dart.dev/guides/language/analysis-options)

