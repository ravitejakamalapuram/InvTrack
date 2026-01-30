# Firestore Version Info Schema

## Document Location

**Collection:** `app_config`  
**Document:** `version_info`

---

## Fields

### **Core Version Fields**

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `latestVersion` | string | ✅ Yes | Latest app version available on Play Store | `"3.24.0"` |
| `latestBuildNumber` | number | ✅ Yes | Latest build number (from pubspec.yaml) | `56` |
| `minimumVersion` | string | ✅ Yes | Minimum version required to use the app | `"3.20.0"` |
| `minimumBuildNumber` | number | ✅ Yes | Minimum build number required | `50` |

### **Update Control Fields**

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `forceUpdate` | boolean | ✅ Yes | Whether to force users to update | `false` |
| `updateMessage` | string | ✅ Yes | Message shown in update dialog | `"New features available!"` |
| `whatsNew` | string | ✅ Yes | Changelog/release notes | `"- Feature 1\n- Feature 2"` |
| `downloadUrl` | string | ✅ Yes | Play Store URL | `"https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker"` |
| `releaseDate` | string | ❌ No | ISO 8601 date when update becomes available | `"2026-02-03T10:00:00Z"` |

### **Automation Fields (NEW)**

| Field | Type | Required | Description | Example |
|-------|------|----------|-------------|---------|
| `pendingRelease` | boolean | ❌ No | Flag indicating a release is awaiting approval | `true` |
| `pendingVersion` | string | ❌ No | Version waiting for approval | `"3.24.0"` |
| `pendingBuildNumber` | number | ❌ No | Build number waiting for approval | `56` |
| `uploadedAt` | string | ❌ No | ISO 8601 timestamp when uploaded to Play Store | `"2026-01-30T10:30:00Z"` |
| `lastApprovedAt` | string | ❌ No | ISO 8601 timestamp when last approved | `"2026-01-30T14:00:00Z"` |

---

## Example Document

### **Before Deployment (Idle State)**

```json
{
  "latestVersion": "3.23.0",
  "latestBuildNumber": 55,
  "minimumVersion": "3.20.0",
  "minimumBuildNumber": 50,
  "forceUpdate": false,
  "updateMessage": "New features available!",
  "whatsNew": "- Screenshot support enabled\n- Updated support email\n- Bug fixes",
  "downloadUrl": "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker",
  "releaseDate": "2026-01-25T10:00:00Z",
  "pendingRelease": false
}
```

### **After Deployment (Waiting for Approval)**

```json
{
  "latestVersion": "3.23.0",
  "latestBuildNumber": 55,
  "minimumVersion": "3.20.0",
  "minimumBuildNumber": 50,
  "forceUpdate": false,
  "updateMessage": "New features available!",
  "whatsNew": "- Screenshot support enabled\n- Updated support email\n- Bug fixes",
  "downloadUrl": "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker",
  "releaseDate": "2026-01-25T10:00:00Z",
  "pendingRelease": true,
  "pendingVersion": "3.24.0",
  "pendingBuildNumber": 56,
  "uploadedAt": "2026-01-30T10:30:00Z"
}
```

### **After Approval (Active State)**

```json
{
  "latestVersion": "3.24.0",
  "latestBuildNumber": 56,
  "minimumVersion": "3.20.0",
  "minimumBuildNumber": 50,
  "forceUpdate": false,
  "updateMessage": "New version available!",
  "whatsNew": "- New investment tracking features\n- Performance improvements\n- Bug fixes",
  "downloadUrl": "https://play.google.com/store/apps/details?id=com.invtracker.inv_tracker",
  "releaseDate": "2026-01-30T14:00:00Z",
  "pendingRelease": false,
  "pendingVersion": "3.24.0",
  "pendingBuildNumber": 56,
  "uploadedAt": "2026-01-30T10:30:00Z",
  "lastApprovedAt": "2026-01-30T14:00:00Z"
}
```

---

## Field Behavior

### **`pendingRelease` Flag Lifecycle**

```
1. Initial State: pendingRelease = false (or doesn't exist)
   ↓
2. Deploy Workflow Runs: Sets pendingRelease = true
   ↓
3. Cron Workflow Checks Every Hour:
   - If pendingRelease = false → Fast exit (2 seconds)
   - If pendingRelease = true → Check Play Store API
   ↓
4. When Approved: Sets pendingRelease = false
   ↓
5. Back to Initial State: Fast exit on next cron run
```

### **`releaseDate` Behavior**

- **Optional field** - If not set, update shows immediately
- **If set to future date** - Update dialog won't show until that date
- **Use case:** Handle Play Store rollout delays (set to 3 days from now)
- **Format:** ISO 8601 string (e.g., `"2026-02-03T10:00:00Z"`)

---

## Automation Workflow

### **1. Deploy Workflow (`cd-deploy-android.yml`)**

```yaml
# After uploading to Play Store:
- Sets pendingRelease: true
- Sets pendingVersion: "3.24.0"
- Sets pendingBuildNumber: 56
- Sets uploadedAt: current timestamp
```

### **2. Cron Workflow (`check-playstore-approval.yml`)**

```yaml
# Runs every hour:
1. Check pendingRelease flag
   - If false → Exit (fast, 2 seconds)
   - If true → Continue
   
2. Check Play Store API
   - Get release status
   - Compare with pendingBuildNumber
   
3. If approved:
   - Update latestVersion
   - Update latestBuildNumber
   - Set releaseDate to now
   - Set pendingRelease: false
   - Set lastApprovedAt: current timestamp
```

---

## Security Rules

```javascript
// firestore.rules
match /app_config/{document} {
  allow read: if true;  // Anyone can read
  allow write: if false;  // Only admins via console or GitHub Actions
}
```

---

## Migration Notes

If you have an existing `version_info` document without the new automation fields, they will be added automatically:

- **Deploy workflow** will add `pendingRelease`, `pendingVersion`, `pendingBuildNumber`, `uploadedAt`
- **Cron workflow** will add `lastApprovedAt` when first approval happens
- **All fields are optional** - existing functionality continues to work

---

## Monitoring

### **Check Current State**

```bash
# Firebase Console
https://console.firebase.google.com/project/invtracker-b19d1/firestore/data/app_config/version_info

# Or via CLI
firebase firestore:get app_config/version_info
```

### **Check Workflow Status**

```bash
# GitHub Actions
https://github.com/YOUR_REPO/actions/workflows/check-playstore-approval.yml
```

