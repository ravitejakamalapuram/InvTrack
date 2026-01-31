## 2024-05-23 - [PIN Hashing Enhancement]
**Vulnerability:** PINs were stored using unsalted SHA-256 hashes. While better than plaintext, unsalted hashes are vulnerable to rainbow table attacks, especially for short numeric PINs.
**Learning:** Upgrading security measures (like hashing algorithms) on live systems requires careful migration strategies. We cannot simply change the algorithm because we can't migrate existing data without the user's input (the PIN).
**Prevention:**
1. Always use salted hashes for secrets (passwords, PINs).
2. When upgrading, implement a "lazy migration" strategy:
   - Detect the old format on login/verification.
   - Verify using the old method.
   - If successful, re-hash using the new method (salt + hash) and overwrite the storage.
   - This seamlessly upgrades users as they log in.

## 2024-05-23 - [Debug Logging Exposure]
**Vulnerability:** PII (emails) and stack traces were logged via `debugPrint` without guards, potentially exposing them in system logs (logcat) in release builds.
**Learning:** In Flutter, `debugPrint` is not automatically stripped in release mode and writes to system logs, which can be accessible to other applications or physical attackers.
**Prevention:**
1. Wrap all debug logging in `if (kDebugMode)`.
2. Never log PII (emails, auth tokens, user objects), even in debug mode.
3. Consider using a custom logger that is compiled out or disabled in release builds.

## 2025-05-24 - [PIN Rate Limiting]
**Vulnerability:** The PIN verification logic lacked rate limiting, allowing unlimited attempts. This made the application vulnerable to brute-force attacks, especially since the verification happens locally.
**Learning:** Local authentication mechanisms must enforce rate limiting just like remote ones. Using `SharedPreferences` to persist the failure count and lockout timestamp ensures the protection survives app restarts.
**Prevention:**
1. Implement attempt counters for all authentication methods.
2. Enforce exponential backoff or fixed lockout periods after max attempts.
3. Persist lockout state to prevent bypass via app restart.

## 2025-05-25 - [Insecure Android Backup Configuration]
**Vulnerability:** The Android application configuration allowed backups (`allowBackup="true"` by default). This enabled attackers with physical access and enabled USB debugging to extract application data via `adb backup`, including sensitive cached investment data and unencrypted `SharedPreferences` (bypassing rate limits).
**Learning:** Default Android configurations prioritize convenience over security. Explicitly disabling backups is crucial for financial or sensitive applications to prevent data exfiltration.
**Prevention:**
1. Explicitly set `android:allowBackup="false"` in `AndroidManifest.xml`.
2. Set `android:fullBackupContent="false"` to prevent cloud backups of sensitive data.

## 2025-05-26 - [Missing Android Screen Protection]
**Vulnerability:** The application did not prevent screenshots, screen recording, or task switcher previews on Android. This could lead to sensitive financial data being leaked via accidental screenshots, malware screen recording, or shoulder surfing the Recents screen.
**Learning:** For financial applications, preventing data leakage via screen capture is critical. While Flutter provides lifecycle hooks to hide content in the task switcher, it doesn't prevent active screen recording or screenshots by the user/malware. Native `FLAG_SECURE` is the only robust solution.
**Prevention:**
1. Enable `WindowManager.LayoutParams.FLAG_SECURE` in `MainActivity.kt` (or `AppDelegate.swift`).
2. Conditionally apply it only in release builds (`!BuildConfig.DEBUG`) to allow development debugging.

## 2026-01-29 - [Missing iOS Screen Protection]
**Vulnerability:** The application did not conceal sensitive content in the iOS App Switcher. This allowed sensitive financial data to be visible when the user switched apps or if an attacker gained physical access to the unlocked device and viewed the Recents list.
**Learning:** While Android has `FLAG_SECURE`, iOS requires manual implementation of a blur or overlay view in `AppDelegate` to achieve the same privacy protection in the App Switcher.
**Prevention:**
1. Override `applicationWillResignActive` in `AppDelegate.swift` to add a blur effect (e.g., `UIVisualEffectView`) over the main window.
2. Override `applicationDidBecomeActive` to remove the blur effect.

## 2026-02-01 - [Data Leakage via Lock Screen Notifications]
**Vulnerability:** Sensitive financial summaries (e.g., "Income: ₹5,00,000") and lists of investment names were displayed in local notifications without `visibility: NotificationVisibility.private`. This allowed anyone to view this data on a locked Android device.
**Learning:** By default, Android notifications may show content on the lock screen depending on user settings. Explicitly setting `NotificationVisibility.private` ensures the content is hidden (showing "Contents hidden") on secure lock screens, regardless of some user defaults.
**Prevention:**
1. Always categorize notifications: Public (safe), Private (sensitive), Secret (never show).
2. For any notification containing PII or financial data, explicitly set `visibility: NotificationVisibility.private` in `AndroidNotificationDetails`.
