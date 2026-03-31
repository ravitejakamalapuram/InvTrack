# Version Update Troubleshooting Guide

## Overview

This guide helps debug issues with the app version update notification system.

---

## 🏗️ Architecture Overview

### **Deployment Strategy: Alpha → Manual Promotion → Production**

```
1. CI/CD Deploy to Alpha Track (Closed Testing)
   └─> cd-deploy-android.yml
       - Builds AAB
       - Uploads to Google Play alpha track
       - Sets pendingRelease=true in Firestore

2. Manual Promotion (You in Play Console)
   └─> Promote release from alpha → production
       - Quality gate: You decide when to promote
       - No automation - fully manual control

3. Approval Detection (Automated)
   └─> check-playstore-approval.yml (runs hourly)
       - Monitors production track
       - Detects your manual promotion
       - Updates Firestore when found
       - Clears pendingRelease flag

4. User Notification (Automated)
   └─> version_check_provider.dart
       - Fetches Firestore config every 24h
       - Compares currentBuildNumber < latestBuildNumber
       - Shows dialog if isReleased() = true
```

---

## 🔍 Diagnostic Steps

### **Step 1: Verify Firestore Document Exists**

**Check:** Does `app_config/version_info` document exist in Firestore?

**How to check:**
```
https://console.firebase.google.com/project/invtracker-b19d1/firestore/data/app_config/version_info
```

**If missing:**
```bash
# Run initialization workflow:
GitHub Actions → "Init: Firestore Version Info" → Run workflow
# Fill in: initial_version=3.54.17, initial_build_number=161
```

**Expected fields:**
- `latestVersion` (string)
- `latestBuildNumber` (number)
- `minimumVersion` (string)
- `minimumBuildNumber` (number)
- `forceUpdate` (boolean)
- `updateMessage` (string)
- `whatsNew` (string)
- `downloadUrl` (string)
- `releaseDate` (string/Timestamp)
- `pendingRelease` (boolean)
- `pendingVersion` (string/null)
- `pendingBuildNumber` (number/null)

---

### **Step 2: Verify Deployment Workflow**

**Check:** Did deployment set `pendingRelease=true`?

**How to check:**
1. Go to: https://github.com/ravitejakamalapuram/InvTrack/actions/workflows/cd-deploy-android.yml
2. Find latest deployment run
3. Check "Set pending release flag in Firestore" step
4. Should see: "✅ Pending release flag set successfully!"

**If failed:**
- Check Firebase credentials secret is valid
- Check network connectivity in runner
- Run manually: GitHub Actions → "CD: Deploy to Play Store"

---

### **Step 3: Verify Manual Promotion**

**Check:** Did you promote the release from alpha to production?

**How to check:**
1. Go to: https://play.google.com/console/u/0/developers/7885006060068362419/app/4975815827002913060/tracks/production
2. Look for the version you deployed
3. Status should be "Available" or "In progress"

**If not promoted:**
```
1. Go to Play Console
2. Navigate to Release → Closed Testing (Alpha)
3. Find the release
4. Click "Promote to Production"
5. Complete the promotion flow
```

---

### **Step 4: Verify Approval Detection**

**Check:** Did approval checker detect the production release?

**How to check:**
1. Go to: https://github.com/ravitejakamalapuram/InvTrack/actions/workflows/check-playstore-approval.yml
2. Find runs after your promotion
3. Look for: "🎉 VERSION APPROVED! Updating Firestore..."

**Expected logs:**
- Pending release found
- Checking Play Store API
- Latest Play Store release: Version Code: XXX, Status: completed
- Firestore updated successfully

**If not detecting:**
- Wait up to 1 hour (cron runs hourly)
- Manually trigger: GitHub Actions → "Auto-Check Play Store Approval" → Run workflow
- Check if production track has the release

---

### **Step 5: Verify Firestore Update**

**Check:** Was Firestore updated with new version?

**How to check:**
```
Firestore Console → app_config/version_info
- latestVersion should = your new version
- latestBuildNumber should = your new build number
- releaseDate should be set (2 hours after approval)
- pendingRelease should = false
```

**If not updated:**
- Check step 4 (approval detection)
- Check Play Console for rollout percentage (should be 100%)

---

## 🐛 Common Issues

### **Issue 1: "No update dialog shown"**

**Symptoms:** Firestore is updated, but users don't see dialog

**Causes:**
1. `releaseDate` is in the future (2-hour delay)
2. App hasn't checked for updates in last 24 hours
3. User dismissed the update
4. Version comparison failing

**Debug:**
```dart
// Add logging in version_check_provider.dart
print('Current build: ${state.currentBuildNumber}');
print('Latest build: ${state.latestVersion?.latestBuildNumber}');
print('Release date: ${state.latestVersion?.releaseDate}');
print('Is released: ${state.latestVersion?.isReleased()}');
print('Has update: ${state.hasUpdate}');
```

**Fix:**
- Wait 2 hours after Firestore update
- Force version check: Pull-to-refresh on home screen
- Clear app data and reinstall

---

### **Issue 2: "pendingRelease stuck at true"**

**Symptoms:** Firestore shows `pendingRelease: true` for days

**Causes:**
1. Release not promoted to production
2. Approval checker not running
3. Version mismatch

**Fix:**
```bash
# 1. Check if release is in production
Play Console → Production → Check version

# 2. Manually trigger checker
GitHub Actions → "Auto-Check Play Store Approval" → Run workflow

# 3. If version doesn't match, manually clear flag
# (Use Firebase Console or create manual workflow)
```

---

### **Issue 3: "Workflow finds no releases in production"**

**Symptoms:** Checker logs: "⚠️ No releases found in production track"

**Causes:**
1. Release still in alpha (not promoted)
2. Promotion pending Google review
3. Rollout percentage is 0%

**Fix:**
1. Promote release to production (see Step 3)
2. Wait for Google approval (1-3 days)
3. Check rollout percentage in Play Console

---

### **Issue 4: "Version mismatch"**

**Symptoms:** Checker finds different version than pending

**Logs:** "ℹ️ Play Store version does not match pending version"

**Causes:**
1. Newer version deployed but pending not updated
2. Old pending version not cleared

**Fix:**
- Checker auto-clears if Play Store version is newer
- Check Firestore after next hourly run

---

## 🛠️ Manual Firestore Update (Emergency)

If automation fails completely:

```bash
# 1. Go to Firebase Console
https://console.firebase.google.com/project/invtracker-b19d1/firestore/data/app_config/version_info

# 2. Manually edit fields:
- latestVersion: "3.54.17"
- latestBuildNumber: 161
- releaseDate: (current time as Timestamp)
- pendingRelease: false

# 3. Save

# 4. Users will see update within 24 hours
```

---

## 📊 Health Check Checklist

Run this checklist to verify everything is working:

- [ ] Firestore document exists with all required fields
- [ ] Firestore security rules allow public read for app_config
- [ ] Firebase credentials secret is valid
- [ ] Play Store API credentials secret is valid
- [ ] Deployment workflow completes successfully
- [ ] Pending flag is set after deployment
- [ ] Manual promotion to production works
- [ ] Approval checker runs hourly (check Actions tab)
- [ ] Firestore is updated after promotion
- [ ] App shows update dialog (test on device)

---

## 🔗 Useful Links

- **Firestore Console**: https://console.firebase.google.com/project/invtracker-b19d1/firestore/data/app_config/version_info
- **Play Console (Production)**: https://play.google.com/console/u/0/developers/7885006060068362419/app/4975815827002913060/tracks/production
- **GitHub Actions**: https://github.com/ravitejakamalapuram/InvTrack/actions
- **Deployment Workflow**: https://github.com/ravitejakamalapuram/InvTrack/actions/workflows/cd-deploy-android.yml
- **Approval Checker**: https://github.com/ravitejakamalapuram/InvTrack/actions/workflows/check-playstore-approval.yml

