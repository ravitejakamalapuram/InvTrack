# InvTrack Task Tracker

> **Created**: 2026-01-10
> **Last Updated**: 2026-01-10

---

## Quick Summary

| # | Task | Status | Priority | Complexity |
|---|------|--------|----------|------------|
| 1 | Help & FAQ page fix | ✅ Complete | High | Low |
| 2 | Contact Support fix | ✅ Complete | High | Low |
| 3 | Simplify Add Transaction | ✅ Complete | Medium | Medium |
| 4 | Redesign Documents | ✅ Complete | Medium | High |
| 5 | Document Swipe Actions | ✅ Complete | Medium | Medium |
| 6 | Invoice Discounting type | ✅ Complete | Low | Low |
| 7 | FIRE Privacy Mode | ✅ Complete | Medium | Medium |

---

## Task 1: Help & FAQ Page Cannot Open

### Analysis
- **Root Cause**: `url_launcher` missing URL scheme config in iOS Info.plist
- **File**: `lib/features/settings/presentation/screens/about_screen.dart`
- **Current URL**: `https://github.com/ravitejakamalapuram/InvTrack#readme`

### Solution
1. Add `LSApplicationQueriesSchemes` with `https` to iOS Info.plist
2. Add fallback: copy URL to clipboard if launch fails

### Files to Modify
- [x] `ios/Runner/Info.plist` - Added LSApplicationQueriesSchemes for https, http, mailto
- [x] `android/app/src/main/AndroidManifest.xml` - Added query intents for VIEW and SENDTO
- [x] `lib/features/settings/presentation/screens/about_screen.dart` - Added clipboard fallback

### Status: ✅ Complete

### Changes Made
1. Added `LSApplicationQueriesSchemes` with `https`, `http`, `mailto` to iOS Info.plist
2. Added query intents for `android.intent.action.VIEW` (https) and `android.intent.action.SENDTO` (mailto) in Android manifest
3. Added clipboard fallback with user-friendly message when launch fails

---

## Task 2: Contact Support Cannot Open

### Analysis
- **Root Cause**: `mailto:` scheme not in iOS query schemes
- **File**: `lib/features/settings/presentation/screens/about_screen.dart`

### Solution
1. Add `mailto` to `LSApplicationQueriesSchemes` in iOS Info.plist
2. Fallback: copy email to clipboard with success message

### Files to Modify
- [x] `ios/Runner/Info.plist` - (Done with Task 1)
- [x] `android/app/src/main/AndroidManifest.xml` - (Done with Task 1)
- [x] `lib/features/settings/presentation/screens/about_screen.dart` - Added try-catch and clipboard fallback

### Status: ✅ Complete

### Changes Made
1. Same platform config as Task 1
2. Added try-catch around launch with clipboard fallback
3. User sees "Email copied to clipboard: support@invtracker.com" if email client can't open

---

## Task 3: Simplify Add Transaction Button

### Analysis
- **Current**: PopupMenuButton with 3 options
- **Proposed**: Direct button → form with smart default
- **Smart Default Logic**:
  - First transaction: `CashFlowType.invest`
  - Subsequent: `CashFlowType.income`

### Files Modified
- [x] `lib/features/investment/presentation/screens/investment_detail_screen.dart`

### Status: ✅ Complete

### Changes Made
1. Removed `PopupMenuButton` from FAB
2. Replaced with direct `GestureDetector` that navigates to `AddTransactionScreen`
3. Smart default: checks if investment has existing cash flows
   - No transactions → default to `CashFlowType.invest`
   - Has transactions → default to `CashFlowType.income`

---

## Task 4: Redesign Save Documents Feature

### Analysis
- **Current**: 4 source buttons (Camera, Gallery, Single, Multiple)
- **Proposed**: 2 buttons (Camera, Files) with unified picker

### Key Changes
1. Simplify to 2 source options
2. Add upload progress indicators
3. Expand allowed file types
4. Auto-detect document type from extension

### Files Modified
- [x] `lib/features/investment/presentation/widgets/add_document_sheet.dart`

### Status: ✅ Complete

### Changes Made
1. Simplified to 2 buttons: **Camera** and **Select Files**
2. Unified file picker supports all extensions (pdf, png, jpg, jpeg, gif, webp, heic)
3. Auto-detect document type from file extension
4. Added upload progress indicator with file count
5. Added thumbnail previews for images
6. Added file size display
7. Per-file auto-detected type (images → Image, PDFs → Receipt)

---

## Task 5: Add Swipe Actions to Documents

### Analysis
- **Current**: PopupMenuButton with View/Edit/Delete
- **Proposed**: Swipe actions (existing pattern)

### Swipe Configuration
- Left → Delete with confirmation
- Right → Edit (open sheet)
- Tap → Open document

### Files Modified
- [x] `lib/features/investment/presentation/widgets/document_list_widget.dart`

### Status: ✅ Complete

### Changes Made
1. Replaced `PopupMenuButton` with `Dismissible` widget
2. Swipe right (startToEnd) → Edit action with blue background
3. Swipe left (endToStart) → Delete action with red gradient, confirmation dialog
4. Tap → Open document viewer (unchanged)
5. Added subtle swipe hint icon
6. Uses `AppFeedback.showConfirmDialog` for consistent UX

---

## Task 6: Add Invoice Discounting Investment Type

### Analysis
- Add new enum value to `InvestmentType`
- Icon: `Icons.receipt_long_rounded`
- Color: Sky Blue `#0EA5E9`

### Files Modified
- [x] `lib/features/investment/domain/entities/investment_entity.dart`

### Status: ✅ Complete

### Changes Made
1. Added `invoiceDiscounting` to InvestmentType enum (between `stocks` and `financing`)
2. Added displayName: "Invoice Discounting"
3. Added icon: `Icons.receipt_long_rounded`
4. Added color: Sky Blue (#0EA5E9) - unique color not used by other types

---

## Task 7: FIRE Feature & Privacy Mode

### Analysis
- Ensure all FIRE monetary values are wrapped with `PrivacyMask`

### Files Modified
- [x] `lib/features/fire_number/presentation/screens/fire_dashboard_screen.dart`
- [x] `lib/features/fire_number/presentation/widgets/fire_progress_ring.dart`
- [x] `lib/features/fire_number/presentation/widgets/fire_stats_card.dart`
- [x] `lib/features/fire_number/presentation/widgets/fire_milestone_card.dart`

### Status: ✅ Complete

### Changes Made
1. Wrapped FIRE number with `PrivacyMask` in dashboard
2. Wrapped current net worth with `PrivacyMask` in progress ring
3. Wrapped all stats in `FireStatsCard`: monthly income, monthly expenses, savings rate, years to FIRE
4. Wrapped milestone amounts with `PrivacyMask` in milestone cards
5. All monetary values now hidden when privacy mode is enabled

---

## Implementation Log

### 2026-01-10
- Created task tracker
- Starting with quick wins (Tasks 1, 2, 6)
- ✅ Task 1 & 2: Fixed URL launcher issues
  - Added LSApplicationQueriesSchemes to iOS Info.plist (https, http, mailto)
  - Added query intents to Android manifest (VIEW for https, SENDTO for mailto)
  - Added clipboard fallback with user feedback when launch fails
- ✅ Task 6: Added Invoice Discounting investment type
  - New enum value with displayName, icon, and color
  - Ready for use in investment creation

### 2026-01-11
- ✅ Task 3: Simplified Add Transaction button
  - Removed popup menu, direct navigation with smart defaults
- ✅ Task 4: Redesigned Save Documents feature
  - 2 buttons (Camera, Files), upload progress, auto-detect type
- ✅ Task 5: Added swipe actions to documents
  - Swipe left to delete, right to edit, tap to open
- ✅ Task 7: FIRE feature privacy mode
  - All monetary values wrapped with PrivacyMask
- **All 7 tasks complete!**