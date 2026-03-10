# Changelog

## [Unreleased]

### 🐛 Bug Fixes

- Update notification test expectations to match formatted currency output

## [3.48.13] - 2026-03-10

### 🐛 Bug Fixes

- Remove unused imports from settings_provider.dart

## [3.48.12] - 2026-03-10

### 🐛 Bug Fixes

- Remove circular dependency in currency provider invalidation

## [3.48.11] - 2026-03-10

### 🐛 Bug Fixes

- Add localization support to accessibility test files

## [3.48.10] - 2026-03-10

### 🐛 Bug Fixes

- Complete all l10n errors and code quality improvements (26 errors → 0)

### 📚 Documentation

- L10n fix summary (26 → 8 errors, 69% complete)

## [3.48.9] - 2026-03-10

### 🐛 Bug Fixes

- Resolve all l10n undefined errors (26 → 8 errors)

### 📚 Documentation

- CI/CD status report - multi-currency fix complete
- Update audit report with complete multi-currency fix

## [3.48.8] - 2026-03-10

### 🐛 Bug Fixes

- Complete multi-currency fix - invalidate currency format providers

## [3.48.7] - 2026-03-10

### 🐛 Bug Fixes

- Invalidate multi-currency providers on base currency change

## [3.48.6] - 2026-03-10

### 🐛 Bug Fixes

- **code-quality**: Fix all lint warnings and errors

## [3.48.5] - 2026-03-10

### 🐛 Bug Fixes

- **localization**: Complete localization compliance (Rule 16.1)

## [3.48.4] - 2026-03-10

### 🐛 Bug Fixes

- **localization**: Add missing ARB strings and fix hardcoded strings (partial)

## [3.48.3] - 2026-03-10

### 🐛 Bug Fixes

- Remove unused imports from export providers

## [3.48.2] - 2026-03-10

### 🐛 Bug Fixes

- Enterprise rules compliance - Multi-currency, localization, and data lifecycle (#255)

## [3.48.1] - 2026-03-09

### 🐛 Bug Fixes

- Use PAT for checkout on self-hosted runners
- Configure git to use SSH for checkout
- Use SSH for self-hosted runner checkout

### 🔧 Miscellaneous

- Use self-hosted runners for all workflows

## [3.48.0] - 2026-03-09

### ✨ Features

- Complete multi-currency stats display (Rule 21.3 compliance) (#243)

## [3.47.5] - 2026-03-08

### 🐛 Bug Fixes

- Restore .jules directory

## [3.47.2] - 2026-03-07

### 🧪 Testing

- Verify CD workflow is working consistently

## [3.47.1] - 2026-03-06

### 🐛 Bug Fixes

- Use actions/checkout@v3 for better runner compatibility
- Restore actions/checkout@v4 after runner upgrade

### 🔧 Miscellaneous

- Clean runner directories and restart
- Create _runner_file_commands directory for runners
- Test runner upgrade to v2.332.0

## [3.47.0] - 2026-03-06

### ✨ Features

- Streamline app lock setup with GPay-like UX (#248)

## [3.46.0] - 2026-03-06

### ✨ Features

- Add Mac Dock-style carousel animation to Goals widget (#241)

### 🐛 Bug Fixes

- Use manual git checkout instead of actions/checkout
- Downgrade checkout action to v3 for runner compatibility
- Resolve Crashlytics spam and deprecation warnings (#242)

## [3.45.0] - 2026-02-27

### ✨ Features

- **core**: Optimize XirrSolver input processing (#226)
- **security**: Validate file signature on document upload (#228)

## [3.44.0] - 2026-02-27

### ✨ Features

- **a11y**: Improve accessibility of investment list filters (#225)

## [3.43.0] - 2026-02-25

### ✨ Features

- Enhanced Firebase Performance Monitoring (#222)

## [3.41.0] - 2026-02-25

### ✨ Features

- **ui**: Make GlassCard keyboard accessible (#219)

### 🐛 Bug Fixes

- **security**: Prevent timing attacks in legacy PIN verification (#220)

## [3.41.1] - 2026-02-24

### Sentinel

- Fix timing attack in legacy PIN verification (#214)

### ⚡ Performance

- Optimize XIRR solver loop by factoring out constant multiplication (#213)

### ✨ Features

- Improve accessibility for add investment screen (#210)
- **security**: Increase default PBKDF2 iterations to 100,000 (#211)
- **a11y**: Add semantic copy action to CompactAmountText (#216)

## [3.40.0] - 2026-02-16

### ⚡ Performance

- Cache DateFormat.yMMM to reduce build overhead (#189)

### ✨ Features

- **a11y**: Add semantics to ShimmerEffect for loading states (#191)
- Add Tooltip to PrivacyToggleButton (#190)

## [3.39.0] - 2026-02-16

### ✨ Features

- **security**: Implement constant-time PIN verification (#188)

## [3.38.5] - 2026-02-16

### 🐛 Bug Fixes

- Remove READ_MEDIA_IMAGES/VIDEO permissions and clean up dead code

## [3.38.3] - 2026-02-14

### 🔧 Miscellaneous

- Change deployment back to closed testing (alpha track)

## [3.38.2] - 2026-02-14

### 🔧 Miscellaneous

- Remove temporary fix workflow

## [3.38.1] - 2026-02-14

### 🐛 Bug Fixes

- Prevent clearing pendingRelease during Play Store review

## [3.38.0] - 2026-02-14

### ✨ Features

- **a11y**: Improve accessibility in AddDocumentSheet (#187)
- **core**: Optimize XIRR calculation with smart initial guess (#185)
- Optimize XIRR calculation with bulk processing (#183)
- **a11y**: Prevent privacy data leakage in investment card semantics (#181)

### 🐛 Bug Fixes

- **security**: Enforce Fail Closed on storage errors during PIN verification (#182)

### 📚 Documentation

- Add comprehensive WCAG AAA accessibility guide (#184)

## [3.37.5] - 2026-02-13

### 🐛 Bug Fixes

- Remove READ_MEDIA_IMAGES permission to comply with Play Store policy

### 📚 Documentation

- Update TODO.md - Mark P3 Task 2 (Accessibility) as complete
- Update TODO.md - Mark P3 Tasks 1, 3, 4, 5 as complete
- Update TODO.md - Mark P2 Tasks 2 & 3 as complete

## [3.37.4] - 2026-02-13

### 🧪 Testing

- P2 Tasks 2 & 3 - Test Coverage Expansion (#180)

## [3.37.3] - 2026-02-13

### 📚 Documentation

- P2 Task 1 - Code Documentation Improvements (#179)

## [3.37.2] - 2026-02-13

### 🔧 Miscellaneous

- Change Play Store deployment from closed testing to production

## [3.37.0] - 2026-02-12

### ✨ Features

- P1 tasks - Structured Logging and ref.select (#175)

### 📚 Documentation

- Update TODO.md with completed PR #173 and #174

## [3.36.0] - 2026-02-11

### ✨ Features

- Add Firebase Performance Monitoring (P1) (#173)

## [3.35.0] - 2026-02-11

### ⚡ Performance

- Optimize currency formatting with NumberFormat caching (#171)

### ✨ Features

- Improve accessibility of filter chip close button (#170)

## [3.34.2] - 2026-02-11

### ♻️ Refactoring

- Add .autoDispose to screen-specific and parameterized providers (P1) (#172)

## [3.34.1] - 2026-02-11

### 🐛 Bug Fixes

- Enterprise compliance improvements (P0, P1, P2) (#163)

## [3.34.0] - 2026-02-10

### ✨ Features

- **a11y**: Add investment context to semantic labels (#166)

## [3.33.0] - 2026-02-09

### ✨ Features

- **a11y**: Improve semantic labels for MetricTile (#151)
- **a11y**: Improve semantics for transaction FAB and app bar actions (#156)
- **perf**: Optimize investment list date rendering (#157)
- **a11y**: Add keyboard navigation and focus indicators to TypeSelector (#158)

## [3.32.0] - 2026-02-04

### ✨ Features

- Add in-app Help & FAQ screen with usage information

## [3.31.0] - 2026-02-03

### ✨ Features

- Enterprise-Grade Localization & Internationalization (40+ Currencies, Auto-Detection) (#137)

## [3.30.5] - 2026-02-02

### 🐛 Bug Fixes

- Add error handling for network image loading in user profile

## [3.30.4] - 2026-02-02

### ⚡ Performance

- Optimize investment list stats using map provider (#140)

### 🐛 Bug Fixes

- **security**: Increase PIN lockout duration to 15 minutes (#139)

## [3.30.0] - 2026-02-01

### ✨ Features

- Auto-merge PRs from repo owner without approval requirement

## [3.29.0] - 2026-02-01

### ✨ Features

- Remove 'What's New' section from update dialog

## [3.28.1] - 2026-02-01

### 🔧 Miscellaneous

- Remove unnecessary debugging workflows and scripts

## [3.28.0] - 2026-02-01

### ✨ Features

- Add workflow to debug Firestore state

## [3.27.1] - 2026-02-01

### 🐛 Bug Fixes

- Remove duplicate 'now' variable declaration

## [3.27.0] - 2026-02-01

### ✨ Features

- Add workflow to fix stuck release state

## [3.26.1] - 2026-02-01

### 🐛 Bug Fixes

- Update Firestore immediately with future releaseDate for rollout delay

## [3.26.0] - 2026-02-01

### ✨ Features

- Add 30-minute rollout delay before notifying users

## [3.25.2] - 2026-01-31

### 🐛 Bug Fixes

- Type mismatch in version comparison (string vs number)

## [3.25.1] - 2026-01-31

### 🐛 Bug Fixes

- Auto-clear stale pending release flags in Play Store check

## [3.25.0] - 2026-01-31

### ✨ Features

- Add auto-merge to PR review workflow (event-based)

## [3.24.2] - 2026-01-31

### ♻️ Refactoring

- Increase PR review frequency to every 2 hours

## [3.24.1] - 2026-01-31

### ♻️ Refactoring

- Optimize scheduled workflows for self-hosted runner

## [3.24.0] - 2026-01-31

### ✨ Features

- Add daily automated PR review and merge workflow

## [3.23.3] - 2026-01-31

### 🐛 Bug Fixes

- Use system global npm packages instead of setup-node packages

## [3.23.2] - 2026-01-31

### 🐛 Bug Fixes

- Use globally installed npm packages in workflows

## [3.23.1] - 2026-01-31

### 🐛 Bug Fixes

- Remove npm cache config from Node.js setup in workflows

## [3.23.0] - 2026-01-31

### ✨ Features

- Add automated Play Store approval monitoring (#129)
- Update support email to invtrack_support@googlegroups.com (#128)

## [3.22.0] - 2026-01-30

### ✨ Features

- Update support email to invtrack_support@googlegroups.com

## [3.21.0] - 2026-01-30

### ✨ Features

- Enable screenshots - remove FLAG_SECURE restriction

## [3.20.0] - 2026-01-30

### ✨ Features

- **a11y**: Add maturity info to investment card semantics (#124)
- Add semantic selection state to GlassCard and InvestmentCard (#126)
- **ios**: Add App Switcher privacy screen (#127)

## [3.19.1] - 2026-01-28

### 🐛 Bug Fixes

- **android**: Use ApplicationInfo.FLAG_DEBUGGABLE instead of BuildConfig.DEBUG

## [3.19.0] - 2026-01-28

### ✨ Features

- **android**: Enable FLAG_SECURE in release builds (#118)
- **a11y**: Improve sign-in button semantics for loading state (#117)

## [3.17.0] - 2026-01-27

### Fix

- Prevent duplicate semantics in GlassCard when label is provided (#115)

### ✨ Features

- **security**: Hide sensitive notification content on lock screen (#114)

## [3.16.5] - 2026-01-26

### ⚡ Performance

- Fix excessive animation delay in long lists (#112)

## [3.16.4] - 2026-01-23

### ♻️ Refactoring

- Code health maintenance - reduce file sizes per Code Health… (#103)

## [3.16.2] - 2026-01-22

### 🐛 Bug Fixes

- Add mounted checks for async BuildContext usage in about_screen.dart

### 🔧 Miscellaneous

- Update dependencies (31 packages including Firebase suite)
- Regenerate golden test images for glass_card

## [3.15.4] - 2026-01-20

### 🔧 Miscellaneous

- Add script for setting up parallel GitHub Actions runners

## [3.15.3] - 2026-01-20

### 🐛 Bug Fixes

- Resolve infinite reload loop and Firestore permission issues

## [3.15.0] - 2026-01-19

### ⚡ Performance

- Optimize AppTextField rebuilds on text change (#87)

### ✨ Features

- **core**: Add semantic support to GlassCard widget (#79)

### 🔧 Miscellaneous

- **ux**: Improve accessibility and consistency in add transaction screen (#82)

## [3.14.3] - 2026-01-19

### ✨ Features

- **ux**: Improve MergeInvestmentsDialog accessibility and interaction
- **security**: Remove PII logging and guard debug prints

### 🐛 Bug Fixes

- Escape changelog content for Slack JSON payload
- Add missing foundation import for kDebugMode
- Add missing foundation import for kDebugMode

### 🔧 Miscellaneous

- Re-trigger ci
- Trigger ci rebuild

## [3.14.2] - 2026-01-14

### 🐛 Bug Fixes

- Truncate changelog to 500 chars for Play Store limit

## [3.14.1] - 2026-01-14

### 🐛 Bug Fixes

- CI/CD pipeline issues

## [3.14.0] - 2026-01-14

### Revert

- Restore self-hosted runners for workflows

### ⚡ Performance

- Disable glass blur in InvestmentCard list items to improve scrolling (#75)

### ✨ Features

- Add GitHub Actions runner auto-start setup script
- Improve accessibility of selection controls (#73)

### 🐛 Bug Fixes

- Remove unused variables in navigation_extensions_test

### 👷 CI/CD

- Switch Augment and CI workflows to GitHub-hosted runners

## [3.13.0] - 2026-01-11

### ✨ Features

- Add document UX improvements - loading indicator and per-file type selector

### 👷 CI/CD

- Simplify GitHub Actions for reliability (keep self-hosted)
- Simplify GitHub Actions workflows for reliability

## [3.12.0] - 2026-01-11

### ✨ Features

- Add document UX improvements - loading indicator and per-file type selector (#70)

## [3.11.0] - 2026-01-11

### ✨ Features

- **ux**: Add clear button to investment search field (#67)
- UX improvements batch 1 - Privacy mode, swipe actions, document management

## [3.10.0] - 2026-01-10

### UX

- Add clear button to AppTextField

### ✨ Features

- **security**: Add input length limits and validation to amount fields
- **a11y**: Add semantics to TypeSelector chips

### 👷 CI/CD

- Use self-hosted runner for Augment PR workflows

## [3.9.0] - 2026-01-08

### ✨ Features

- **security**: Add privacy screen for background state

## [3.8.2] - 2026-01-08

### 🐛 Bug Fixes

- Add explicit tag_name for GitHub Release action

## [3.8.1] - 2026-01-08

### 🐛 Bug Fixes

- Use pubspec.yaml as single source of truth for versioning

### 🔧 Miscellaneous

- Disable iOS and Android integration tests temporarily

## [3.7.1] - 2026-01-08

### 🐛 Bug Fixes

- Add actions:write permission to trigger deploy workflow

## [3.7.0] - 2026-01-08

### ♻️ Refactoring

- Consolidate store metadata and cleanup unnecessary workflows

### ⚡ Performance

- Defer XIRR calculation in InvestmentCard (#49)

### ✨ Features

- Implement multiple document upload, financing type, and UX improvements
- Add Semantics to Add Investment screen (#48)
- Make hero card toggle accessible (#50)
- **FIRE**: FIRE Number Calculator with comprehensive KT documentation (#53)
- **notifications**: Add goal at-risk and stale notifications

### 🐛 Bug Fixes

- Handle existing tags in CD workflow
- Use arch -arm64 for brew install on self-hosted runner
- Make Android integration tests optional
- Use GitHub-hosted runner for Android integration tests
- Resolve analyzer warnings
- Resolve lint warnings from merged PRs
- **security**: Prevent app lock during document picker operations
- Use macOS-compatible commands in release workflow [skip-release]
- Correct version to 3.6.0+18

### 👷 CI/CD

- Rename workflow files with ci/cd prefix [skip-release]
- Rename workflows with CI/CD prefix for clarity [skip-release]
- Switch to self-hosted runner for all workflows

### 🔧 Miscellaneous

- Add workflow_dispatch trigger to CD workflow
- Trigger CI
- Trigger CI
- Trigger CI

## [3.6.0] - 2026-01-05

### 👷 CI/CD

- Also copy key.properties for signing
- Add keystore copy step for self-hosted runner
- Switch to self-hosted runner for free CI/CD

### 🔧 Miscellaneous

- Bump version code to 100 for Play Store
- Bump version code to 10 for Play Store
- Add gitleaks config to allowlist Firebase/pod files

## [3.8.0] - 2026-01-05

### ⚡ Performance

- Optimize investment list sorting by skipping XIRR calculation (#46)

### ✨ Features

- Enforce input length limits on form fields (#47)
- **a11y**: Add semantics to investment list filters and search (#45)
- Add CI/CD automation with Slack notifications

### 🐛 Bug Fixes

- Trigger deploy workflow via gh cli to bypass GITHUB_TOKEN limitation [skip-release]

## [3.5.1] - 2026-01-04

### ✨ Features

- Add proper permission handling for document picker (v3.5.1)

## [3.5.0] - 2026-01-04

### ✨ Features

- Add document PDF viewer with external app support (v3.5.0)

## [3.4.0] - 2026-01-04

### ✨ Features

- **analytics**: Add comprehensive analytics tracking for investment lifecycle and settings
- V3.4.0 - Data Export/Import, Unified Settings & UX Improvements (#41)
- Add comprehensive automation testing infrastructure (#43)

## [3.3.1] - 2025-12-30

### 🐛 Bug Fixes

- Notifications, biometrics, and swipe archive (#42)

### 🔧 Miscellaneous

- Bump version to 3.3.1+15

## [3.3.0] - 2025-12-29

### ✨ Features

- Goals Selection Mode & Swipe-to-Delete v3.3.0 (#40)

### 📚 Documentation

- Add store listing workflow guide & sync fastlane metadata

## [3.2.8] - 2025-12-29

### ✨ Features

- Add Privacy Mode to hide financial data (#39)

## [3.2.7] - 2025-12-28

### 🐛 Bug Fixes

- **ci**: Add Gradle/pub caching, fix GitHub release permissions (v3.2.7+12)

## [3.2.6] - 2025-12-28

### 🐛 Bug Fixes

- **ci**: Use correct secret names STORE_PASSWORD and PLAY_STORE_CREDENTIALS (v3.2.6+11)

## [3.2.5] - 2025-12-28

### 🐛 Bug Fixes

- **ci**: Add keystore verification step and fix key.properties format (v3.2.5+10)

## [3.2.4] - 2025-12-28

### 🐛 Bug Fixes

- **ci**: Use Flutter master channel for Dart 3.10+ support (v3.2.4+9)

## [3.2.3] - 2025-12-28

### 🐛 Bug Fixes

- **ci**: Fix Flutter build workflow for Android deployment (v3.2.3+8)

## [3.2.2] - 2025-12-28

### 🐛 Bug Fixes

- Enable AD_ID permission for Firebase Analytics (v3.2.2+7)

## [3.2.1] - 2025-12-28

### ✨ Features

- **ci**: Add Fastlane and GitHub Actions for automated Play Store deployment
- **onboarding**: Add Goals & Reminders screen to onboarding
- **android**: Optimize APK size with R8 shrinking and ProGuard rules
- Add document management and enhanced notifications
- Simplify app messaging and update version to 3.1.0

### 🐛 Bug Fixes

- **android**: Remove AD_ID permission for Play Store compliance
- **ci**: Correct package name in Fastlane Appfile
- **ci**: Add all Firebase config files for CI builds
- **ci**: Add firebase_options.dart to repo for CI builds
- **ci**: Update Flutter version to 3.38.4 to match Dart SDK constraint
- **security**: App lock screen clear button and biometric auth issues (#38)
- **android**: Remove USE_EXACT_ALARM permission for Play Store compliance
- Update test repositories to implement archived collections interface

### 🔧 Miscellaneous

- Bump version to 3.2.1+6 for release
- Bump version to 3.2.0 and update store listings

## [3.0.0] - 2025-12-24

### ✨ Features

- Standardize App Lock UI

### 🐛 Bug Fixes

- Improve XIRR calculation for loss-making investments

## [0-stable] - 2025-12-08

### ✨ Features

- Add sync functionality to settings screen
- Implement financial calculators, entry form, sync, and charts
- Implement app theme, design system, and navigation
- Implement Investment and Entry CRUD operations
- Implement secure token storage and Drift database
- Implement Google Sign-In flow with Riverpod state management
- Configure Google OAuth credentials for web platform
- **P1-02**: Add core dependencies to pubspec.yaml
- **P1-01**: Initialize Flutter project with Clean Architecture structure

### 🐛 Bug Fixes

- Update integration tests to match actual entity structures
- Resolve deprecation warnings and improve auth initialization
- Add refreshListenable to router for auth state changes
- Resolve compilation errors for web platform
- Use Google's renderButton for web sign-in


