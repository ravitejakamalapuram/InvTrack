# Changelog

All notable changes to InvTracker will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.3.0] - 2025-12-29

### Added
- 🎯 **Goals Selection Mode**: Multi-select goals for bulk operations
  - Tap the checkbox icon to enter selection mode
  - Select All / Deselect All controls
  - Bulk delete multiple goals at once
- 👆 **Swipe-to-Delete**: Quick delete with swipe gestures
  - Swipe left on any investment card to delete
  - Swipe left on any goal card to delete
  - Confirmation dialog before deletion
  - Disabled during multi-select mode

### Changed
- Refactored selection controls into reusable generic widgets
- Created `SelectionListControls` for consistent selection UI
- Created `SelectionListActionBar` for configurable bulk actions
- Created `SwipeToDelete` wrapper for consistent swipe behavior
- Improved code reuse across investments and goals features

---

## [3.2.8] - 2025-12-29

### Added
- 🔒 **Privacy Mode**: Tap the eye icon to hide all financial amounts and sensitive data
  - Masks investment values, returns, and percentages with `••••`
  - Hides goal progress and amounts
  - Perfect for checking your portfolio in public

### Changed
- Improved number formatting consistency across the app
- Centralized compact amount display with `CompactAmountText` widget
- Enhanced goal progress display with privacy mode support
- Better currency formatting for large numbers (K, L, Cr abbreviations)

### Fixed
- Privacy mode now works consistently across all screens:
  - Overview dashboard
  - Investment detail screen
  - Goal cards and goal details
  - Analytics widgets
- Fixed notification permission checks for milestone notifications
- Fixed notification settings toggle reactivity

---

## [3.2.0] - 2025-12-27

### Added

#### 🎯 Financial Goals
- New Goals feature to set and track financial targets
- Support for corpus goals (reach a target amount)
- Support for income goals (generate target monthly income)
- Beautiful progress rings with milestone celebrations
- Link investments to goals to track contributions
- Goal details screen with progress breakdown
- Goals dashboard card on overview screen

#### 🔔 Smart Notifications
- Income payment reminders (get notified before income is due)
- Maturity date alerts (never miss when investments mature)
- Weekly portfolio summary notifications
- Customizable notification settings per category
- Deep linking from notifications to relevant screens

#### 📄 Document Management
- Attach documents to investments (receipts, contracts, etc.)
- Document viewer with full-screen support
- Support for images and PDF files
- Cloud storage for documents with sync

#### ⚙️ Enhanced Settings
- Reorganized settings with dedicated screens
- New Appearance settings screen
- New Notifications settings screen
- New Security settings screen
- New Data Management screen
- New About screen with app info

### Changed
- Improved investment detail screen layout
- Enhanced currency formatting with compact notation
- Better number formatting utilities
- Optimized settings screen navigation
- Improved investment card design

### Fixed
- Currency display formatting issues
- Test repository implementations for archived collections
- Various UI polish and stability improvements

---

## [3.1.0] - 2025-12-15

### Added
- Archive/Unarchive investments feature
- Separate archived investments view
- Archived cash flows management

### Changed
- Improved investment list filtering
- Enhanced repository interfaces

---

## [3.0.0] - 2025-12-01

### Added
- Initial release with core investment tracking
- XIRR and MOIC calculations
- Offline-first with cloud sync
- Google Sign-In authentication
- Dark mode support
- Clean dashboard with analytics

