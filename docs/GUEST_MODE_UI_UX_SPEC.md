# Guest Mode UI/UX Specification

## 1. Sign-In Screen Changes

### 1.1 Current Sign-In Screen
```
┌─────────────────────────────────────┐
│                                     │
│         InvTracker Logo             │
│                                     │
│   Track Your Investments            │
│   Know Your Real Returns            │
│                                     │
│   [Sign In with Google]             │
│                                     │
└─────────────────────────────────────┘
```

### 1.2 New Sign-In Screen with Guest Mode
```
┌─────────────────────────────────────┐
│                                     │
│         InvTracker Logo             │
│                                     │
│   Track Your Investments            │
│   Know Your Real Returns            │
│                                     │
│   [Sign In with Google]             │
│                                     │
│   ─────────── or ───────────        │
│                                     │
│   [Continue as Guest]               │
│                                     │
│   ℹ️ Guest mode: Data stays on     │
│      this device only               │
│                                     │
└─────────────────────────────────────┘
```

### 1.3 Guest Mode Info Dialog
```
┌─────────────────────────────────────┐
│ Guest Mode                      [×] │
├─────────────────────────────────────┤
│                                     │
│ ✅ Use app without signing in       │
│ ✅ All features available           │
│ ✅ Data stored locally              │
│                                     │
│ ⚠️ No cloud backup                  │
│ ⚠️ Data lost if app uninstalled     │
│ ⚠️ No multi-device sync             │
│                                     │
│ You can sign in later to:           │
│ • Backup your data to cloud         │
│ • Access from multiple devices      │
│ • Never lose your data              │
│                                     │
│ [Continue as Guest] [Sign In]       │
│                                     │
└─────────────────────────────────────┘
```

## 2. App Bar Indicators

### 2.1 Guest Mode Indicator
```
┌─────────────────────────────────────┐
│ 🔒 Guest Mode        [Sign In] ☰   │
└─────────────────────────────────────┘
```

### 2.2 Signed-In Mode Indicator
```
┌─────────────────────────────────────┐
│ InvTracker          ☁️ Synced  ☰   │
└─────────────────────────────────────┘
```

### 2.3 Guest Mode with Data
```
┌─────────────────────────────────────┐
│ 🔒 Guest • 15 investments  [↑] ☰   │
└─────────────────────────────────────┘
```
*[↑] = Sign in to backup*

## 3. Settings Screen Changes

### 3.1 Guest Mode Settings
```
┌─────────────────────────────────────┐
│ Settings                            │
├─────────────────────────────────────┤
│                                     │
│ 👤 Account                          │
│ ┌─────────────────────────────────┐ │
│ │ 🔒 Guest User                   │ │
│ │                                 │ │
│ │ You're using guest mode.        │ │
│ │ Sign in to backup your data.    │ │
│ │                                 │ │
│ │ [Sign In with Google]           │ │
│ └─────────────────────────────────┘ │
│                                     │
│ 🎨 Appearance                       │
│ ├─ Theme                            │
│ ├─ Currency                         │
│ └─ Date Format                      │
│                                     │
│ 🔒 Security                         │
│ ├─ Passcode Lock                    │
│ └─ Privacy Mode                     │
│                                     │
│ 📊 Data Management                  │
│ ├─ Export Data                      │
│ ├─ Import Data                      │
│ └─ Sample Data                      │
│                                     │
└─────────────────────────────────────┘
```

### 3.2 Signed-In Mode Settings
```
┌─────────────────────────────────────┐
│ Settings                            │
├─────────────────────────────────────┤
│                                     │
│ 👤 Account                          │
│ ┌─────────────────────────────────┐ │
│ │ John Doe                        │ │
│ │ john.doe@gmail.com              │ │
│ │                                 │ │
│ │ ☁️ Last synced: 2 mins ago      │ │
│ │                                 │ │
│ │ [Sign Out]                      │ │
│ │ [Delete Account]                │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ... (rest same as guest mode)       │
│                                     │
└─────────────────────────────────────┘
```

## 4. Migration Flow UI

### 4.1 Sign-In from Guest Mode
```
Step 1: User taps "Sign In" button
        ↓
Step 2: Google Sign-In flow
        ↓
Step 3: Migration prompt appears
```

### 4.2 Migration Prompt
```
┌─────────────────────────────────────┐
│ Migrate Your Data?              [×] │
├─────────────────────────────────────┤
│                                     │
│ You have data in guest mode:        │
│                                     │
│ 📊 15 investments                   │
│ 💰 127 cash flows                   │
│ 🎯 3 goals                          │
│ 📄 8 documents                      │
│                                     │
│ What would you like to do?          │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ ✅ Merge with Cloud Data        │ │
│ │ Combine guest data with any     │ │
│ │ existing cloud data             │ │
│ │                                 │ │
│ │ [Merge Data]                    │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 🔄 Replace Cloud Data           │ │
│ │ Delete cloud data and use       │ │
│ │ guest data instead              │ │
│ │                                 │ │
│ │ [Replace Data]                  │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 📦 Keep Separate                │ │
│ │ Export guest data and start     │ │
│ │ fresh with cloud                │ │
│ │                                 │ │
│ │ [Export & Continue]             │ │
│ └─────────────────────────────────┘ │
│                                     │
│ [Cancel]                            │
│                                     │
└─────────────────────────────────────┘
```

### 4.3 Migration Progress
```
┌─────────────────────────────────────┐
│ Migrating Your Data...              │
├─────────────────────────────────────┤
│                                     │
│ ⏳ Please wait while we migrate     │
│    your data to the cloud.          │
│                                     │
│ ✅ Backing up data locally          │
│ ⏳ Uploading investments...         │
│    [████████░░░░░░░░] 60%          │
│ ⏸️ Uploading cash flows...          │
│ ⏸️ Uploading goals...               │
│ ⏸️ Uploading documents...           │
│ ⏸️ Verifying migration...           │
│                                     │
│ 📊 15/15 investments uploaded       │
│ 💰 76/127 cash flows uploaded       │
│                                     │
│ ⚠️ Do not close the app             │
│                                     │
└─────────────────────────────────────┘
```

### 4.4 Migration Success
```
┌─────────────────────────────────────┐
│ Migration Complete! ✅              │
├─────────────────────────────────────┤
│                                     │
│ Your data has been successfully     │
│ migrated to the cloud.              │
│                                     │
│ ✅ 15 investments                   │
│ ✅ 127 cash flows                   │
│ ✅ 3 goals                          │
│ ✅ 8 documents                      │
│                                     │
│ 💾 Backup saved to:                 │
│    InvTrack_Backup_20240315.zip     │
│                                     │
│ Your data is now synced across      │
│ all your devices!                   │
│                                     │
│ [Continue]                          │
│                                     │
└─────────────────────────────────────┘
```

### 4.5 Migration Error
```
┌─────────────────────────────────────┐
│ Migration Failed ❌                 │
├─────────────────────────────────────┤
│                                     │
│ We couldn't migrate your data.      │
│                                     │
│ Error: Network connection lost      │
│                                     │
│ Your guest data is safe and         │
│ unchanged. You can:                 │
│                                     │
│ • [Retry Migration]                 │
│ • [Export Data Manually]            │
│ • [Continue in Guest Mode]          │
│                                     │
│ 💾 Backup saved to:                 │
│    InvTrack_Backup_20240315.zip     │
│                                     │
│ [Contact Support]                   │
│                                     │
└─────────────────────────────────────┘
```

## 5. Upgrade Prompts

### 5.1 Periodic Upgrade Prompt (After 7 days)
```
┌─────────────────────────────────────┐
│ Backup Your Data                [×] │
├─────────────────────────────────────┤
│                                     │
│ You've been using InvTracker for    │
│ 7 days in guest mode.               │
│                                     │
│ Sign in to:                         │
│ ✅ Backup your 15 investments       │
│ ✅ Access from any device           │
│ ✅ Never lose your data             │
│                                     │
│ [Sign In Now] [Remind Me Later]     │
│                                     │
└─────────────────────────────────────┘
```

### 5.2 Export Prompt (Before Uninstall)
```
┌─────────────────────────────────────┐
│ Export Your Data?               [×] │
├─────────────────────────────────────┤
│                                     │
│ ⚠️ You're in guest mode.            │
│                                     │
│ If you uninstall the app, your      │
│ data will be lost forever.          │
│                                     │
│ We recommend:                       │
│ • Sign in to backup to cloud        │
│ • Export data to a file             │
│                                     │
│ [Sign In] [Export Data] [Cancel]    │
│                                     │
└─────────────────────────────────────┘
```

## 6. Feature-Specific UI Changes

### 6.1 Multi-Currency in Guest Mode
```
┌─────────────────────────────────────┐
│ US Stocks                           │
├─────────────────────────────────────┤
│ Current Value: $1,500               │
│                                     │
│ ≈ ₹1,24,680 (estimated)             │
│ ⓘ Exchange rate: 1 USD = 83.12 INR  │
│    (cached, may not be current)     │
│                                     │
└─────────────────────────────────────┘
```

### 6.2 Documents in Guest Mode
```
┌─────────────────────────────────────┐
│ Documents                           │
├─────────────────────────────────────┤
│ 📄 FD Certificate.pdf               │
│    Stored locally                   │
│    ⚠️ Will be lost if app deleted   │
│                                     │
│ [Upload Document]                   │
│                                     │
└─────────────────────────────────────┘
```

## 7. Accessibility Considerations

### 7.1 Screen Reader Announcements
- "Guest mode active. Data stored locally only."
- "Sign in to backup your data to the cloud."
- "Migration in progress. 60% complete."
- "Migration successful. Your data is now synced."

### 7.2 Semantic Labels
- Guest mode indicator: "Guest mode. Tap to sign in."
- Sign in button: "Sign in with Google to backup data"
- Migration button: "Migrate data to cloud"

### 7.3 Color Contrast
- Guest mode indicator: Orange/amber color (warning)
- Signed-in indicator: Green color (success)
- Migration progress: Blue color (info)

## 8. Localization Strings

### 8.1 New ARB Entries Required
```json
{
  "guestMode": "Guest Mode",
  "continueAsGuest": "Continue as Guest",
  "signInToBackup": "Sign in to backup",
  "guestModeInfo": "Guest mode: Data stays on this device only",
  "migrateYourData": "Migrate Your Data?",
  "mergeWithCloud": "Merge with Cloud Data",
  "replaceCloudData": "Replace Cloud Data",
  "keepSeparate": "Keep Separate",
  "migrationInProgress": "Migrating Your Data...",
  "migrationComplete": "Migration Complete!",
  "migrationFailed": "Migration Failed",
  "backupYourData": "Backup Your Data",
  "dataStoredLocally": "Data stored locally",
  "willBeLostIfDeleted": "Will be lost if app deleted",
  "exchangeRateCached": "Exchange rate cached, may not be current"
}
```

## 9. Animation & Transitions

### 9.1 Guest Mode Indicator
- Fade in when entering guest mode
- Pulse animation on first appearance
- Smooth transition to signed-in indicator

### 9.2 Migration Progress
- Progress bar animation (smooth, not jumpy)
- Checkmark animation on completion
- Error shake animation on failure

### 9.3 Sign-In Button
- Subtle glow effect to draw attention
- Haptic feedback on tap
- Loading spinner during sign-in

## 10. Error States

### 10.1 Network Error During Migration
```
┌─────────────────────────────────────┐
│ Network Error                   [×] │
├─────────────────────────────────────┤
│ ⚠️ No internet connection           │
│                                     │
│ Migration requires internet.        │
│ Please check your connection        │
│ and try again.                      │
│                                     │
│ [Retry] [Cancel]                    │
└─────────────────────────────────────┘
```

### 10.2 Storage Error During Migration
```
┌─────────────────────────────────────┐
│ Storage Error                   [×] │
├─────────────────────────────────────┤
│ ⚠️ Insufficient storage             │
│                                     │
│ Migration requires at least 50MB    │
│ of free space. Please free up       │
│ space and try again.                │
│                                     │
│ [OK]                                │
└─────────────────────────────────────┘
```

### 10.3 Duplicate Data Warning
```
┌─────────────────────────────────────┐
│ Duplicate Data Detected         [×] │
├─────────────────────────────────────┤
│ ⚠️ Some investments already exist   │
│    in your cloud account.           │
│                                     │
│ Found duplicates:                   │
│ • HDFC FD (2 versions)              │
│ • US Stocks (2 versions)            │
│                                     │
│ How should we handle duplicates?    │
│                                     │
│ [Keep Both] [Skip Duplicates]       │
│ [Cancel Migration]                  │
│                                     │
└─────────────────────────────────────┘
```

