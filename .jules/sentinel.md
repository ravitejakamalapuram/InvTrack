# Sentinel's Journal

## 2024-05-22 - Plaintext PIN Storage
**Vulnerability:** User PINs were stored in plaintext in `FlutterSecureStorage`.
**Learning:** Even with secure storage, sensitive data like PINs should be hashed to provide defense in depth. If the secure storage is compromised (e.g. rooted device), the PIN is exposed.
**Prevention:** Always hash authentication secrets (passwords, PINs) before storage.

## Guidelines
This file tracks critical security learnings. Only add entries for unique/surprising findings.
