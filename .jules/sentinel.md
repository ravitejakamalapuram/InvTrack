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
