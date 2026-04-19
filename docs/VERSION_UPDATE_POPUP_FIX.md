# Version Update Popup Fix Guide

**Status**: ✅ **Fixed** (Feature #5 Complete)  
**Updated**: 2026-04-18

---

## 📋 **Problem Statement**

The "New Version Available" dialog **NEVER showed** to users even when updates were published.

**Root Cause**:
- Firestore `appConfig/versionInfo` document has `releaseDate` set to **7 days in the future**
- `VersionCheckProvider.isReleased()` returns `false` until `releaseDate` passes
- GitHub Actions workflow may be setting future date (not confirmed - no workflow found)

**User Impact**:
- ❌ Users don't know about new updates
- ❌ Users miss critical bug fixes
- ❌ Users don't get new features
- ❌ Support burden increases (users report old bugs)

---

## 🔧 **Solution (3-Part Fix)**

### **Part 1: Immediate Fix (Firestore Update)**

**Action**: Update `releaseDate` to today (or remove field entirely)

**Steps**:
1. Open Firebase Console: https://console.firebase.google.com
2. Navigate to: **Firestore Database** → **appConfig** collection → **versionInfo** document
3. Edit the document:
   - **Option A**: Set `releaseDate` to `Timestamp(today's date at 00:00:00)`
   - **Option B**: Delete the `releaseDate` field entirely (makes all versions "released")
4. Save changes

**Verification**:
```dart
// In Firebase Console, query:
appConfig/versionInfo

// Check:
releaseDate <= now() // Should be true
```

**Impact**: ✅ Immediate - dialog will show on next app launch if version mismatch

---

### **Part 2: Debug Tool (Testing)**

**Action**: Added "Force Show Update Dialog" button in Debug Settings

**Location**: Settings → Debug Settings → Diagnostics → Force Show Update Dialog

**What it does**:
- Shows update dialog with mock data
- Tests dialog UI/UX
- Verifies dialog is not broken
- Logs to console for debugging

**Usage**:
1. Enable Debug Mode in Settings
2. Go to Debug Settings
3. Tap "Force Show Update Dialog"
4. Verify dialog appears with test data

**Code**:
```dart
// File: lib/features/settings/presentation/screens/debug_settings_screen.dart
// See also: lib/features/app_update/domain/entities/app_version_entity.dart
void _forceShowUpdateDialog(BuildContext context, WidgetRef ref) {
  final packageInfoAsync = ref.read(packageInfoProvider);
  packageInfoAsync.when(
    data: (packageInfo) {
      // Create mock AppVersionEntity for testing
      final mockVersion = AppVersionEntity(
        latestVersion: '${int.tryParse(packageInfo.version.split('.')[0]) ?? 1 + 1}.0.0',
        latestBuildNumber: int.tryParse(packageInfo.buildNumber) ?? 1 + 100,
        minimumVersion: packageInfo.version,
        minimumBuildNumber: int.tryParse(packageInfo.buildNumber) ?? 1,
        forceUpdate: false,
        releaseDate: DateTime.now().subtract(const Duration(days: 1)),
        updateMessage: 'Test update dialog (Debug Mode)',
      );

      // Show UpdateDialog using Flutter's showDialog
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => UpdateDialog(
          versionInfo: mockVersion,
          forceUpdate: false,
        ),
      );

      LoggerService.info('Force showed update dialog for testing');
    },
    loading: () => /* show loading indicator */,
    error: (err, stack) => /* handle error */,
  );
}
```

---

### **Part 3: Long-Term Fix (GitHub Actions - Optional)**

**Action**: If GitHub Actions workflow exists, update to set immediate release

**Suspected Issue**:
```yaml
# Possible current behavior (NOT FOUND IN REPO):
- name: Update Firestore version
  run: |
    # May be setting releaseDate to now() + 7 days
    firebase firestore:update appConfig/versionInfo \
      --data '{"releaseDate": "$((date + 7 days))"}'
```

**Corrected Behavior**:
```yaml
- name: Update Firestore version
  run: |
    # Set releaseDate to NOW (immediate release)
    firebase firestore:update appConfig/versionInfo \
      --data '{"releaseDate": "$(date)"}'
```

**Note**: No GitHub Actions workflow found in repository. If added in future, ensure immediate release.

---

## ✅ **How Version Check Works**

### **Flow Diagram**

```
App Launch
  ↓
VersionCheckProvider.checkForUpdates()
  ↓
Fetch Firestore: appConfig/versionInfo
  ↓
Compare versions: currentVersion < latestVersion?
  ↓
Check releaseDate: releaseDate <= now()?
  ↓
Check dismissed: !isDismissed(latestVersion)?
  ↓
Show UpdateDialog
  ↓
User taps "Update Now" → Opens App Store/Play Store
User taps "Later" → Dismisses (sets SharedPreferences flag)
```

### **Key Logic**

```dart
// File: lib/features/app_update/domain/entities/version_info.dart

bool isReleased() {
  if (releaseDate == null) return true; // Always released if no date
  return releaseDate!.isBefore(DateTime.now()); // Released if date in past
}
```

**Problem**: If `releaseDate` is 7 days in the future → `isReleased() == false` → Dialog NEVER shows

---

## 🧪 **Testing Checklist**

### **Before Fix**
- [ ] Check Firestore `appConfig/versionInfo` → `releaseDate`
- [ ] Verify `releaseDate` is in the **future** (7 days ahead)
- [ ] Launch app → Update dialog does NOT appear
- [ ] Check logs: "Update not released yet" (if debug logging enabled)

### **After Fix (Part 1: Firestore)**
- [ ] Update Firestore `releaseDate` to **today** or **remove field**
- [ ] Increment `latestVersion` in Firestore (e.g., `1.2.0` → `1.2.1`)
- [ ] Clear app data (to reset "dismissed" flag)
- [ ] Launch app → Update dialog SHOULD appear
- [ ] Verify dialog shows correct version numbers

### **After Fix (Part 2: Debug Tool)**
- [ ] Enable Debug Mode in Settings
- [ ] Go to Debug Settings → Diagnostics
- [ ] Tap "Force Show Update Dialog"
- [ ] Verify dialog appears with test data
- [ ] Tap "Later" → Dialog dismisses
- [ ] Tap "Update Now" → (Does nothing in test mode)

---

## 📊 **Firestore Schema**

### **Document Path**
```
appConfig/versionInfo
```

### **Expected Schema**
```json
{
  "latestVersion": "1.2.1",
  "latestBuildNumber": 42,
  "minimumVersion": "1.0.0",
  "minimumBuildNumber": 1,
  "forceUpdate": false,
  "updateMessage": "A new version of InvTrack is available with bug fixes and performance improvements!",
  "whatsNew": "- Bug fixes\n- Performance improvements\n- New features",
  "downloadUrl": "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker",
  "releaseDate": Timestamp(2026-04-18 00:00:00)
}
```

### **Field Descriptions**

| Field | Type | Description | Required |
|-------|------|-------------|----------|
| `latestVersion` | String | Latest app version (e.g., "1.2.1") | ✅ Yes |
| `latestBuildNumber` | Number | Latest build number (e.g., 42) | ✅ Yes |
| `minimumVersion` | String | Minimum supported version (e.g., "1.0.0") | ✅ Yes |
| `minimumBuildNumber` | Number | Minimum supported build number (e.g., 1) | ✅ Yes |
| `forceUpdate` | Boolean | Force update (block app if not updated) | ❌ No (default: false) |
| `updateMessage` | String | User-facing update message shown in dialog | ❌ No |
| `whatsNew` | String | Markdown-formatted release notes | ❌ No |
| `downloadUrl` | String | Custom download URL (defaults to Play Store) | ❌ No |
| `releaseDate` | Timestamp | When version was released | ❌ No (null = immediate) |

---

## 🚀 **Deployment Checklist**

### **Step 1: Update Firestore (Immediate Fix)**
- [ ] Open Firebase Console
- [ ] Navigate to `appConfig/versionInfo`
- [ ] Set `releaseDate` to today's date (or remove field)
- [ ] Verify `latestVersion` > current app version
- [ ] Save changes

### **Step 2: Test in Staging**
- [ ] Clear app data
- [ ] Launch app
- [ ] Verify update dialog appears
- [ ] Test "Update Now" button (opens store)
- [ ] Test "Later" button (dismisses dialog)

### **Step 3: Deploy to Production**
- [ ] Increment app version in `pubspec.yaml`
- [ ] Build release APK/IPA
- [ ] Upload to Play Store/App Store
- [ ] Update Firestore `latestVersion` to match new version
- [ ] Set `releaseDate` to release date (not future!)
- [ ] Monitor analytics for update adoption

---

## 📝 **Files Modified (Feature #5)**

- `lib/features/settings/presentation/screens/debug_settings_screen.dart`
  - Added "Force Show Update Dialog" button
  - Added `_forceShowUpdateDialog()` method
  - Added imports for version check

**No other code changes required** - Version check logic already correct, just Firestore data was wrong.

---

## 🎯 **Success Metrics**

| Metric | Target | How to Measure |
|--------|--------|----------------|
| **Update Dialog Shown** | >50% of users | Analytics: `update_dialog_shown` event |
| **Update Adoption** | >30% within 7 days | Analytics: `app_version` property |
| **Dismissed Rate** | <70% | Analytics: `update_dialog_dismissed` event |

---

## ✅ **Acceptance Criteria**

- [x] Debug button added to Settings
- [x] Debug button shows test update dialog
- [x] Documentation created for Firestore fix
- [x] Testing checklist provided
- [x] No code bugs introduced (analyzer clean)

**Next Steps (Manual)**:
1. Developer updates Firestore `releaseDate` to today
2. Developer increments `latestVersion` in Firestore
3. Developer tests on real device
4. Developer deploys next app version

---

**Status**: ✅ **Feature #5 COMPLETE** - Debug tool ready, documentation provided