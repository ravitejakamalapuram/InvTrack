# GitHub Issue - Domain Localization (V2)

**Title**: [V2] Refactor domain layer to support full localization

**Labels**: enhancement, v2, localization, breaking-change

**Milestone**: V2 - Multi-Language Support

---

## 📋 **Issue Description**

Refactor the Portfolio Health Score domain layer to support full localization by returning stable keys instead of hardcoded English strings.

**Background**: During V1 development (PR #322), CodeRabbit identified that `ComponentScore` in the domain layer contains hardcoded English strings. This was deferred to V2 because:
- UI layer is 100% localized (users see zero hardcoded strings)
- Requires breaking API changes
- Better suited for post-V1 feedback

**Reference**: `docs/DOMAIN_LOCALIZATION_DECISION.md`

---

## 🎯 **Goals**

1. Move all hardcoded strings from domain layer to ARB files
2. Return stable identifiers/keys from domain logic
3. Map keys to localized strings in presentation layer
4. Maintain backward compatibility during migration
5. Support multiple languages (Hindi, Tamil, etc.)

---

## 🔧 **Technical Changes Required**

### **1. Entity Refactor - `ComponentScore`**

**Current (V1)**:
```dart
class ComponentScore {
  final String name;              // "Returns Performance"
  final String description;       // "XIRR vs Inflation"
  final List<String> suggestions; // ["Excellent returns!"]
}
```

**Proposed (V2)**:
```dart
class ComponentScore {
  final String nameKey;              // "returns_performance"
  final String? descriptionKey;      // "returns_vs_inflation"
  final List<String> suggestionKeys; // ["suggestion_excellent_returns"]
  
  // Deprecated - backward compatibility
  @Deprecated('Use nameKey with AppLocalizations')
  final String? name;
  
  @Deprecated('Use descriptionKey with AppLocalizations')
  final String? description;
}
```

### **2. Calculator Updates - `PortfolioHealthCalculator`**

Update all component calculation methods:
- `_calculateReturnsScore()` - Return keys for suggestions
- `_calculateDiversificationScore()` - Return keys for suggestions
- `_calculateLiquidityScore()` - Return keys for suggestions
- `_calculateGoalAlignmentScore()` - Return keys for suggestions
- `_calculateActionReadinessScore()` - Return keys for suggestions

### **3. ARB Entries - Add ~50 New Keys**

Example:
```json
{
  "componentReturnsPerformance": "Returns Performance",
  "componentDiversification": "Diversification",
  "suggestionExcellentReturns": "Excellent returns! Keep up the good work",
  "suggestionBelowInflation": "Returns below inflation. Your money is losing value",
  ...
}
```

### **4. Presentation Layer Mapping**

**Current**:
```dart
Text(score.returnsPerformance.name)
Text(score.returnsPerformance.suggestions[0])
```

**Proposed**:
```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.componentName(score.returnsPerformance.nameKey))
Text(score.returnsPerformance.suggestions.map((key) => l10n.suggestion(key)))
```

### **5. Firestore Migration**

If `HealthScoreSnapshotModel` persists `ComponentScore`:
- Add migration to handle both old/new formats
- Gradual deprecation over 2-3 releases
- Clear migration path for existing data

---

## 📝 **Implementation Plan**

### **Phase 1: Preparation** (Week 1)
- [ ] Audit all hardcoded strings in domain layer
- [ ] Create comprehensive ARB key mapping
- [ ] Design backward-compatible API
- [ ] Write migration strategy

### **Phase 2: Entity Refactor** (Week 2)
- [ ] Update `ComponentScore` with new fields
- [ ] Add deprecation warnings to old fields
- [ ] Update unit tests
- [ ] Verify backward compatibility

### **Phase 3: Calculator Updates** (Week 3)
- [ ] Refactor `_calculateReturnsScore()`
- [ ] Refactor `_calculateDiversificationScore()`
- [ ] Refactor `_calculateLiquidityScore()`
- [ ] Refactor `_calculateGoalAlignmentScore()`
- [ ] Refactor `_calculateActionReadinessScore()`
- [ ] Add all ARB entries (~50 keys)
- [ ] Generate l10n

### **Phase 4: Presentation Updates** (Week 4)
- [ ] Update all UI consumers to use keys
- [ ] Test with multiple languages
- [ ] Update accessibility labels
- [ ] Verify no hardcoded strings remain

### **Phase 5: Migration & Cleanup** (Week 5)
- [ ] Add Firestore migration (if needed)
- [ ] Monitor production for issues
- [ ] Remove deprecated fields (after 2-3 releases)
- [ ] Update documentation

---

## ✅ **Acceptance Criteria**

- [ ] Zero hardcoded English strings in domain layer
- [ ] All suggestions returned as keys
- [ ] All component names/descriptions as keys
- [ ] Presentation layer maps keys to localized strings
- [ ] Backward compatibility maintained during migration
- [ ] ARB files contain all domain strings
- [ ] Multiple languages supported (Hindi, Tamil)
- [ ] Zero analyzer errors/warnings
- [ ] All tests passing
- [ ] Documentation updated

---

## 🔗 **Related**

- **PR #322**: Portfolio Health Score V1 (where this was deferred)
- **CodeRabbit Comment #36**: Original identification
- **Doc**: `docs/DOMAIN_LOCALIZATION_DECISION.md`

---

## 📊 **Estimated Effort**

- **Development**: 3-4 hours
- **Testing**: 1-2 hours
- **Migration**: 1 hour
- **Total**: 5-7 hours

---

## 🎯 **Priority**

**Priority**: Medium  
**Milestone**: V2  
**Blocked By**: V1 launch + user feedback  
**Blocks**: Full multi-language support

---

## 💡 **Notes**

- This is a breaking change - plan for major version bump
- Consider lessons learned from V1 before implementing
- User feedback may inform string wording
- May want to batch with other i18n improvements
