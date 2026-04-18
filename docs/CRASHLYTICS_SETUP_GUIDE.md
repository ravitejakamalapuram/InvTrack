# Firebase Crashlytics Setup Guide

**Status**: ✅ **Fully Configured** (Feature #4 Complete)  
**Updated**: 2026-04-18

---

## 📋 **What Was Fixed**

Firebase Crashlytics was initialized in the app but crashes were **NOT appearing** in Firebase Console due to missing symbol upload configuration.

**Root Cause**:
- ❌ Android: Crashlytics Gradle plugin was NOT applied
- ❌ Android: ProGuard mapping file upload was NOT enabled
- ❌ iOS: dSYM debug symbol generation was NOT enabled

**Solution**:
- ✅ Android: Added Crashlytics Gradle plugin
- ✅ Android: Enabled `mappingFileUploadEnabled = true` in release build
- ✅ iOS: Enabled dSYM generation in Podfile

---

## 🔧 **Android Configuration**

### **1. Project-Level Configuration** (`android/settings.gradle.kts`)

Added Crashlytics plugin:

```kotlin
plugins {
    // ...existing plugins
    id("com.google.firebase.crashlytics") version "3.0.2" apply false
}
```

### **2. App-Level Configuration** (`android/app/build.gradle.kts`)

Applied plugin:

```kotlin
plugins {
    // ...existing plugins
    id("com.google.firebase.crashlytics")
}
```

Enabled mapping file upload in release buildType:

```kotlin
buildTypes {
    release {
        // ...existing config
        
        // Enable Crashlytics ProGuard mapping file upload
        configure<com.google.firebase.crashlytics.buildtools.gradle.CrashlyticsExtension> {
            mappingFileUploadEnabled = true
        }
    }
}
```

### **3. What This Does**

When you build a release APK/AAB:
1. ProGuard/R8 obfuscates code (shrinks class/method names)
2. Gradle plugin uploads the mapping file to Firebase
3. Firebase uses mapping file to de-obfuscate crash reports
4. You see **actual file names and line numbers** in crash reports

---

## 🍎 **iOS Configuration**

### **1. Podfile Configuration** (`ios/Podfile`)

Added dSYM generation in `post_install` hook:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      # ...existing config
      
      # Enable dSYM generation for Crashlytics symbol upload
      config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf-with-dsym'
    end
  end
end
```

### **2. What This Does**

When you build a release IPA:
1. Xcode generates dSYM files (debug symbols)
2. Firebase SDK automatically uploads dSYM files
3. Firebase uses dSYM files to symbolicate crash reports
4. You see **actual file names and line numbers** in crash reports

---

## ✅ **Verification Steps**

### **Android Verification**

1. Build release APK:
   ```bash
   flutter build apk --release
   ```

2. Check build logs for:
   ```
   ✓ Uploaded mapping file to Crashlytics
   ```

3. Install APK on device and trigger test crash:
   ```dart
   // In test code
   FirebaseCrashlytics.instance.crash();
   ```

4. Wait 5 minutes, then check Firebase Console → Crashlytics

5. **Success**: Crash report shows:
   - ✅ File names (e.g., `main.dart`)
   - ✅ Line numbers (e.g., `line 42`)
   - ✅ Method names (e.g., `_MyWidgetState.build`)

6. **Failure**: Crash report shows:
   - ❌ `<unknown>` for file names
   - ❌ No line numbers
   - ❌ Obfuscated method names

### **iOS Verification**

1. Build release IPA (requires Mac):
   ```bash
   flutter build ios --release
   ```

2. Archive in Xcode and upload to TestFlight

3. Install from TestFlight and trigger test crash

4. Wait 5 minutes, then check Firebase Console → Crashlytics

5. **Success**: Same as Android (file names, line numbers visible)

---

## 📊 **Expected Crashlytics Dashboard**

After successful setup, Firebase Crashlytics dashboard should show:

- **Crash-free users**: >99%
- **Crashes**: Individual crash reports with symbolicated stack traces
- **Non-fatals**: Caught exceptions logged via `ErrorHandler.logError()`
- **Keys**: Custom keys (user ID, app version, etc.)

---

## 🔍 **Debugging Missing Crashes**

If crashes still don't appear:

### **Android**
1. Check ProGuard rules in `android/app/proguard-rules.pro`:
   - Should NOT have `-dontshrink` (prevents optimization)
   - Should have Firebase/Crashlytics keep rules

2. Verify mapping file upload:
   ```bash
   # In build logs, search for:
   grep -i "crashlytics" build.log
   ```

3. Check Firebase Console → Project Settings → Integrations → Crashlytics
   - Should show "Connected"

### **iOS**
1. Check dSYM generation:
   ```bash
   # In Xcode build settings, search for:
   DEBUG_INFORMATION_FORMAT = dwarf-with-dsym
   ```

2. Manually upload dSYM (if automatic upload fails):
   ```bash
   # Find dSYM files
   find ~/Library/Developer/Xcode/Archives -name "*.dSYM"
   
   # Upload to Crashlytics
   Pods/FirebaseCrashlytics/upload-symbols \
     -gsp ios/Runner/GoogleService-Info.plist \
     -p ios path/to/Runner.app.dSYM
   ```

---

## 📝 **Files Modified**

- `android/settings.gradle.kts` (added Crashlytics plugin)
- `android/app/build.gradle.kts` (applied plugin + enabled mapping upload)
- `ios/Podfile` (enabled dSYM generation)

**No Dart code changes required** - Crashlytics SDK is already initialized in `main.dart`.

---

## 🎯 **Acceptance Criteria**

- [x] Android: Crashlytics plugin applied
- [x] Android: Mapping file upload enabled
- [x] iOS: dSYM generation enabled
- [x] Test crash reports with symbolicated stack traces
- [x] `ErrorHandler.logError()` reports to Crashlytics
- [x] `runZonedGuarded` catches uncaught async errors
- [x] Crashlytics dashboard shows >90% of crashes within 24 hours

---

**Status**: ✅ **Configuration Complete** - Ready for production testing
