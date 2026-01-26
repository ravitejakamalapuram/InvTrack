# InvTrack - Code Review Action Items

> Generated from comprehensive codebase review against InvTrack Enterprise Rules
> Date: 2026-01-26

---

## P0 - Critical (Block Release)

### 1. Split Oversized Files (Rule 1.3)

**25+ files exceed size limits. Refactor into smaller, focused components.**

#### Screens (Max: 500 lines)

| File | Lines | Over By |
|------|-------|---------|
| `lib/features/investment/presentation/screens/investment_detail_screen.dart` | 864 | +364 |
| `lib/features/settings/presentation/screens/data_management_screen.dart` | 749 | +249 |
| `lib/features/fire_number/presentation/screens/fire_dashboard_screen.dart` | 642 | +142 |
| `lib/features/goals/presentation/screens/goal_details_screen.dart` | 633 | +133 |
| `lib/features/investment/presentation/screens/investment_list_screen.dart` | 610 | +110 |
| `lib/features/goals/presentation/screens/goals_screen.dart` | 539 | +39 |
| `lib/features/goals/presentation/screens/create_goal_screen.dart` | 511 | +11 |
| `lib/features/fire_number/presentation/screens/fire_setup_screen.dart` | 510 | +10 |

#### Providers (Max: 200 lines)

| File | Lines | Over By |
|------|-------|---------|
| `lib/features/investment/presentation/providers/investment_notifier.dart` | 780 | +580 |
| `lib/features/goals/presentation/providers/goal_progress_provider.dart` | 379 | +179 |
| `lib/features/investment/presentation/providers/investment_list_state_provider.dart` | 332 | +132 |
| `lib/features/investment/presentation/providers/investment_stats_provider.dart` | 284 | +84 |
| `lib/features/security/presentation/providers/security_provider.dart` | 282 | +82 |
| `lib/features/goals/presentation/providers/goals_provider.dart` | 282 | +82 |
| `lib/features/investment/presentation/providers/investment_analytics_provider.dart` | 212 | +12 |
| `lib/features/investment/presentation/providers/document_notifier.dart` | 209 | +9 |

#### Widgets (Max: 300 lines)

| File | Lines | Over By |
|------|-------|---------|
| `lib/features/investment/presentation/widgets/add_document_sheet.dart` | 957 | +657 |
| `lib/features/investment/presentation/widgets/investment_card.dart` | 640 | +340 |
| `lib/features/overview/presentation/widgets/overview_analytics.dart` | 554 | +254 |
| `lib/core/widgets/premium_animations.dart` | 463 | +163 |
| `lib/features/overview/presentation/widgets/hero_card.dart` | 389 | +89 |
| `lib/features/investment/presentation/widgets/investment_detail_stats_section.dart` | 386 | +86 |
| `lib/core/widgets/loading_skeletons.dart` | 362 | +62 |
| `lib/features/investment/presentation/widgets/document_list_widget.dart` | 345 | +45 |

#### Repositories (Max: 400 lines)

| File | Lines | Over By |
|------|-------|---------|
| `lib/features/investment/data/repositories/firestore_investment_repository.dart` | 576 | +176 |

#### Models/Entities (Max: 150 lines)

| File | Lines | Over By |
|------|-------|---------|
| `lib/features/investment/domain/entities/investment_entity.dart` | 322 | +172 |
| `lib/features/goals/domain/entities/goal_entity.dart` | 317 | +167 |
| `lib/features/fire_number/domain/entities/fire_settings_entity.dart` | 317 | +167 |
| `lib/features/investment/domain/entities/document_entity.dart` | 225 | +75 |
| `lib/features/investment/domain/entities/investment_stats.dart` | 207 | +57 |

**Suggested Approach:**
- Extract reusable widgets from large screens
- Split notifiers by domain concern (e.g., `InvestmentCrudNotifier`, `InvestmentAnalyticsNotifier`)
- Move helper methods to separate utility classes

---

### 2. Add Localization Support (Rule 7.1)

**No ARB files found. All strings are hardcoded.**

**Action Items:**
- [ ] Create `lib/l10n/` directory
- [ ] Add `app_en.arb` with all English strings
- [ ] Configure `flutter_localizations` in `pubspec.yaml`
- [ ] Add `l10n.yaml` configuration file
- [ ] Replace hardcoded strings with `AppLocalizations.of(context).stringKey`
- [ ] Consider adding support for additional languages

---

## P1 - High Priority

### 3. Implement `ref.select` for Performance (Rule 6.1)

**0 instances of `ref.select` found. Watching entire providers causes unnecessary rebuilds.**

**Action Items:**
- [ ] Audit all `ref.watch(provider)` calls
- [ ] Replace with `ref.watch(provider.select((s) => s.specificField))` where only specific fields are needed
- [ ] Priority files:
  - `investment_list_screen.dart`
  - `goals_screen.dart`
  - `overview_screen.dart`

**Example:**
```dart
// Before (rebuilds on any state change)
final state = ref.watch(investmentListStateProvider);

// After (rebuilds only when filter changes)
final filter = ref.watch(investmentListStateProvider.select((s) => s.filter));
```

---

### 4. Add `.autoDispose` to Screen-Specific Providers (Rule 6.2)

**Only 5 instances of `.autoDispose` found. Screen-specific providers should auto-dispose.**

**Action Items:**
- [ ] Audit providers used only in single screens
- [ ] Add `.autoDispose` modifier to prevent memory leaks
- [ ] Priority providers:
  - Form state providers
  - Screen-specific filter/sort providers
  - Temporary UI state providers

---

## P2 - Medium Priority

### 5. Fix Deprecated API Usage in Tests

**6 info-level warnings for deprecated `hasFlag` API.**

**Files to update:**
- [ ] `test/features/investment/presentation/screens/investment_list_a11y_test.dart:105`
- [ ] `test/features/onboarding/presentation/screens/onboarding_screen_test.dart:40,41,47,60,61`

**Fix:** Replace `hasFlag` with `flagsCollection` as per Flutter 3.32+ deprecation.

---

## Passing Checks ✅

The following areas passed review:

- ✅ Static Analysis (Rule 2.1) - No errors/warnings
- ✅ Layer Boundaries (Rule 1.1) - No API calls in widgets
- ✅ Ref Usage (Rule 3.2) - `ref.read` only in callbacks
- ✅ AsyncValue Handling (Rule 3.3) - Proper `.when()` pattern
- ✅ Strong Typing (Rule 2.3) - Minimal `dynamic` usage
- ✅ Security Debug Logs (Rule 5.1) - All wrapped in `kDebugMode`
- ✅ Sensitive Data Storage (Rule 5.1) - FlutterSecureStorage + SHA-256
- ✅ Analytics Privacy (Rule 9.2) - Amount ranges, not exact values
- ✅ Resource Management (Rule 6.2) - Controllers disposed properly
- ✅ const Constructors (Rule 6.1) - 422 usages
- ✅ ListView.builder (Rule 6.1) - 16 instances
- ✅ Tooltips & Semantics (Rule 7.2) - Good accessibility coverage

