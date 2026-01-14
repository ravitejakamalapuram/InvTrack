# Sentinel Journal
## 2025-02-23 - App Switcher Privacy Leak
**Vulnerability:** Financial data visible in app switcher snapshots.
**Learning:** OS takes screen snapshots on 'inactive'/'paused' state. Standard Flutter apps don't obscure this by default.
**Prevention:** Wrapped app in `PrivacyProtectionWrapper` listening to lifecycle events.

## 2025-02-24 - Unsalted PIN Hashing
**Vulnerability:** User PINs were stored as unsalted SHA-256 hashes.
**Learning:** Even with FlutterSecureStorage, short inputs like 4-digit PINs are vulnerable to rainbow table attacks if the storage is compromised (e.g., rooted device).
**Prevention:** Always use Salted Hashing (e.g., `salt:hash` where salt is random 16 bytes) for any user secrets, even low-entropy ones.
