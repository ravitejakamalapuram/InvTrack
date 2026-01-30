# Play Store Approval Automation - Knowledge Transfer

> **Complete guide for automated Play Store approval monitoring and Firestore version updates**

---

## 🎯 What This Does

Automatically monitors Play Store for app approval and updates Firestore so users see the update dialog - **no manual Firestore edits needed**.

---

## 🏗️ Architecture

### **The Problem**
- Google Play **does NOT** provide webhooks when app is approved
- Only way to know: Poll the API or check email manually

### **The Solution**
**Smart Cron-Based Polling with Flag Control**

```
1. Deploy Workflow (cd-deploy-android.yml)
   ↓ Uploads to Play Store
   ↓ Sets Firestore: pendingRelease = true
   
2. Cron Workflow (check-playstore-approval.yml)
   ↓ Runs every hour
   ↓ Checks Firestore flag first
   ↓ If pendingRelease = false → Fast exit (2 sec)
   ↓ If pendingRelease = true → Check Play Store API
   
3. When Approved
   ↓ Updates Firestore with new version
   ↓ Sets pendingRelease = false
   ↓ Sends Slack notification
   ↓ Users see update dialog!
```

---

## 📁 Files Created/Modified

### **Workflows**
1. `.github/workflows/check-playstore-approval.yml` - Hourly cron monitoring
2. `.github/workflows/update-firestore-version.yml` - Manual fallback option
3. `.github/workflows/cd-deploy-android.yml` - Modified to set pending flag

### **App Code**
4. `lib/features/app_update/` - Complete version check feature
   - `data/services/version_check_service.dart` - Fetches from Firestore
   - `domain/entities/app_version_entity.dart` - Version comparison logic
   - `presentation/providers/version_check_provider.dart` - Riverpod state
   - `presentation/widgets/update_dialog.dart` - Update UI
   - `presentation/widgets/version_check_initializer.dart` - Auto-check on startup

### **Configuration**
5. `lib/app/app.dart` - Initialize version check
6. `lib/core/router/app_router.dart` - Export navigator key for dialogs
7. `pubspec.yaml` - Added package_info_plus dependency

---

## 🔧 Setup (One-Time)

### **1. GitHub Secrets**

```bash
# Already added:
✅ FIREBASE_CREDENTIALS - Firebase service account JSON
✅ PLAY_STORE_CREDENTIALS - Play Store API credentials
```

### **2. Firestore Schema**

**Document:** `app_config/version_info`

**Core Fields (existing):**
- `latestVersion` (string) - Latest version on Play Store
- `latestBuildNumber` (number) - Latest build number
- `minimumVersion` (string) - Minimum required version
- `minimumBuildNumber` (number) - Minimum required build
- `forceUpdate` (boolean) - Force users to update
- `updateMessage` (string) - Message in dialog
- `whatsNew` (string) - Changelog
- `downloadUrl` (string) - Play Store URL
- `releaseDate` (string, optional) - ISO 8601 date when available

**Automation Fields (new):**
- `pendingRelease` (boolean) - Flag for pending approval
- `pendingVersion` (string) - Version awaiting approval
- `pendingBuildNumber` (number) - Build awaiting approval
- `uploadedAt` (string) - When uploaded to Play Store
- `lastApprovedAt` (string) - When last approved

---

## 🚀 How to Use

### **Normal Release Flow**

```bash
# 1. Update version in pubspec.yaml
version: 3.24.0+56

# 2. Create and push tag
git tag v3.24.0
git push origin v3.24.0

# 3. Deploy workflow runs automatically
# ✅ Builds app
# ✅ Uploads to Play Store
# ✅ Sets pendingRelease: true in Firestore

# 4. Wait for Google approval (1-3 days)
# ⏳ Cron checks every hour automatically

# 5. When approved:
# ✅ Cron detects approval
# ✅ Updates Firestore automatically
# ✅ Sets pendingRelease: false
# ✅ Sends Slack notification
# ✅ Users see update dialog!

# 6. Done! No manual steps needed! 🎉
```

### **Manual Fallback (if needed)**

If automation fails, use manual workflow:

```bash
# Go to GitHub Actions → "Update Firestore Version Info"
# Fill in form:
- Version: 3.24.0
- Build: 56
- Release date: 2026-02-03T10:00:00Z (or leave empty)
- Update message: "New features available!"
- What's new: "- Feature 1\n- Feature 2"
```

---

## 🔍 Monitoring

### **Check Workflow Status**
```
https://github.com/ravitejakamalapuram/InvTrack/actions/workflows/check-playstore-approval.yml
```

### **Check Firestore State**
```
https://console.firebase.google.com/project/invtracker-b19d1/firestore/data/app_config/version_info
```

### **Expected Logs**
- **No pending release:** "✅ No pending release. Exiting..."
- **Checking:** "🔍 Checking Play Store API..."
- **Approved:** "🎉 VERSION APPROVED!"

---

## 🛠️ Troubleshooting

### **Issue: Workflow doesn't run**
**Solution:** Cron can take up to 1 hour to activate. Trigger manually first:
```bash
gh workflow run check-playstore-approval.yml
```

### **Issue: "No pending release" but I just deployed**
**Solution:** Check deploy workflow logs - "Set pending flag" step might have failed.

### **Issue: npm install fails**
**Solution:** Packages are installed with multiple fallback strategies:
1. Try npm registry with cache
2. Check if globally installed
3. Try with verbose logging
4. Fail with helpful error

**Pre-install globally on runner (recommended):**
```bash
npm install -g firebase-admin@12.0.0 googleapis@131.0.0
```

### **Issue: "Invalid credentials"**
**Solution:** Verify GitHub secrets are valid JSON (copy entire file content).

### **Issue: "No releases found in alpha track"**
**Solution:** Verify deploy workflow uploaded to `alpha` track (check cd-deploy-android.yml line 173).

---

## 📊 Resource Usage

### **When NO pending release (99% of time)**
- Runs every hour
- Checks Firestore flag only
- Exits in ~2-5 seconds
- **No Play Store API calls**
- Minimal CPU/memory

### **When pending release (1-3 days after deploy)**
- Runs every hour
- Checks Firestore flag
- Calls Play Store API
- ~10-20 seconds per check
- **1 API call/hour** (well within quota)

---

## 🔐 Security

### **Firestore Rules**
```javascript
match /app_config/{document} {
  allow read: if true;  // Anyone can read
  allow write: if false;  // Only admins/GitHub Actions
}
```

### **GitHub Secrets**
- Never logged or exposed
- Only accessible to workflows
- Encrypted at rest

---

## 🧪 Testing

### **Test Cron Workflow**
```bash
# Manual trigger
gh workflow run check-playstore-approval.yml

# Wait a few seconds
sleep 10

# Check status
gh run list --workflow=check-playstore-approval.yml --limit 1

# View logs
gh run view --log
```

**Expected output (no pending release):**
```
🔍 Checking for pending release...
✅ No pending release. Exiting...
ℹ️  This workflow will activate automatically after next deployment.
```

### **Test Manual Workflow**
```bash
# Trigger with test values
gh workflow run update-firestore-version.yml

# Check Firestore Console
# Should see updated values
```

---

## 📝 Firestore Document Examples

### **Idle State (no pending release)**
```json
{
  "latestVersion": "3.23.0",
  "latestBuildNumber": 55,
  "minimumVersion": "3.20.0",
  "minimumBuildNumber": 50,
  "forceUpdate": false,
  "updateMessage": "New features available!",
  "whatsNew": "- Bug fixes\n- Performance improvements",
  "downloadUrl": "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker",
  "releaseDate": "2026-01-25T10:00:00Z",
  "pendingRelease": false
}
```

### **Waiting for Approval**
```json
{
  "latestVersion": "3.23.0",
  "latestBuildNumber": 55,
  "pendingRelease": true,
  "pendingVersion": "3.24.0",
  "pendingBuildNumber": 56,
  "uploadedAt": "2026-01-30T10:30:00Z"
}
```

### **After Approval**
```json
{
  "latestVersion": "3.24.0",
  "latestBuildNumber": 56,
  "pendingRelease": false,
  "pendingVersion": "3.24.0",
  "pendingBuildNumber": 56,
  "uploadedAt": "2026-01-30T10:30:00Z",
  "lastApprovedAt": "2026-01-30T14:00:00Z",
  "releaseDate": "2026-01-30T14:00:00Z"
}
```

---

## 🎓 Key Concepts

### **Smart Flag Pattern**
- Uses `pendingRelease` boolean to control workflow behavior
- Fast exit when false (no API calls)
- Full check when true (API polling)
- Efficient resource usage

### **Environment-Scoped npm Config**
- Uses `NPM_CONFIG_*` environment variables
- Only affects workflow step, not system
- Handles corporate registry issues
- No side effects on runner

### **releaseDate Field**
- Optional field for handling Play Store rollout delays
- If set to future date, update dialog won't show until then
- Use case: Set to 3 days from now to handle gradual rollout
- Format: ISO 8601 (e.g., "2026-02-03T10:00:00Z")

---

## ✅ Benefits

- ✅ **Fully automated** - No manual Firestore edits
- ✅ **Efficient** - Only polls when needed
- ✅ **Reliable** - Multiple fallback strategies
- ✅ **Self-hosted** - Runs on your runners (free)
- ✅ **User-friendly** - Manual fallback option available
- ✅ **Monitored** - Slack notifications + GitHub logs
- ✅ **Tested** - Manual trigger for testing

---

## 📞 Support

**Check workflow logs:**
```bash
gh run list --workflow=check-playstore-approval.yml
gh run view <run-id> --log
```

**Check Firestore:**
```
Firebase Console → Firestore → app_config → version_info
```

**Manual trigger:**
```
GitHub → Actions → "Update Firestore Version Info" → Run workflow
```

---

## 🗑️ Cleanup

**Old documentation files (consolidated here):**
- ~~AUTOMATION_SUMMARY.md~~
- ~~FIRESTORE_VERSION_INFO_SCHEMA.md~~
- ~~GITHUB_ACTIONS_AUTOMATION_GUIDE.md~~
- ~~IMPLEMENTATION_COMPLETE.md~~
- ~~NPM_REGISTRY_TROUBLESHOOTING.md~~
- ~~OPTION_1_QUICK_START.md~~
- ~~VERSION_UPDATE_AUTOMATION_OPTIONS.md~~
- ~~VERSION_UPDATE_GUIDE.md~~
- ~~VERSION_UPDATE_SUMMARY.md~~

**All information is now in this single KT document.**

---

**Last Updated:** 2026-01-30
**Version:** 1.0
**Status:** ✅ Production Ready
