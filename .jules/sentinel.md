# Sentinel Journal
## 2025-02-23 - App Switcher Privacy Leak
**Vulnerability:** Financial data visible in app switcher snapshots.
**Learning:** OS takes screen snapshots on 'inactive'/'paused' state. Standard Flutter apps don't obscure this by default.
**Prevention:** Wrapped app in `PrivacyProtectionWrapper` listening to lifecycle events.
