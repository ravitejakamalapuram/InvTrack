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

### 6. **Jules AI Crash Fix Automation** (`jules-crash-fix.yml`) 🆕
**Trigger:** Daily at 9 AM UTC or manual

**What it does:**
- 🔍 Fetches top crashes from Firebase Crashlytics
- 🤖 Creates Jules AI sessions to analyze crashes
- 🛠️ Jules generates fixes with comprehensive tests
- 📝 Automatically creates pull requests
- 📊 Posts summary GitHub issue

**How it works:**
1. Fetches crashes using Firebase CLI MCP
2. Filters by impact (min affected users)
3. Creates Jules session for each crash
4. Jules analyzes root cause and generates fix
5. Creates PR with fix + tests (AUTO_CREATE_PR mode)
6. Monitors sessions and reports results

**Parameters (manual trigger):**
- `crash_limit`: Number of crashes to analyze (1-10)
- `min_affected_users`: Minimum users affected (default: 5)
- `report_type`: `topIssues` or `topVersions`

**Required Secrets:**
- `JULES_API_KEY` - Jules AI API key
- `JULES_SOURCE_NAME` - Jules source name (e.g., `sources/github-owner-invtrack`)
- `FIREBASE_TOKEN` - Firebase CI token
- `FIREBASE_APP_ID` - Firebase app ID

**Setup Guide:** See [JULES_CRASH_FIX_AUTOMATION.md](../../docs/JULES_CRASH_FIX_AUTOMATION.md)

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

# CI/CD Cache Fix - Wed May 20 07:57:04 IST 2026
# Workflow test - Wed May 20 10:32:38 IST 2026
