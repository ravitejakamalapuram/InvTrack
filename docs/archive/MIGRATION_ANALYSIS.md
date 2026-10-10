# InvTrack Migration to Centralized GitHub Actions

## 📊 Current Workflow Analysis

### CI Workflow (`ci.yml` - 88 lines)

#### ✅ Features Already Covered by Centralized Actions

1. **Flutter Setup** (lines 32-53)
   - ✅ Covered by: `flutter/setup` action
   - ✅ Includes pub cache corruption recovery (lines 44-53)

2. **Flutter Analyze** (lines 55-56)
   - ✅ Covered by: `flutter/analyze` action
   - ✅ Supports `--fatal-warnings` and `--no-fatal-infos`

3. **Flutter Test** (lines 58-59)
   - ✅ Covered by: `flutter/test` action
   - ⚠️ **CUSTOM REQUIREMENT**: `--exclude-tags=golden` (needs parameter)

#### ⚠️ Features NOT in Centralized Actions (Need Addition)

4. **Security Check** (lines 61-71)
   - ❌ NOT in centralized actions
   - Checks for:
     - Disabled SSL verification (`badCertificateCallback`, `allowInsecure`)
     - Print statements in production code
   - **ACTION NEEDED**: Add to `flutter/analyze` or create separate security action

5. **Architecture Check** (lines 73-83)
   - ✅ PARTIALLY covered by `flutter/analyze` (has architecture checks)
   - ⚠️ **DIFFERENCE**: Current checks are more specific:
     - API calls in widgets: `FirebaseFirestore|http.|dio.` in `lib/features/*/presentation/widgets/`
     - Navigation in domain: `Navigator|GoRouter|context.go` in `lib/features/*/domain/`
   - ✅ Centralized action checks:
     - API in widgets (generic check)
     - Navigation in domain (generic check)
     - UI in domain (additional check)
   - **ACTION NEEDED**: Verify centralized checks cover these patterns

#### 🔧 Environment & Configuration

- **Runner**: `self-hosted` ✅ Supported via `runner-type` input
- **Env var**: `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` ⚠️ Need to preserve
- **Concurrency**: `ci-${{ github.ref }}` with `cancel-in-progress: true` ✅ Can preserve
- **Skip drafts**: `github.event.pull_request.draft == false` ✅ Supported via conditions

---

### CD Workflow (`cd.yml` - 456 lines)

#### Job 1: bump-and-deploy (lines 65-297)

##### ✅ Features Covered

1. **Version Bump** (lines 116-162)
   - ✅ Covered by: `common/version-bump` action
   - ✅ Auto-detection from commit messages (BREAKING/feat/fix)
   - ✅ Semantic versioning (major/minor/patch)

2. **Changelog Generation** (lines 164-179)
   - ⚠️ **CUSTOM TOOL**: Uses `git-cliff` (not in centralized actions)
   - ❌ Centralized action uses git log, not git-cliff
   - **ACTION NEEDED**: Keep custom git-cliff steps OR accept centralized changelog format

3. **Flutter Build** (lines 224-226)
   - ✅ Covered by: `flutter/build-android` action
   - Type: appbundle ✅ Supported

4. **GitHub Release** (lines 272-285)
   - ✅ Covered by: `common/create-release` action

5. **Play Store Deploy** (lines 238-248)
   - ❌ NOT in centralized actions
   - Uses: `r0adkll/upload-google-play@v1`
   - **ACTION NEEDED**: This is complex, keep as custom step

##### ⚠️ InvTrack-Specific Features (Must Preserve)

6. **Skip Logic** (lines 74-86)
   - Skips on: `[skip-release]`, `chore(release)`, `chore:` in commit message
   - Not on `workflow_dispatch`
   - **ACTION NEEDED**: Preserve as custom condition

7. **Multi-File Version Update** (lines 181-205)
   - Updates `pubspec.yaml` ✅
   - Updates `lib/features/settings/presentation/screens/about_screen.dart` ❌ Custom
   - Updates fastlane changelog ❌ Custom
   - **ACTION NEEDED**: Keep as custom steps

8. **Signing Files** (lines 213-222)
   - Copies from `$HOME/invtrack-keys/` (self-hosted specific)
   - ❌ Centralized action uses secrets (base64)
   - **ACTION NEEDED**: Keep custom approach OR migrate to secrets

9. **App Size Tracking** (lines 228-236)
   - Tracks AAB size and reports in release
   - ❌ NOT in centralized actions
   - **ACTION NEEDED**: Keep as custom step

10. **Slack Notifications** (lines 287-297, 348-358, 445-455)
    - ❌ NOT in centralized actions
    - **ACTION NEEDED**: Keep as custom steps

11. **Git Commit & Push** (lines 250-270)
    - Commits version bump with `[skip-release]`
    - Uses PAT token to bypass branch protection
    - **ACTION NEEDED**: Keep as custom steps

#### Job 2: deploy-tag (lines 299-358)
- Manual deploy of specific tag
- ✅ Mostly covered, but custom signing & Slack notification need preservation

#### Job 3: promote-production (lines 360-455)
- Complex Google Play API promotion logic (Node.js script)
- ❌ NOT in centralized actions
- **ACTION NEEDED**: Keep entirely as custom job

---

## 🎯 Migration Strategy

### Option 1: Hybrid Approach (Recommended)

Use centralized actions for **standard parts**, keep **custom logic** intact:

#### CI Workflow Changes

**Before**: 88 lines
**After**: ~35 lines (60% reduction)
**Approach**: Use centralized actions + add 2 custom security/architecture checks

```yaml
# New CI workflow structure
jobs:
  ci-checks:
    runs-on: self-hosted
    steps:
      - Checkout
      - Flutter Setup (centralized action)
      - Flutter Analyze (centralized action with architecture checks)
      - Security Check (keep custom)
      - Flutter Test (centralized action with --exclude-tags parameter)
```

#### CD Workflow Changes

**Before**: 456 lines
**After**: ~200-250 lines (45-55% reduction)
**Approach**: Use centralized actions for version/changelog/build, keep InvTrack-specific logic

```yaml
# New CD workflow structure
jobs:
  bump-and-deploy:
    steps:
      - Checkout (custom with PAT)
      - Check skip logic (custom)
      - Version bump (centralized action)
      - Changelog (CHOICE: use git-cliff OR centralized)
      - Update multi-file versions (custom)
      - Flutter setup (centralized)
      - Copy signing files (custom)
      - Build appbundle (centralized action)
      - App size tracking (custom)
      - Deploy Play Store (custom)
      - Commit & push (custom)
      - Create GitHub release (centralized action)
      - Slack notify (custom)

  deploy-tag: (keep mostly as-is)
  promote-production: (keep entirely as-is)
```

---

## ⚠️ Required Changes to Centralized Actions

### 1. Flutter Test Action - Add Parameter

**File**: `.github-workflows-shared/composite-actions/flutter/test/action.yml`

**Change**: Add `exclude-tags` input parameter

```yaml
inputs:
  exclude-tags:
    description: 'Tags to exclude from tests (comma-separated)'
    required: false
    default: ''
```

**Usage in step**:
```yaml
run: |
  EXCLUDE_TAGS="${{ inputs.exclude-tags }}"
  if [ -n "$EXCLUDE_TAGS" ]; then
    flutter test --exclude-tags="$EXCLUDE_TAGS"
  else
    flutter test
  fi
```

### 2. Flutter Analyze Action - Verify Architecture Checks

**File**: `.github-workflows-shared/composite-actions/flutter/analyze/action.yml`

**Current checks** (lines 63-88):
- ✅ API calls in widgets
- ✅ Navigation in domain
- ✅ UI in domain

**InvTrack checks**:
- ✅ API calls in widgets (FirebaseFirestore|http.|dio.)
- ✅ Navigation in domain (Navigator|GoRouter|context.go)

**Conclusion**: Centralized action already covers these! ✅ No change needed.

---

## 📋 Migration Decision Points - YOUR INPUT NEEDED

### Decision 1: Changelog Tool

**Option A**: Keep git-cliff (more features, better formatting)
- Pros: Current format, two separate configs (regular + Play Store)
- Cons: Requires git-cliff installation, custom steps

**Option B**: Use centralized changelog action (simpler)
- Pros: Standard approach, less maintenance
- Cons: Different format, may need adjustment

**Recommendation**: Keep git-cliff for now (minimal changes)

**YOUR CHOICE**: A or B? _________________

---

### Decision 2: Signing Files Approach

**Current**: Copies from `$HOME/invtrack-keys/` (self-hosted runner)

**Option A**: Keep current approach
- Pros: No changes needed, works with self-hosted
- Cons: Not portable to cloud runners

**Option B**: Migrate to secrets (base64)
- Pros: Works anywhere, more secure
- Cons: Need to base64 encode and set secrets

**Recommendation**: Keep current (Option A) since you're using self-hosted

**YOUR CHOICE**: A or B? _________________

---

### Decision 3: Security Checks

**Current**: Custom grep-based security checks in CI

**Option A**: Keep as separate custom step
- Pros: Maintains current checks exactly
- Cons: One extra step

**Option B**: Add to centralized Flutter analyze action
- Pros: Reusable across projects
- Cons: Not all projects need these

**Recommendation**: Keep as custom step (Option A) - project-specific

**YOUR CHOICE**: A or B? _________________

---

## 📝 Summary of Changes

### Changes to Centralized Actions (Minimal)

1. ✅ **Add `exclude-tags` parameter** to `flutter/test` action
2. ✅ Verify architecture checks (already covered)

### InvTrack Workflow Changes

#### CI Workflow
- ✅ Use `flutter/setup` (with cache recovery)
- ✅ Use `flutter/analyze` (with architecture checks)
- ✅ Use `flutter/test` (with `exclude-tags: 'golden'`)
- ✅ Keep custom security check step
- ✅ Preserve env vars and conditions

**Reduction**: 88 → ~35 lines (60%)

#### CD Workflow
- ✅ Use `common/version-bump` for version calculation
- ⚠️ Keep git-cliff for changelog (pending your decision)
- ✅ Use `flutter/build-android` for AAB build
- ✅ Use `common/create-release` for GitHub release
- ✅ Keep all InvTrack-specific steps:
  - Skip logic
  - Multi-file version updates
  - Signing file copy
  - App size tracking
  - Play Store deploy
  - Slack notifications
  - Git commit/push with PAT
  - Promote-production job (entirely preserved)

**Reduction**: 456 → ~220 lines (52%)

---

## ✅ Benefits After Migration

1. **Maintenance**: Updates to Flutter setup/build now automatic
2. **Consistency**: Same patterns as other projects
3. **Clarity**: Less boilerplate, focus on InvTrack-specific logic
4. **Flexibility**: Still keeps all custom features
5. **Testing**: Can leverage shared action improvements

---

## 🚀 Next Steps

1. **Review this document** ✋ PLEASE CONFIRM DECISIONS ABOVE
2. **Update centralized action** (add exclude-tags parameter)
3. **Create new CI workflow** (use centralized + custom steps)
4. **Create new CD workflow** (hybrid approach)
5. **Create PR** with:
   - New workflows
   - Backup of old workflows (rename to `.bak`)
   - This migration analysis doc
6. **Test in PR** before merging

---

**PLEASE REVIEW AND PROVIDE YOUR CHOICES FOR THE 3 DECISIONS ABOVE BEFORE I PROCEED**
