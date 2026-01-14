# Changelog

## [Unreleased]

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

---
*Generated by [git-cliff](https://git-cliff.org)*
