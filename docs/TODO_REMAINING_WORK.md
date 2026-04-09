# TODO - Remaining Work for Fresh Context

**Date Created**: 2026-04-06  
**Context**: Marathon session complete, some items skipped/deferred  
**Purpose**: Track all remaining work for completion in new context

---

## 🎯 **IMMEDIATE ACTIONS** (Do First)

### 1. ✅ Wait for CodeRabbit Approval
**Status**: Review triggered, waiting for response  
**Timeline**: 1-2 hours  
**Action**: Monitor PR #322 for CodeRabbit approval

**If approved**:
- Merge PR #322 using squash merge
- Delete feature branch
- Proceed to Post-Merge tasks

**If changes requested**:
- Address new comments
- Re-trigger review
- Repeat until approved

---

## 📋 **POST-MERGE TASKS** (After PR #322 merges)

### 2. Create V2 GitHub Issue for Domain Localization
**Priority**: Medium  
**Estimated Time**: 5 minutes  
**Template**: `docs/GITHUB_ISSUE_DOMAIN_LOCALIZATION.md`

**Command**:
```bash
gh issue create \
  --title "[V2] Refactor domain layer to support full localization" \
  --label "enhancement,v2,localization,breaking-change" \
  --milestone "V2" \
  --body-file docs/GITHUB_ISSUE_DOMAIN_LOCALIZATION.md
```

**What it tracks**:
- Moving hardcoded strings from domain to ARB files
- ComponentScore API refactor
- 50+ new ARB entries
- Presentation layer mapping
- Estimated effort: 5-7 hours

---

### 3. Archive Marathon Session Documentation
**Priority**: Low  
**Estimated Time**: 10 minutes  
**Reason**: Keep docs/ clean for production

**Files to archive** (move to `docs/archive/marathon-2026-04-06/`):
```
docs/CODERABBIT_REVIEW_ANALYSIS.md
docs/READY_TO_MERGE_SUMMARY.md
docs/CODERABBIT_FIXES_STATUS.md
docs/CODERABBIT_REVIEW_COMPLETE.md
docs/CODERABBIT_THREAD_RESOLUTION.md
docs/CODERABBIT_RE_REVIEW_REQUEST.md
docs/MARATHON_SESSION_COMPLETE.md
```

**Keep in docs/**:
```
docs/DOMAIN_LOCALIZATION_DECISION.md (reference for V2)
docs/GITHUB_ISSUE_DOMAIN_LOCALIZATION.md (V2 template)
```

**Command**:
```bash
mkdir -p docs/archive/marathon-2026-04-06
mv docs/CODERABBIT_*.md docs/archive/marathon-2026-04-06/
mv docs/READY_TO_MERGE_SUMMARY.md docs/archive/marathon-2026-04-06/
mv docs/MARATHON_SESSION_COMPLETE.md docs/archive/marathon-2026-04-06/
git add -A
git commit -m "docs: Archive marathon session documentation"
git push
```

---

### 4. Clean Up Markdown Lint Violations (Optional)
**Priority**: Low  
**Estimated Time**: 15 minutes  
**Reason**: CodeRabbit flagged these as "cosmetic"

**Files with violations**:
- `docs/EXECUTIVE_SUMMARY.md` (MD022 - blank lines around headings)
- `docs/INNOVATION_SUMMARY.md` (MD022, MD031)
- `docs/WEEK_2_PROGRESS.md` (MD022, MD031, MD040)
- `docs/MBA_LEVEL_INNOVATION_ANALYSIS.md` (MD022)
- `docs/FINAL_DELIVERY_SUMMARY.md` (MD040 - code block language)

**Rules to fix**:
- MD022: Blank line before/after headings
- MD031: Blank lines around fenced code blocks
- MD040: Specify language for code blocks

**Tool**:
```bash
# Install markdownlint-cli if needed
npm install -g markdownlint-cli

# Fix automatically
markdownlint --fix docs/*.md

# Verify
markdownlint docs/*.md
```

---

## 🚀 **WEEK 4 TASKS** (Next Sprint)

### 5. Write Comprehensive Unit Tests
**Priority**: High  
**Estimated Time**: 3-4 hours  
**Coverage Target**: ≥80% for new code

**Test files to create**:
```
test/features/portfolio_health/domain/services/portfolio_health_calculator_test.dart
test/features/portfolio_health/domain/entities/portfolio_health_score_test.dart
test/features/portfolio_health/data/repositories/health_score_repository_test.dart
test/features/portfolio_health/data/services/health_score_auto_save_service_test.dart
test/features/portfolio_health/data/models/health_score_snapshot_model_test.dart
```

**Test coverage for**:
- All 5 component score calculations
- Edge cases (empty portfolio, negative XIRR, etc.)
- Score tier classification
- Suggestion generation
- Auto-save debouncing
- Firestore serialization/deserialization
- Repository pagination
- Error handling

**Run tests**:
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

### 6. Add Analytics Events
**Priority**: Medium  
**Estimated Time**: 1 hour

**Events to add**:
```dart
// When user views dashboard
AnalyticsService().logEvent('portfolio_health_viewed', {
  'score_tier': scoreTier.name,
  'score_range': scoreRange,
});

// When user views details
AnalyticsService().logEvent('portfolio_health_details_viewed', {
  'score_tier': scoreTier.name,
});

// When user shares score
AnalyticsService().logEvent('portfolio_health_shared', {
  'score_tier': scoreTier.name,
});

// When feature is toggled
AnalyticsService().logEvent('portfolio_health_toggled', {
  'enabled': enabled,
});
```

**Privacy-compliant ranges**:
```dart
final scoreRange = score >= 80 ? 'excellent'
    : score >= 60 ? 'good'
    : score >= 40 ? 'fair'
    : 'poor';
```

---

### 7. Enable Feature Flag for Internal Testing
**Priority**: High  
**Estimated Time**: 5 minutes  
**After**: PR merged + tests passing

**Steps**:
1. Open app in debug mode
2. Settings → Debug Settings → Experimental Features
3. Toggle "Portfolio Health Score" ON
4. Test on real device with real data
5. Monitor Crashlytics for errors
6. Gather feedback from team

**Rollout plan**:
- Week 4: Internal testing (5-10 users)
- Week 5: Beta testing (50-100 users)
- Week 6: Gradual rollout (10% → 50% → 100%)

---

## 📝 **DEFERRED V2 WORK** (Future Enhancement)

### 8. Domain Layer Localization
**Priority**: Medium (V2)  
**Estimated Time**: 5-7 hours  
**Tracked in**: GitHub issue (to be created in task #2)

**What it involves**:
- Refactor ComponentScore to use keys instead of strings
- Add 50+ ARB entries for suggestions
- Update presentation layer to map keys
- Maintain backward compatibility
- Firestore migration (if needed)

**See**: `docs/DOMAIN_LOCALIZATION_DECISION.md` for full justification

---

## ✅ **COMPLETION CHECKLIST**

Use this checklist to track progress in new context:

**Immediate** (Today):
- [ ] CodeRabbit approval received
- [ ] PR #322 merged to main
- [ ] Feature branch deleted
- [ ] V2 issue created

**Post-Merge** (This Week):
- [ ] Marathon docs archived
- [ ] Markdown lint violations fixed (optional)

**Week 4** (Next Sprint):
- [ ] Unit tests written (≥80% coverage)
- [ ] Analytics events added
- [ ] Feature flag enabled for internal testing
- [ ] Crashlytics monitored
- [ ] Team feedback gathered

**V2** (Future):
- [ ] Domain localization GitHub issue created
- [ ] Domain localization implemented
- [ ] Multi-language support launched

---

## 🎯 **SUCCESS CRITERIA**

**PR #322 Merged**: ✅ When approved by CodeRabbit  
**V2 Tracked**: ✅ When GitHub issue created  
**Tests Complete**: ✅ When coverage ≥80%  
**Production Ready**: ✅ When internal testing successful  

---

## 📞 **CONTEXT FOR NEW SESSION**

**Current Status**:
- 35/36 CodeRabbit comments fixed
- 1/36 deferred to V2 with full justification
- GitHub Actions passing
- Zero analyzer errors
- Waiting for CodeRabbit approval

**Key Documents**:
- `docs/DOMAIN_LOCALIZATION_DECISION.md` - Why V2
- `docs/GITHUB_ISSUE_DOMAIN_LOCALIZATION.md` - V2 template
- `docs/MARATHON_SESSION_COMPLETE.md` - Session summary

**Next Action**: Wait for CodeRabbit, then merge PR #322

---

**Created**: 2026-04-06  
**Status**: Ready for new context  
**Estimated Total Time**: 10-15 hours across Weeks 4-5
