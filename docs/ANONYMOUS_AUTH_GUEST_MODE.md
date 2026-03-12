# Anonymous Auth Guest Mode - Implementation Plan

## Overview

Allow users to use InvTrack without signing in by leveraging **Firebase Anonymous Authentication**. This is the simplest approach with minimal code changes.

---

## Architecture

### Single Storage Layer

```text
User opens app
    ↓
Firebase Anonymous Sign-In (automatic)
    ↓
User gets Firebase UID (e.g., "aBcD1234xyz")
    ↓
All data stored in Firestore: users/{anonymousUID}/investments/...
    ↓
Firestore offline persistence enabled (works offline)
    ↓
When user signs in with Google:
    ↓
Try to link accounts → Success: Data stays at same UID
                     → Fail: Create ZIP backup, sign in, manual import
```

### Key Benefits

- ✅ **Simple**: Only 1 storage layer (Firestore)
- ✅ **Secure**: Firebase Auth + Firestore security rules work normally
- ✅ **No migration service**: Account linking handles most cases
- ✅ **Offline works**: Firestore offline persistence
- ✅ **85% less code**: ~400 lines vs ~2000 lines (Hive approach)

---

## Trade-offs Accepted

| Issue | Status | Mitigation |
|-------|--------|------------|
| Data lost on uninstall | ✅ Accepted | Same as current app behavior |
| Account linking fails (Google account exists) | ✅ Accepted | ZIP backup + manual import |
| Orphaned anonymous users | ✅ Accepted | Cloud Function cleanup (30 days) |
| Firebase costs (≈$0.0055/user as of Mar 2026) | ✅ Accepted | Minimal per-user cost — [verify current pricing](https://firebase.google.com/pricing) |
| First launch needs internet | ✅ Accepted | Same as current app |

---

## Implementation Phases

### Phase 1: Enable Anonymous Auth (Week 1)

**Tasks**:
1. Enable Firebase Anonymous Authentication in Firebase Console
2. Add `isAnonymous` flag to `UserEntity` domain model
3. Update onboarding screen with "Continue as Guest" button
4. Show GDPR notice at guest entry (data stored locally, can be deleted anytime)
5. Auto sign-in anonymously on first launch
6. Add anonymous user indicator in Settings
7. Add in-app data deletion option for guest users

**Files to Modify**:
- `lib/features/auth/domain/entities/user_entity.dart` (add `isAnonymous: bool` field)
- `lib/features/auth/presentation/screens/onboarding_screen.dart` (page 4: add "Continue as Guest" button below "Sign In with Google")
- `lib/features/auth/presentation/screens/sign_in_screen.dart` (support anonymous flow)
- `lib/features/settings/presentation/screens/settings_screen.dart` (guest mode indicator)
- `lib/features/settings/presentation/screens/data_management_screen.dart` (add "Delete Guest Data" option)

**Analytics Events** (add to analytics service):
- `guest_mode_started` - When user taps "Continue as Guest"
- `guest_mode_data_deleted` - When user deletes guest data from Settings

**Localization Strings** (add to `lib/l10n/app_en.arb`):
```json
{
  "continueAsGuest": "Continue as Guest",
  "guestModeNotice": "Your data will be stored locally on this device only. You can sign in later to backup to cloud.",
  "guestModeIndicator": "Guest Mode",
  "signInToBackup": "Sign In to Backup",
  "deleteGuestData": "Delete Guest Data",
  "deleteGuestDataConfirm": "Are you sure? This will permanently delete all your local data.",
  "guestDataDeleted": "Guest data deleted successfully"
}
```

**GDPR Compliance** (🚨 Must-fix before Phase 1 ships):
- Show notice at guest entry: "Your investment data will be stored locally. You can delete it anytime from Settings."
- Provide in-app deletion: Settings → Data Management → Delete Guest Data
- No analytics tracking for guest users without explicit consent

**Accessibility Checklist** (WCAG compliance):
- [ ] "Continue as Guest" button: ≥44×44dp touch target
- [ ] Semantic label: "Continue as Guest button"
- [ ] Color contrast: ≥4.5:1 ratio
- [ ] Screen reader compatible (test with TalkBack/VoiceOver)

**Deliverables**:
- [ ] Anonymous sign-in working
- [ ] `UserEntity.isAnonymous` flag implemented
- [ ] User can use app without Google sign-in
- [ ] Settings shows "Guest Mode" indicator
- [ ] GDPR notice shown at guest entry
- [ ] In-app data deletion option available
- [ ] All strings localized
- [ ] Analytics events instrumented
- [ ] Accessibility verified

---

### Phase 2: Google Sign-In with Account Linking (Week 2)

**Tasks**:
1. Create `LinkAccountUseCase` in domain layer (clean architecture)
2. Implement account linking logic in `FirebaseAuthRepository` (data layer)
3. Create Google sign-in handler in presentation layer
4. Guard auth-state navigation during linking (prevent navigation loops)
5. Invalidate Riverpod providers on UID change (refresh cached data)
6. Handle linking success (data stays at same UID)
7. Handle linking failure (Google account already exists)
8. Show backup & merge dialog on linking failure
9. Create encrypted ZIP backup (AES-256 or protected internal directory)

**Files to Create**:
- `lib/features/auth/domain/usecases/link_account_usecase.dart` (business logic)
- `lib/features/auth/presentation/handlers/google_sign_in_handler.dart` (UI handler)
- `lib/features/auth/presentation/dialogs/backup_merge_dialog.dart` (backup flow UI)

**Files to Modify**:
- `lib/features/auth/data/repositories/firebase_auth_repository.dart` (add `linkAnonymousToGoogle()` method)
- `lib/features/auth/presentation/providers/auth_provider.dart` (suppress navigation during linking)
- `lib/core/di/repository_module.dart` (invalidate providers on UID change)

**ZIP Backup Format** (OWASP MASVS compliance):
```json
{
  "version": "1.0",
  "exportDate": "2026-03-12T10:30:00Z",
  "anonymousUID": "aBcD1234xyz",
  "encryption": "AES-256-GCM",
  "collections": {
    "investments": [...],
    "cashflows": [...],
    "goals": [...]
  }
}
```
- Encrypted with AES-256-GCM using device-generated key
- Stored in protected internal directory (not external storage)
- Deleted after successful import

**Analytics Events**:
- `account_link_success` - Anonymous account linked to Google
- `account_link_failure` - Linking failed (Google account exists)
- `backup_created` - ZIP backup created before sign-in
- `backup_imported` - ZIP backup imported after sign-in

**Backup & Merge Dialog Flow**:
1. User taps "Sign In with Google" (while in guest mode)
2. Try to link accounts
3. If linking fails (Google account exists):
   - Show dialog: "This Google account already exists. Create backup?"
   - User chooses: "Backup & Sign In" or "Cancel"
   - If "Backup & Sign In":
     - Create encrypted ZIP backup
     - Sign in with Google (new session)
     - Show success: "Backup created. Import now?"
     - User chooses: "Import Now" or "Later"

**Deliverables**:
- [ ] `LinkAccountUseCase` implemented in domain layer
- [ ] Account linking logic in `FirebaseAuthRepository`
- [ ] Account linking works when Google account is new
- [ ] Backup dialog shown when Google account exists
- [ ] Encrypted ZIP backup created (AES-256)
- [ ] User can import backup after signing in
- [ ] Auth-state navigation guarded during linking
- [ ] Providers invalidated on UID change
- [ ] Analytics events instrumented

---

### Phase 3: Cloud Function Cleanup (Week 3)

**Tasks**:
1. Create Cloud Function to delete old anonymous users
2. Run daily at 2 AM UTC
3. Delete anonymous users inactive for 30+ days
4. Delete associated Firestore data
5. Delete Firebase Auth anonymous user accounts (prevent orphaned auth records)

**Files to Create**:
- `functions/src/cleanupAnonymousUsers.ts`

**Cloud Function Implementation**:
```typescript
// Must delete BOTH Firestore data AND Firebase Auth user
export const cleanupOldAnonymousUsers = functions.pubsub
  .schedule('0 2 * * *')
  .timeZone('UTC')
  .onRun(async (context) => {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 30);

    const listUsersResult = await admin.auth().listUsers();

    for (const user of listUsersResult.users) {
      if (user.providerData.length === 0) { // Anonymous user
        const lastSignIn = new Date(user.metadata.lastSignInTime);

        if (lastSignIn < cutoffDate) {
          // 1. Delete Firestore data
          await deleteUserData(user.uid);

          // 2. Delete Firebase Auth user (CRITICAL - prevents orphaned auth records)
          await admin.auth().deleteUser(user.uid);
        }
      }
    }
  });
```

**Deliverables**:
- [ ] Cloud Function deployed
- [ ] Cleanup runs daily
- [ ] Old anonymous Firestore data deleted
- [ ] Old anonymous Firebase Auth users deleted
- [ ] No orphaned auth records remain

---

### Phase 4: UI/UX Polish (Week 4)

**Tasks**:
1. Add guest mode indicator in app bar
2. Update Help & FAQ with guest mode info
3. Add localization strings
4. Add "Sign In to Backup" prompts
5. Testing on Android and iOS

**Files to Modify**:
- `lib/features/settings/presentation/screens/help_faq_screen.dart`
- `lib/l10n/app_en.arb`
- `lib/core/widgets/app_bar.dart` (if custom app bar exists)

**Deliverables**:
- [ ] Guest mode clearly indicated
- [ ] Help & FAQ updated
- [ ] All strings localized
- [ ] Tested on both platforms

---

## Code Changes Summary

### No Changes Needed

- ✅ Repository implementations (already use Firestore)
- ✅ Domain entities (no changes)
- ✅ UI screens (work with any authenticated user)
- ✅ Offline persistence (already enabled)

### Minimal Changes

- ⚠️ Onboarding screen (add "Continue as Guest" button)
- ⚠️ Settings screen (show guest mode indicator)
- ⚠️ Google sign-in flow (add account linking logic)

### New Files (3 total)

1. `google_sign_in_handler.dart` (~200 lines)
2. `backup_merge_dialog.dart` (~100 lines)
3. `cleanupAnonymousUsers.ts` (~100 lines)

**Total new code: ~400 lines**

---

## Security

### Firestore Security Rules (No Changes)

```javascript
// Same rules work for anonymous and signed-in users
match /users/{userId}/investments/{investmentId} {
  allow read, write: if request.auth.uid == userId;
  // ✅ Anonymous users have request.auth.uid
  // ✅ Can only access their own data
}
```

### Anonymous User Cleanup

```javascript
// Cloud Function runs daily
// Deletes anonymous users inactive for 30+ days
// Prevents orphaned data accumulation
```

---

## Timeline

| Week | Phase | Effort |
|------|-------|--------|
| Week 1 | Enable Anonymous Auth | 2 days |
| Week 2 | Google Sign-In + Linking | 3 days |
| Week 3 | Cloud Function Cleanup | 2 days |
| Week 4 | UI/UX Polish + Testing | 3 days |

**Total: 4 weeks, 1 developer**

---

## Success Metrics

- ✅ Users can use app without signing in
- ✅ Account linking works (when Google account is new)
- ✅ Backup + import works (when Google account exists)
- ✅ Old anonymous data cleaned up automatically
- ✅ Zero `flutter analyze` errors
- ✅ All tests passing

---

## Next Steps

1. Review this plan
2. Get approval
3. Start Phase 1 implementation
4. Create JIRA tickets for each phase

---

**Status**: Ready for Review  
**Last Updated**: March 12, 2026

