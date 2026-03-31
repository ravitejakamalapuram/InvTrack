# InvTrack CI/CD Workflows

Simple, focused workflows with CodeRabbit handling detailed code reviews.

## 📋 Workflows

### 1. **PR Review** (`pr-review.yml`)
**Trigger:** Pull requests (opened, updated, ready for review)

**What it does:**
- ✅ Runs `flutter analyze`
- ✅ Runs `flutter test`
- ✅ Checks for critical security issues (SSL, print statements)
- ✅ Checks for architecture violations (API in widgets, navigation in domain)

**CodeRabbit Integration:**
- 🤖 CodeRabbit automatically reviews all PRs (configured in `.coderabbit.yaml`)
- 📝 Provides detailed feedback on code quality, localization, accessibility, etc.
- 🔍 Enforces InvTrack Enterprise Rules

**Merge Requirements:**
- All checks must pass (PR Checks status)
- CodeRabbit review completed
- Branch protection enforced (no direct pushes to main)

**Branch Protection:**
- ✅ Require pull requests before merging
- ✅ Require "PR Checks" status to pass
- ✅ Dismiss stale reviews on new commits
- ✅ No force pushes or deletions
- ⚠️ Admins can bypass (use carefully!)

---

### 2. **CI** (`ci-tests.yml`)
**Trigger:** Push to `main` or `develop`

**What it does:**
- ✅ Runs `flutter analyze`
- ✅ Runs `flutter test`
- ✅ Validates code quality on main branch

**Purpose:** Ensures main branch stays healthy

---

### 3. **CD: Version & Changelog** (`cd-version.yml`)
**Trigger:** Push to `main` (auto) or manual

**What it does:**
- 📦 Bumps version based on conventional commits
- 📝 Generates changelog with `git-cliff`
- 🏷️ Creates git tag
- 🚀 Triggers deployment workflow

**Version Bumping:**
- `feat:` → Minor version (1.2.0 → 1.3.0)
- `fix:` → Patch version (1.2.0 → 1.2.1)
- `BREAKING CHANGE:` → Major version (1.2.0 → 2.0.0)

---

### 4. **CD: Deploy to Play Store** (`cd-deploy-android.yml`)
**Trigger:** Version tag created or manual

**What it does:**
- 🏗️ Builds release AAB
- 📱 Deploys to Google Play **alpha track (closed testing)**
- 🔥 Sets pending flag in Firestore
- 📊 Creates GitHub release

**Deployment Flow (Alpha → Manual Promotion → Production):**
1. Build signed AAB
2. Upload to Play Store **alpha track** (closed testing)
3. Set `pendingRelease: true` in Firestore
4. **Manual**: You promote from alpha → production in Play Console
5. Approval checker monitors production track (see next workflow)

---

### 5. **Auto-Check Play Store Approval** (`check-playstore-approval.yml`)
**Trigger:** Hourly cron (9am-6pm UTC) or manual

**What it does:**
- 🔍 Checks if pending release is approved on Play Store
- ✅ Updates Firestore when you manually promote to production
- 📅 Sets `releaseDate` with 2-hour rollout delay
- 🔔 Notifies via Slack (optional)

**How it works with manual promotion:**
1. Checks Firestore for `pendingRelease: true` (set when deployed to alpha)
2. Queries Play Store API for **production track** (where you manually promote)
3. When pending version found in production with status = `completed`:
   - Updates `latestVersion` and `latestBuildNumber`
   - Sets `releaseDate` (2 hours from promotion)
   - Clears `pendingRelease: false`
4. App shows update dialog after `releaseDate` passes

**Note:** Monitors PRODUCTION track to detect manual promotions from alpha (closed testing).

---

## 🎯 Design Philosophy

### **Simple & Focused**
- Each workflow has one clear purpose
- No duplicate checks across workflows
- Easy to understand and maintain

### **CodeRabbit Does the Heavy Lifting**
- Detailed code review (localization, accessibility, architecture)
- Enforces InvTrack Enterprise Rules
- Provides actionable feedback

### **CI/CD Does the Essentials**
- Critical checks only (analyze, test, security, architecture)
- Automated version bumping and deployment
- End-to-end automation from commit to Play Store

---

## 🔧 Local Development

**Before pushing:**
```bash
# Run the same checks as CI
flutter analyze --no-fatal-infos
flutter test --exclude-tags=golden
```

**Check for issues:**
```bash
# Security
grep -rn "badCertificateCallback\|allowInsecure" lib/

# Architecture
grep -rn "FirebaseFirestore\|http\.\|dio\." lib/features/*/presentation/widgets/
grep -rn "Navigator\|GoRouter" lib/features/*/domain/
```

---

## 📚 Related Files

- **CodeRabbit Config:** `.coderabbit.yaml`
- **Enterprise Rules:** `.augment/rules/invtrack_rules.md`
- **Changelog Config:** `cliff.toml`

