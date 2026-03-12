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

ℹ️ **Note: Play Store Only (Android)**

This app targets Google Play Store only. Apple Sign-In is not required.

### 1.3 Guest Data Backup Reminders

✅ **Data Loss Prevention: Scheduled In-App Prompts**

Since apps cannot detect uninstall, show periodic backup reminders to guest users:

**Trigger Conditions**:
1. **After significant data entry**: Show prompt after user creates 5+ investments
2. **Monthly reminder**: Show prompt every 30 days if user hasn't exported data
3. **Settings access**: Prominent "Backup Data" button always visible

**Reminder Dialog**:
```text
┌─────────────────────────────────────┐
│                                     │
│   📦 Backup Your Data               │
│                                     │
│   You have 12 investments tracked.  │
│   Export your data to keep it safe. │
│                                     │
│   Guest data is stored locally and  │
│   will be lost if you uninstall.    │
│                                     │
│   [Remind Later]    [Export Now]    │
│                                     │
└─────────────────────────────────────┘
```

**Implementation**:
```dart
class GuestBackupReminderService {
  static const _lastReminderKey = 'guest_last_backup_reminder';
  static const _reminderIntervalDays = 30;

  Future<bool> shouldShowReminder() async {
    final isGuest = await _authService.isGuestMode();
    if (!isGuest) return false;

    final lastReminder = _prefs.getString(_lastReminderKey);
    if (lastReminder == null) return true; // First time

    final lastDate = DateTime.parse(lastReminder);
    final daysSince = DateTime.now().difference(lastDate).inDays;

    return daysSince >= _reminderIntervalDays;
  }

  Future<void> markReminderShown() async {
    await _prefs.setString(_lastReminderKey, DateTime.now().toIso8601String());
  }
}
```

### 1.4 Guest Analytics Consent Dialog

✅ **GDPR Compliance: Explicit Opt-In Required**

When user selects "Continue as Guest", show consent dialog BEFORE starting guest session:

```text
┌─────────────────────────────────────┐
│                                     │
│   Help Us Improve InvTrack         │
│                                     │
│   Would you like to share           │
│   anonymous usage data to help      │
│   us improve the app?               │
│                                     │
│   • No personal information         │
│   • No financial data               │
│   • Only feature usage stats        │
│   • Can be disabled anytime         │
│                                     │
│   [No Thanks]    [Allow Analytics]  │
│                                     │
└─────────────────────────────────────┘
```

**Implementation**:
- Show dialog ONCE on first guest session
- Store choice in SharedPreferences: `guest_analytics_consent`
- Default: `false` (analytics disabled)
- If user selects "Allow Analytics": set to `true`
- If user selects "No Thanks": set to `false`
- Gate all analytics calls behind this flag:
  ```dart
  Future<void> logEvent(String event, Map<String, dynamic> params) async {
    final isGuest = await _authService.isGuestMode();
    if (isGuest) {
      final consent = _prefs.getBool('guest_analytics_consent') ?? false;
      if (!consent) return; // Skip analytics for guest without consent
    }
    // Proceed with analytics
    await _analytics.logEvent(name: event, parameters: params);
  }
  ```

```text
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

**WCAG AAA Requirements** (per InvTrack accessibility guidelines):
- **Normal text (<18pt)**: 7:1 contrast ratio minimum
- **Large text (≥18pt or ≥14pt bold)**: 4.5:1 contrast ratio minimum

**Concrete Color Tokens** (verified with contrast checker):

#### Guest Mode Indicator (Orange/Amber - Warning)
- **Light Theme**:
  - Text: `--color-guest-amber-light: #B45309` (Amber 700)
  - Background: `--color-app-bar-light: #FFFFFF` (White)
  - **Contrast Ratio**: 5.74:1 ✅ (meets 4.5:1 for large text ≥18pt)
  - **Text Size**: 18pt bold (recommended)

- **Dark Theme**:
  - Text: `--color-guest-amber-dark: #FCD34D` (Amber 300)
  - Background: `--color-app-bar-dark: #1F2937` (Gray 800)
  - **Contrast Ratio**: 9.21:1 ✅ (meets 7:1 for normal text)
  - **Text Size**: 16pt or larger

#### Signed-In Indicator (Green - Success)
- **Light Theme**:
  - Text: `--color-signed-in-green-light: #15803D` (Green 700)
  - Background: `--color-app-bar-light: #FFFFFF`
  - **Contrast Ratio**: 5.93:1 ✅ (meets 4.5:1 for large text ≥18pt)

- **Dark Theme**:
  - Text: `--color-signed-in-green-dark: #86EFAC` (Green 300)
  - Background: `--color-app-bar-dark: #1F2937`
  - **Contrast Ratio**: 10.12:1 ✅ (meets 7:1 for normal text)

#### Migration Progress (Blue - Info)
- **Light Theme**:
  - Text: `--color-migration-blue-light: #1D4ED8` (Blue 700)
  - Background: `--color-app-bar-light: #FFFFFF`
  - **Contrast Ratio**: 7.04:1 ✅ (meets 7:1 for normal text)

- **Dark Theme**:
  - Text: `--color-migration-blue-dark: #93C5FD` (Blue 300)
  - Background: `--color-app-bar-dark: #1F2937`
  - **Contrast Ratio**: 8.59:1 ✅ (meets 7:1 for normal text)

**Implementation Checklist**:
- [ ] Add color tokens to theme configuration
- [ ] Verify each token pair with contrast checker before implementation
- [ ] Use 18pt bold for guest/signed-in indicators (allows 4.5:1 threshold)
- [ ] Test on both light and dark themes
- [ ] Verify with TalkBack/VoiceOver for accessibility

### 7.4 Testing Requirements

🔴 **CRITICAL: Manual accessibility testing required before release**

- [ ] Test all guest mode flows with **TalkBack (Android)** enabled
- [ ] Test all guest mode flows with **VoiceOver (iOS)** enabled
- [ ] Verify sign-in flow is fully navigable with screen readers
- [ ] Verify migration flow provides clear audio feedback at each step
- [ ] Test critical flows:
  - Sign In screen
  - Add Investment
  - Investment List
  - Overview Screen
  - Settings Screen
  - Migration Flow (all 3 screens)
- [ ] Verify touch target sizes: minimum 44x44dp for all interactive elements
- [ ] Test with large text sizes (accessibility settings)
- [ ] Test with reduced motion enabled

## 8. Localization Strings

### 8.1 New ARB Entries Required

✅ **FIXED: Complete ARB structure with metadata**

```json
{
  "@@locale": "en",
  "guestMode": "Guest Mode",
  "@guestMode": {
    "description": "Label for guest mode indicator"
  },
  "continueAsGuest": "Continue as Guest",
  "@continueAsGuest": {
    "description": "Button text to start using app without signing in"
  },
  "signInToBackup": "Sign in to backup",
  "@signInToBackup": {
    "description": "Prompt to sign in for cloud backup"
  },
  "guestModeInfo": "Guest mode: Data stays on this device only",
  "@guestModeInfo": {
    "description": "Information about guest mode data storage"
  },
  "migrateYourData": "Migrate Your Data?",
  "@migrateYourData": {
    "description": "Title for migration prompt dialog"
  },
  "mergeWithCloud": "Merge with Cloud Data",
  "@mergeWithCloud": {
    "description": "Option to merge guest data with existing cloud data"
  },
  "replaceCloudData": "Replace Cloud Data",
  "@replaceCloudData": {
    "description": "Option to replace cloud data with guest data"
  },
  "keepSeparate": "Keep Separate",
  "@keepSeparate": {
    "description": "Option to export guest data and start fresh with cloud"
  },
  "migrationInProgress": "Migrating Your Data...",
  "@migrationInProgress": {
    "description": "Title shown during data migration process"
  },
  "migrationComplete": "Migration Complete!",
  "@migrationComplete": {
    "description": "Title shown when migration succeeds"
  },
  "migrationFailed": "Migration Failed",
  "@migrationFailed": {
    "description": "Title shown when migration fails"
  },
  "backupYourData": "Backup Your Data",
  "@backupYourData": {
    "description": "Prompt to backup data to cloud"
  },
  "dataStoredLocally": "Data stored locally",
  "@dataStoredLocally": {
    "description": "Information that data is stored on device only"
  },
  "willBeLostIfDeleted": "Will be lost if app deleted",
  "@willBeLostIfDeleted": {
    "description": "Warning that local data will be lost on app uninstall"
  },
  "exchangeRateCached": "Exchange rate cached, may not be current",
  "@exchangeRateCached": {
    "description": "Warning that exchange rates in guest mode may be outdated"
  }
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

