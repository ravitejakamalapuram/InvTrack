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

## 2024-05-24 - [PIN Rate Limiting]
**Vulnerability:** The PIN verification system lacked rate limiting, allowing attackers with physical access to brute-force the 4-digit PIN indefinitely.
**Learning:** Even with strong hashing (Salted SHA-256), short secrets like PINs are vulnerable to brute-force attacks if the verification attempt count is not limited.
**Prevention:**
1. Implement attempt counters and timeouts (e.g., 30s lockout after 5 failed attempts).
2. Store the attempt count and lockout timestamp in secure storage.
3. Ensure the UI handles the lockout state gracefully by informing the user.
