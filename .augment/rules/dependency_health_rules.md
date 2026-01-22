---
type: "always_apply"
---

# Dependency Health Rules – InvTrack

These rules ensure dependency hygiene and prevent security/compatibility issues.

---

## DEP RULE 1: PACKAGE VETTING (Before Adding)
Before adding ANY new package:
- Check pub.dev score (minimum 100 points required)
- Check last updated date (must be within 6 months)
- Check Flutter SDK compatibility with current SDK (^3.10.1)
- Check null-safety support (required)
- Check license compatibility (MIT, BSD, Apache preferred)
- Review GitHub issues for critical bugs
- Check if package is actively maintained (>1 maintainer preferred)

❌ Package that fails any check → DO NOT ADD without explicit user approval

---

## DEP RULE 2: PREFER OFFICIAL PACKAGES
Always prefer in this order:
1. Flutter SDK built-in solutions
2. Official Google/Firebase packages
3. Packages by verified publishers
4. Community packages (only if no alternative)

Example preferences:
- `firebase_*` over community Firebase wrappers
- `go_router` (official) over other routing solutions
- `flutter_riverpod` (official) over alternatives

---

## DEP RULE 3: VERSION CONSTRAINTS
- Use caret syntax: `^1.2.3` (allows minor updates)
- Never use `any` or open-ended ranges
- Pin major versions for critical packages:
  - `firebase_*`
  - `flutter_riverpod`
  - `go_router`
- Document why specific versions are pinned

---

## DEP RULE 4: DEPENDENCY AUDIT CHECKLIST
When asked to audit or update dependencies:
1. Run `flutter pub outdated`
2. Categorize updates:
   - 🔴 Security patches → Update immediately
   - 🟡 Minor updates → Review changelog, update if safe
   - 🟢 Major updates → Plan migration, test thoroughly
3. Check CHANGELOG for breaking changes
4. Run full test suite after updates
5. Test on both iOS and Android

---

## DEP RULE 5: REMOVING DEPENDENCIES
Before removing a package:
- Search entire codebase for imports
- Check for transitive dependencies that might break
- Remove from pubspec.yaml
- Run `flutter pub get`
- Run `dart analyze`
- Run full test suite

---

## DEP RULE 6: DEV DEPENDENCIES HYGIENE
- Keep dev_dependencies minimal
- Remove unused testing/build tools
- Ensure dev dependencies don't leak to production
- Regularly audit: `mocktail`, `build_runner`, `flutter_lints`

---

## DEP RULE 7: LOCKFILE MANAGEMENT
- Always commit `pubspec.lock`
- Never manually edit `pubspec.lock`
- Use `flutter pub upgrade` for updates
- Use `flutter pub downgrade` for rollbacks
- Document major lockfile changes in commits

---

## DEP RULE 8: SECURITY ADVISORY CHECK
Before any release:
- Check https://github.com/nickmeinhold/dart-security-advisories
- Review Firebase security bulletins
- Check Flutter security advisories
- Update vulnerable packages immediately

---

## DEP RULE 9: NATIVE DEPENDENCY AWARENESS
For packages with native code (iOS/Android):
- Check Podfile.lock for iOS versions
- Check gradle dependencies for Android
- Test on real devices (not just simulators)
- Verify minimum iOS/Android version compatibility
- Document any native configuration required

---

## DEP RULE 10: PERIODIC MAINTENANCE
Suggest to user monthly:
- Run `flutter pub outdated`
- Review and update minor versions
- Check for deprecated packages
- Audit unused dependencies
- Run `dart fix --apply` for deprecation fixes

