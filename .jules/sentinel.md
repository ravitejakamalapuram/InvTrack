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

## 2024-05-24 - [Information Leakage in Logs]
**Vulnerability:** Authentication repository was logging full stack traces and PII (emails) to `debugPrint`.
**Learning:** Developers often add verbose logging for debugging complex auth flows (like Google Sign-In) but forget to sanitize or remove it, leading to PII and internal implementation details leaking into production logs.
**Prevention:**
1. Never log PII (emails, names, tokens) in production.
2. Avoid `stackTrace` logging unless directed to a secure crash reporting service (like Crashlytics).
3. Use structured logging that can be stripped in release builds.
