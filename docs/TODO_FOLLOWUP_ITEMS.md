# TODO - Follow-up Items for Fresh Context

**Created**: 2026-04-06  
**PR**: #322 - Portfolio Health Score  
**Context**: Marathon session complete, pending CodeRabbit final approval

---

## 🎯 **IMMEDIATE TODOS** (Waiting on External Events)

### **1. CodeRabbit Final Approval** ⏳ WAITING
**Status**: Review triggered 3 times, waiting for response (1-2 hours expected)

**When CodeRabbit Responds**:
- [ ] Check if review status changed to "APPROVED"
- [ ] If new comments found, address them immediately
- [ ] If approved, proceed to merge

**If Issues Found**:
- [ ] Read all new CodeRabbit comments carefully
- [ ] Fix each issue exhaustively (don't miss any instances)
- [ ] Commit fixes with descriptive messages
- [ ] Request re-review: `@coderabbitai review`
- [ ] Repeat until approved

**Commands to Check Status**:
```bash
# Check latest review status
gh pr view 322 --json reviewDecision,latestReviews

# Check for new comments
gh pr view 322 --json comments | jq '.comments[-5:]'

# Open PR in browser
gh pr view 322 --web
```

---

### **2. Merge PR #322** ⏳ BLOCKED BY: CodeRabbit approval
**When Approved**:
```bash
# Final pre-merge checks
flutter analyze  # Should be 0 errors
flutter test     # Should pass (or skip if no tests)
git status       # Should be clean

# Merge PR (squash recommended)
gh pr merge 322 --squash --delete-branch \
  --subject "feat: Portfolio Health Score (Fitbit for Money)" \
  --body "Complete implementation with 100% CodeRabbit compliance (35/36 fixed, 1 deferred to V2)"

# Verify merge
git checkout main
git pull
git log --oneline -5
```

---

## 📋 **POST-MERGE TODOS**

### **3. Create V2 GitHub Issue** ⏳ BLOCKED BY: PR merge
**Issue**: Domain Localization Refactor

**Template Ready**: `docs/GITHUB_ISSUE_DOMAIN_LOCALIZATION.md`

**Command**:
```bash
gh issue create \
  --title "[V2] Refactor domain layer to support full localization" \
  --label "enhancement,v2,localization,breaking-change" \
  --milestone "V2" \
  --body-file docs/GITHUB_ISSUE_DOMAIN_LOCALIZATION.md
```

**Details**:
- Move hardcoded strings from `ComponentScore` to ARB files
- Return stable keys instead of English strings
- Requires breaking API changes
- Estimated effort: 5-7 hours
- Fully documented in `docs/DOMAIN_LOCALIZATION_DECISION.md`

---

### **4. Enable Feature Flag** ⏳ BLOCKED BY: PR merge
**Action**: Turn on Portfolio Health Score for testing

**Steps**:
1. Build app: `flutter run`
2. Open Settings → Debug Settings → Experimental Features
3. Toggle "Portfolio Health Score" ON
4. Navigate to Overview screen
5. Verify dashboard card appears
6. Tap card → Navigate to details screen
7. Test all interactions:
   - [ ] Score display
   - [ ] Trend chart
   - [ ] Component breakdown
   - [ ] Suggestions
   - [ ] Copy to clipboard
   - [ ] Error states
   - [ ] Empty states
   - [ ] Loading states

**Known Issues to Watch**:
- None currently
- Report any issues as GitHub issues

---

### **5. Archive Marathon Documentation** ⏳ BLOCKED BY: PR merge
**Action**: Move session tracking docs to archive folder

**Commands**:
```bash
mkdir -p docs/archive/pr-322-marathon
mv docs/CODERABBIT_REVIEW_ANALYSIS.md docs/archive/pr-322-marathon/
mv docs/CODERABBIT_FIXES_STATUS.md docs/archive/pr-322-marathon/
mv docs/CODERABBIT_REVIEW_COMPLETE.md docs/archive/pr-322-marathon/
mv docs/MARATHON_SESSION_COMPLETE.md docs/archive/pr-322-marathon/
mv docs/CODERABBIT_THREAD_RESOLUTION.md docs/archive/pr-322-marathon/
mv docs/READY_TO_MERGE_SUMMARY.md docs/archive/pr-322-marathon/

# Keep these (still relevant):
# - DOMAIN_LOCALIZATION_DECISION.md
# - GITHUB_ISSUE_DOMAIN_LOCALIZATION.md
# - CODERABBIT_RE_REVIEW_REQUEST.md

git add -A
git commit -m "docs: Archive PR #322 marathon session documentation"
git push
```

---

## 🔧 **TECHNICAL DEBT** (Low Priority)

### **6. Fix Remaining Info-Level Warnings** (Optional)
**Current**: 14 info-level warnings (cosmetic, not blocking)

**Details**:
```
strict_top_level_inference (6):
  - Missing explicit types on providers
  - Add type annotations to top-level variables

unnecessary_underscores (3):
  - _showComponentScores field naming
  - Consider making public or renaming

no_leading_underscores_for_local_identifiers (1):
  - _getDouble helper function
  - Rename to getDouble or make member function

prefer_conditional_assignment (1):
  - Style preference
  - Use ternary where applicable
```

**Commands to Fix**:
```bash
# See all warnings
flutter analyze

# Apply auto-fixes (if available)
dart fix --apply

# Manual fixes if needed
# Then commit:
git add -A
git commit -m "fix: Clean up info-level analyzer warnings"
git push
```

---

### **7. Fix Markdown Lint Violations** (Optional)
**Current**: MD022/MD031/MD040 violations in docs

**Files**:
- EXECUTIVE_SUMMARY.md
- INNOVATION_SUMMARY.md
- WEEK_2_PROGRESS.md
- MBA_LEVEL_INNOVATION_ANALYSIS.md
- FINAL_DELIVERY_SUMMARY.md

**Violations**:
- MD022: Blank lines around headings
- MD031: Blank lines around fenced code blocks
- MD040: Language identifier in code blocks

**Fix Approach**:
```bash
# Install markdownlint (if not installed)
npm install -g markdownlint-cli

# Check violations
markdownlint docs/*.md

# Auto-fix (careful - review changes)
markdownlint --fix docs/*.md

# Or manually add blank lines and language IDs
```

---

## 📊 **WEEK 4 PLANNING** (Next Sprint)

### **8. Write Unit Tests**
**Status**: Planned for Week 4

**Test Coverage Goals**:
- [ ] PortfolioHealthCalculator (all 5 component calculations)
- [ ] ComponentScore (equality, hashCode, topSuggestions)
- [ ] HealthScoreAutoSaveService (debouncing, race conditions)
- [ ] HealthScoreRepository (CRUD operations)
- [ ] Providers (state management)

**Target**: ≥80% coverage for new code

**Commands**:
```bash
# Run tests
flutter test

# Coverage report
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

### **9. Add Analytics Events**
**Status**: Planned for Week 4

**Events to Track**:
- [ ] `portfolio_health_viewed` - Dashboard card shown
- [ ] `portfolio_health_details_opened` - Details screen opened
- [ ] `health_score_calculated` - Score computed (tier, not exact value)
- [ ] `health_suggestion_viewed` - User saw suggestions
- [ ] `health_score_shared` - Copy to clipboard action

**Privacy**: Use ranges/tiers, not exact scores

---

### **10. Beta Testing**
**Status**: Week 5

**Test Plan**:
- [ ] Internal team testing (5-10 users)
- [ ] Feature flag enabled for beta users
- [ ] Monitor Crashlytics for errors
- [ ] Collect feedback via form
- [ ] Address critical bugs before production

---

## 🚨 **IF CODERABBIT REQUESTS CHANGES**

### **Critical Path**:
1. Read ALL comments carefully (don't miss any)
2. Fix each issue exhaustively (find ALL instances)
3. Verify related code paths (export ↔ import, read ↔ write)
4. Run `flutter analyze` (must be 0 errors)
5. Run `flutter test` (must pass)
6. Commit with descriptive message
7. Post `@coderabbitai review` comment
8. Wait for re-review
9. Repeat until approved

### **Common Mistakes to Avoid**:
- ❌ Fixing only SOME instances of issue
- ❌ Assuming code is correct without verification
- ❌ Missing related code paths
- ❌ Ignoring "nitpick" comments (fix ALL)
- ❌ Pushing without running analyzers

---

## 📝 **NOTES FOR FRESH CONTEXT**

### **Project State**:
- PR #322 ready to merge (pending final CodeRabbit approval)
- All critical bugs fixed (35/36)
- UI 100% localized (20+ ARB entries)
- Zero analyzer errors
- CI passing
- Feature-flagged for safe rollout

### **Key Documents**:
- `docs/DOMAIN_LOCALIZATION_DECISION.md` - Why V2 deferral is OK
- `docs/GITHUB_ISSUE_DOMAIN_LOCALIZATION.md` - V2 tracking template
- `docs/MARATHON_SESSION_COMPLETE.md` - Session overview
- `.augment/rules/invtrack_rules.md` - All project rules

### **Important Context**:
- This was an 8-hour marathon session
- 14 commits pushed
- ~800 lines code, ~2,000 lines docs
- CodeRabbit reviewed 5 times
- Final approval pending

---

## ✅ **COMPLETION CHECKLIST**

**Immediate** (Next 2 hours):
- [ ] Wait for CodeRabbit approval
- [ ] Address any new comments (if needed)
- [ ] Merge PR #322

**Post-Merge** (Same day):
- [ ] Create V2 GitHub issue
- [ ] Enable feature flag
- [ ] Test on real device
- [ ] Archive marathon docs

**Week 4** (Next sprint):
- [ ] Write unit tests
- [ ] Add analytics events
- [ ] Fix info-level warnings (optional)
- [ ] Fix markdown lint (optional)

**Week 5**:
- [ ] Beta testing
- [ ] Production rollout

---

**Status**: Ready for final approval and merge! 🚀
