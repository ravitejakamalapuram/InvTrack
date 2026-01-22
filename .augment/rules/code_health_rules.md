---
type: "always_apply"
---

# Code Health & Technical Debt Rules – InvTrack

These rules maintain code quality and prevent technical debt accumulation.

---

## CODE RULE 1: STATIC ANALYSIS
Before ANY commit or PR:
```bash
dart analyze
flutter analyze
```

Requirements:
- ❌ Zero errors
- ❌ Zero warnings (fix all, don't ignore)
- ⚠️ Infos should be reviewed and addressed

Never suppress warnings without documented justification.

---

## CODE RULE 2: LINTING COMPLIANCE
Follow `analysis_options.yaml` strictly:
- All lint rules are intentional
- No `// ignore:` comments without team approval
- Run `dart fix --apply` for auto-fixable issues
- Keep lint rules updated with Flutter releases

---

## CODE RULE 3: FILE SIZE LIMITS
| Type | Max Lines | Action if Exceeded |
|------|-----------|-------------------|
| Widget file | 300 | Split into smaller widgets |
| Provider file | 200 | Extract logic to service |
| Repository file | 400 | Split by domain concern |
| Model file | 150 | Check for god object |
| Test file | 500 | Split by test category |

---

## CODE RULE 4: FUNCTION COMPLEXITY
- Max function length: 50 lines
- Max parameters: 5 (use object for more)
- Max nesting depth: 3 levels
- Single responsibility per function
- Extract complex conditions to named booleans:
```dart
// ✅ Good
final isEligibleForDiscount = user.isPremium && order.total > 100;
if (isEligibleForDiscount) { ... }

// ❌ Bad
if (user.isPremium && order.total > 100 && !order.hasDiscount) { ... }
```

---

## CODE RULE 5: NAMING CONVENTIONS
| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `investment_repository.dart` |
| Classes | PascalCase | `InvestmentRepository` |
| Variables | camelCase | `investmentList` |
| Constants | camelCase or SCREAMING_CASE | `defaultTimeout` or `MAX_RETRIES` |
| Private | _prefix | `_privateMethod` |
| Providers | camelCase + Provider | `investmentProvider` |

---

## CODE RULE 6: TODO MANAGEMENT
TODO comments must include:
- Ticket reference (if applicable)
- Date added
- Owner

```dart
// TODO(ravi): Implement pagination - Issue #123 - 2024-01-15
```

Rules:
- No TODOs older than 2 weeks in production code
- Convert old TODOs to issues
- Review TODOs before each release

---

## CODE RULE 7: LOGGING DISCIPLINE
```dart
// ✅ Debug logging (stripped in release)
if (kDebugMode) {
  debugPrint('🔍 Investment loaded: ${investment.id}');
}

// ✅ Error logging (goes to Crashlytics)
CrashlyticsService().recordError(error, stack);

// ❌ Never use in production
print('Debug: $data');
```

Log levels:
- 🔍 Debug info
- ⚠️ Warnings
- 🔴 Errors
- 📦 Data operations

---

## CODE RULE 8: DEAD CODE REMOVAL
Remove immediately:
- Unused imports
- Unused variables
- Unused functions
- Commented-out code blocks
- Unreachable code
- Deprecated methods

Run regularly:
```bash
dart analyze --fatal-infos
```

---

## CODE RULE 9: IMPORT ORGANIZATION
Order imports:
1. Dart SDK (`dart:async`, `dart:io`)
2. Flutter SDK (`package:flutter/...`)
3. External packages (`package:riverpod/...`)
4. Project imports (`package:inv_tracker/...`)

Use relative imports within same feature:
```dart
import '../domain/entities/investment_entity.dart';
```

---

## CODE RULE 10: DOCUMENTATION REQUIREMENTS
Required documentation:
- Public APIs (classes, methods)
- Complex algorithms
- Non-obvious business logic
- Workarounds with reasoning

```dart
/// Calculates XIRR using Newton-Raphson method.
/// 
/// [cashFlows] must contain at least one positive and one negative value.
/// Returns null if calculation doesn't converge after [maxIterations].
double? calculateXirr(List<CashFlow> cashFlows, {int maxIterations = 100}) {
  // ...
}
```

---

## CODE RULE 11: ERROR MESSAGE QUALITY
User-facing errors must be:
- Clear and actionable
- Localized
- Not exposing technical details

```dart
// ✅ Good
'Unable to save. Please check your connection and try again.'

// ❌ Bad
'FirebaseException: PERMISSION_DENIED at /users/abc123/investments'
```

---

## CODE RULE 12: REFACTORING TRIGGERS
Refactor when:
- Same code appears 3+ times → Extract to shared function
- File exceeds size limit → Split by concern
- Function has 5+ parameters → Create parameter object
- Deep nesting (>3 levels) → Extract to separate functions
- Comments explain "what" not "why" → Code is unclear

