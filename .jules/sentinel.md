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

## 2026-02-02 - [Idle Alert Privacy Leak]
**Vulnerability:** "Idle Investment" alerts exposed specific investment names (e.g., "HDFC FD") on the lock screen because they defaulted to `NotificationVisibility.public`.
**Learning:** Even seemingly benign notifications like "idle alerts" can leak sensitive financial metadata (names of assets owned). Consistency in privacy settings across all notification types is crucial.
**Prevention:**
1. Audit all notification types for PII or sensitive metadata.
2. Default to `visibility: NotificationVisibility.private` for any notification that includes dynamic user content, unless explicitly verified as public-safe.

## 2026-05-24 - [CSV Injection Vulnerability]
**Vulnerability:** User-controlled inputs (investment names, notes, goal names) were exported to CSV files without sanitization. This allowed CSV Injection (Formula Injection) attacks where malicious input starting with =, +, -, @ could execute commands when opened in spreadsheet software.
**Learning:** Exporting user data to formats like CSV/Excel requires sanitization just like rendering HTML to prevent XSS. Spreadsheet software interprets cells starting with special characters as formulas, regardless of context.
**Prevention:**
1. Sanitize all user-controlled fields before writing to CSV.
2. Prepend a single quote (') to any field starting with =, +, -, @, tab, or carriage return.
3. Use a centralized utility (e.g., CsvUtils.sanitizeField) to ensure consistency.

## 2026-05-24 - [Accessibility Data Leakage]
**Vulnerability:** Privacy-masked fields (using `ImageFiltered` or text bullets) were leaking sensitive data via accessibility services (Screen Readers). The blurred content was still semantically present, and bulleted text announced individual bullets instead of "Hidden".
**Learning:** Visual masking (like blur) does not hide semantics from accessibility tools. Screen readers read the underlying widget tree unless explicitly excluded.
**Prevention:**
1. Wrap visually masked content in `Semantics(label: 'Hidden content', child: ExcludeSemantics(child: ...))`.
2. Use `semanticsLabel` on `Text` widgets to provide meaningful descriptions for masked text (e.g. "Hidden amount").

## 2026-05-25 - [Cleartext Traffic Vulnerability]
**Vulnerability:** The Android application did not explicitly forbid cleartext traffic (`usesCleartextTraffic` was undefined). This means on older Android versions or under certain configurations, the app could theoretically make unencrypted HTTP requests, exposing financial data to Man-in-the-Middle (MitM) attacks.
**Learning:** Even if an app primarily uses HTTPS libraries (like Firebase), leaving the "door open" for HTTP at the OS level is a security risk. A developer might accidentally introduce an HTTP call (e.g., for an image or a new API), and without this check, it would silently succeed and leak data.
**Prevention:**
1. Explicitly set `android:usesCleartextTraffic="false"` in `AndroidManifest.xml` for all production apps handling sensitive data.
2. Consider using Network Security Configuration for more granular control (certificate pinning) if higher security is needed.

## 2026-06-02 - [Zip Slip Path Traversal]
**Vulnerability:** The document import process (`DataImportService`) extracts files from a ZIP archive using metadata (`investmentId` and `documentId`) provided within the archive itself (`metadata.json`). These IDs were used to construct file paths in `DocumentStorageService` without validation, allowing a malicious ZIP file to write files outside the intended directory via path traversal characters (`../`).
**Learning:** Never trust metadata or file paths coming from an external source (like a ZIP file), even if the ZIP extraction itself is safe. Always validate or sanitize any string used to construct a file system path.
**Prevention:**
1. Validate all IDs used in file paths against a strict whitelist (e.g. `^[a-zA-Z0-9-_]+$`).
2. Use `path.normalize` and check `path.isWithin` to ensure the final path is inside the intended directory, as a second layer of defense.

## 2026-06-18 - [Weak PIN Hashing Remediated]
**Vulnerability:** User PINs were stored using weak hashing (single iteration SHA-256 with salt, known as v2 format). This is vulnerable to brute-force attacks if the storage is compromised, given the low entropy of 4-digit PINs.
**Learning:** Even with a salt, fast hashing algorithms are unsuitable for low-entropy secrets like PINs. An attacker can iterate through the entire 10,000 PIN space in milliseconds.
**Prevention:**
1. Implemented PBKDF2-HMAC-SHA256 with 10,000 iterations to increase the work factor (v3 format).
2. Added automatic upgrade logic to migrate existing users from v0 (plaintext), v1 (unsalted), and v2 (simple salted) to v3 (PBKDF2) upon successful login.

## 2026-06-25 - [Insecure PIN Rate Limiting Storage]
**Vulnerability:** PIN rate limiting counters (failed attempts, lockout timestamp) were stored in `SharedPreferences`. On iOS, `SharedPreferences` are cleared on app uninstall, while Keychain items (the PIN) persist. This allowed an attacker to bypass the lockout mechanism by uninstalling and reinstalling the app, effectively enabling infinite brute-force attempts.
**Learning:** Security controls (like rate limits) protecting a secret must be stored with the same persistence and security level as the secret itself. If the lock can be reset while the key remains, the lock is useless.
**Prevention:**
1. Store security metadata (failed attempts, lockout) in `FlutterSecureStorage` alongside the credentials.
2. Implement migration logic to seamlessly move existing counters from insecure storage to secure storage without resetting them (fail closed/secure).

## 2026-06-26 - [Zip Slip via Data Export]
**Vulnerability:** The data export service constructed ZIP files using unsanitized document filenames. A malicious filename containing path traversal characters (`../`) could be written to the ZIP, potentially allowing arbitrary file write when extracted by a vulnerable client (Zip Slip).
**Learning:** Security is bidirectional. We must sanitize data we *export* as well as data we *import*. Creating a malicious file (even from user's own data) puts the user at risk when they use that file with other tools.
**Prevention:**
1. Sanitize all filenames before adding them to a ZIP archive using `path.basename`.
2. Ensure metadata pointing to these files also uses the sanitized name to maintain referential integrity.

## 2026-06-27 - [Timing Attack in PIN Verification]
**Vulnerability:** The PIN verification logic used the standard equality operator (`==`) to compare the stored hash with the computed hash. This comparison returns `false` immediately upon finding the first mismatching character, leaking information about the valid hash prefix through timing differences. An attacker could theoretically use this to deduce the hash byte-by-byte.
**Learning:** Standard string comparison is optimized for performance, not security. For sensitive values like hashes, MACs, or tokens, early-exit behavior creates a side-channel vulnerability.
**Prevention:**
1. Use a constant-time comparison function (like `constantTimeEquals`) for all security-sensitive string comparisons.
2. Ensure the comparison takes the same amount of time regardless of whether the inputs match or where the mismatch occurs (e.g., using XOR accumulation).

## 2026-06-29 - [Local File Inclusion in Document Reader]
**Vulnerability:** The `DocumentStorageService.readDocument` method accepted an arbitrary file path (`localPath`) and read the file without validating it was within the allowed application directory. This allowed an attacker (or compromised local data) to read sensitive files from the device filesystem (LFI).
**Learning:** `path_provider` methods return safe base directories, but subsequent file operations using concatenated strings or stored paths are vulnerable if not validated. Trusting a stored path is dangerous if the storage medium (e.g. Firestore, local DB) can be tampered with.
**Prevention:**
1. Always validate file paths before opening them.
2. Use `path.canonicalize` to resolve symlinks and `..` segments.
3. Use `path.isWithin` to ensure the resolved path is strictly inside the intended directory.
