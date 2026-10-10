# Two-Track Version Management System

## Overview

InvTrack uses a **two-track version management system** to prevent production users from seeing update popups for beta-only releases that aren't available to them on the Play Store.

## Problem Solved

**Before (Single Track):**

```text
Beta release v2.0.0 build 50 → Update Firestore
↓
Production users (v1.9.0) see "Update Available" popup
↓
They go to Play Store → NO UPDATE SHOWN (beta only!)
↓
Confused/frustrated users
```

**After (Two-Track):**

```text
Beta release v2.0.0 → Update version_info_beta
Production release v1.9.0 → Update version_info

Beta users see beta updates
Production users see production updates only
No confusion!
```

## Firestore Structure

### Production Document: `app_config/version_info`

```json
{
  "latestVersion": "1.9.0",
  "latestBuildNumber": 45,
  "minimumVersion": "1.8.0",
  "minimumBuildNumber": 40,
  "forceUpdate": false,
  "updateMessage": "New features available!",
  "whatsNew": "- Portfolio Health Score\n- Multi-currency support",
  "downloadUrl": "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker"
}
```

### Beta Document: `app_config/version_info_beta`

```json
{
  "latestVersion": "2.0.0",
  "latestBuildNumber": 50,
  "minimumVersion": "1.9.0",
  "minimumBuildNumber": 45,
  "forceUpdate": false,
  "updateMessage": "Beta: Testing multi-currency support",
  "whatsNew": "- Multi-currency support\n- New goal templates\n- Bug fixes",
  "downloadUrl": "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker"
}
```

## How It Works

### 1. Beta Detection (App Code)

**Package Name Check:**
- Production: `com.invtracker.inv_tracker`
- Beta: `com.invtracker.inv_tracker.beta`

```dart
bool _isBetaBuild(PackageInfo packageInfo) {
  return packageInfo.packageName.endsWith('.beta');
}
```

### 2. Version Fetching (App Code)

```dart
// Detect beta user
final isBetaUser = _isBetaBuild(packageInfo);

// Fetch appropriate version
final latestVersion = await _service.fetchLatestVersion(
  isBetaUser: isBetaUser,
);
```

### 3. CI/CD Workflow (GitHub Actions)

**Beta Release (Closed Testing):**
1. Deploy to Play Store Closed Testing (alpha track)
2. Update `app_config/version_info_beta` document
3. Beta testers see update popup immediately

**Production Release:**
1. Start phased rollout (20% → 50% → 100%)
2. **Wait for 100% rollout** (2-3 days)
3. Update `app_config/version_info` document
4. Production users see update popup

## Release Timeline

```text
Day 1:  Submit to Play Console → Beta Testing
Day 3:  Approved → Deploy to Closed Testing → Update version_info_beta
Day 5:  Beta testing complete → Promote to Production (20% rollout)
Day 6:  50% rollout
Day 7:  100% rollout → Update version_info (production users see popup)
```

## Critical: When to Update Firestore

### ❌ DON'T Update Immediately After Release Start

- Some users won't have received the Play Store update yet
- They'll see "Update Available" but Play Store shows "No Update"

### ✅ DO Update After 100% Rollout Complete

- All eligible users have received the Play Store update
- Update popup now matches Play Store availability

### Exception: Force Update (Critical Bug Fix)

- Update Firestore IMMEDIATELY
- Set `forceUpdate: true`
- Users MUST update for security/data integrity

## GitHub Actions Integration

### Beta Deployment Workflow

`cd-deploy-android.yml` deploys to Closed Testing and updates `version_info_beta`:

```text
# Pseudo-code (illustrative)
- name: Update Beta Version Info in Firestore
  run: |
    await db.collection('app_config').doc('version_info_beta').set({
      latestVersion: version,
      latestBuildNumber: buildNumber,
      # ... other fields
    }, { merge: true });
```

### Production Deployment Workflow

`cd-promote-production.yml` promotes to Production and updates `version_info`:

**Behavior:**
- **All rollout percentages (20%, 50%, 100%):** Updates rollout tracking metadata (`rolloutPercentage`, `updatedAt`)
- **Only at 100% rollout:** Promotes production fields (`latestVersion`, `latestBuildNumber`) from pending fields

```text
# Pseudo-code (illustrative)
- name: Update Production Version Info in Firestore
  run: |
    # Always update rollout tracking
    await db.collection('app_config').doc('version_info').set({
      rolloutPercentage: rolloutPercent,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    # Only promote production fields at 100%
    if (rolloutPercent === 100) {
      // Guard: Verify pending fields exist
      if (!versionData.pendingVersion || !versionData.pendingBuildNumber) {
        throw new Error('Missing pending fields');
      }

      await db.collection('app_config').doc('version_info').set({
        latestVersion: versionData.pendingVersion,
        latestBuildNumber: versionData.pendingBuildNumber,
        // ... other production fields
      }, { merge: true });
    }
```

## Testing

### Manual Testing Checklist

- [ ] Create both Firestore documents (`version_info` and `version_info_beta`)
- [ ] Test beta build with higher `version_info_beta` version
- [ ] Test production build with lower `version_info` version
- [ ] Verify beta users see beta updates only
- [ ] Verify production users see production updates only
- [ ] Verify update dialog shows correct message for each track

## Troubleshooting

**Q: Production users not seeing updates after 100% rollout?**
- Check `app_config/version_info` document exists
- Verify `latestBuildNumber` is higher than current app version
- Check app logs for Firestore fetch errors

**Q: Beta users seeing production updates?**
- Verify beta build package name ends with `.beta`
- Check `app_config/version_info_beta` exists
- Review beta detection logic in `version_check_provider.dart`

**Q: How to force an update immediately?**
- Set `forceUpdate: true` in Firestore document
- Update both tracks if needed for all users
- Dialog becomes non-dismissible
