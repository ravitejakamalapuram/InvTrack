# 🐛 Update Dialog Not Showing - Root Cause Analysis

## Problem
- Play Store has version 3.25.2 (build 64) - deployed and approved
- Users on mobile (< 3.25.2) and emulator (3.25.0) don't see update dialog
- Workflow shows "No pending release" and exits

## Root Cause: Logic Bug in Rollout Delay Implementation

### What Happens:
1. **First workflow run after approval:**
   - Detects approval ✅
   - Records `lastApprovedAt` timestamp ✅
   - Clears `pendingRelease` flag ✅
   - **DOES NOT update `latestVersion`/`latestBuildNumber`** ❌ (waiting for 30-min delay)

2. **Subsequent workflow runs:**
   - Checks `pendingRelease` flag → **FALSE**
   - Exits immediately with "No pending release" ❌
   - **NEVER updates `latestVersion`/`latestBuildNumber`** ❌

### The Bug:
**Lines 267-270 in `.github/workflows/check-playstore-approval.yml`:**
```javascript
// Just record the approval time, don't notify users yet
await db.collection('app_config').doc('version_info').update({
  lastApprovedAt: existingApprovalTime || approvalTime,
  pendingRelease: false,  // ❌ BUG: Clears flag before updating latestVersion!
});
```

**Result:**
- Firestore `latestBuildNumber` is stuck at old value (probably 62 from 3.25.0)
- Users with build < 64 don't see popup because Firestore says latest is 62
- Workflow can't run again because `pendingRelease` is false

## Solution

### Option 1: Keep `pendingRelease` TRUE During Delay Period
```javascript
// Record approval time but KEEP pending flag
await db.collection('app_config').doc('version_info').update({
  lastApprovedAt: existingApprovalTime || approvalTime,
  pendingRelease: true,  // ✅ Keep flag so workflow runs again
});
```

### Option 2: Update Immediately, Use `releaseDate` for Delay
```javascript
// Update latestVersion immediately, use releaseDate for delay
const releaseDate = new Date(Date.now() + (30 * 60 * 1000)); // 30 min from now

await db.collection('app_config').doc('version_info').update({
  latestVersion: versionData.pendingVersion,
  latestBuildNumber: versionData.pendingBuildNumber,
  releaseDate: releaseDate.toISOString(),  // Future date
  updateMessage: 'New version available!',
  whatsNew: whatsNew,
  pendingRelease: false,
  lastApprovedAt: approvalTime,
});
```

Then app checks `isReleased()` which compares `releaseDate` with current time.

## Recommended Fix: Option 2
- Simpler logic
- Firestore has correct version immediately
- App handles delay via `releaseDate` check (already implemented in `AppVersionEntity.isReleased()`)
- No need for workflow to run multiple times

## Current Firestore State (Suspected)
```json
{
  "latestVersion": "3.25.0",
  "latestBuildNumber": 62,  // ❌ Should be 64!
  "pendingRelease": false,
  "lastApprovedAt": "2026-01-31T...",
  "pendingVersion": "3.25.2",
  "pendingBuildNumber": 64
}
```

## Verification Steps
1. Check actual Firestore data
2. Confirm `latestBuildNumber` is NOT 64
3. Apply fix (Option 2 recommended)
4. Manually trigger workflow or update Firestore
5. Test on emulator/mobile

