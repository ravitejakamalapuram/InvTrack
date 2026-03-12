# Anonymous Auth Guest Mode - Implementation Plan

## Overview

Allow users to use InvTrack without signing in by leveraging **Firebase Anonymous Authentication**. This is the simplest approach with minimal code changes.

---

## Architecture

### Single Storage Layer
```
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
- ✅ **85% less code**: ~300 lines vs ~2000 lines (Hive approach)

---

## Trade-offs Accepted

| Issue | Status | Mitigation |
|-------|--------|------------|
| Data lost on uninstall | ✅ Accepted | Same as current app behavior |
| Account linking fails (Google account exists) | ✅ Accepted | ZIP backup + manual import |
| Orphaned anonymous users | ✅ Accepted | Cloud Function cleanup (30 days) |
| Firebase costs (~$0.0055/user) | ✅ Accepted | Minimal cost, scales with usage |
| First launch needs internet | ✅ Accepted | Same as current app |

---

## Implementation Phases

### Phase 1: Enable Anonymous Auth (Week 1)

**Tasks**:
1. Enable Firebase Anonymous Authentication in Firebase Console
2. Update onboarding screen with "Continue as Guest" button
3. Auto sign-in anonymously on first launch
4. Add anonymous user indicator in Settings

**Files to Modify**:
- `lib/features/auth/presentation/screens/onboarding_screen.dart`
- `lib/features/settings/presentation/screens/settings_screen.dart`

**Deliverables**:
- [ ] Anonymous sign-in working
- [ ] User can use app without Google sign-in
- [ ] Settings shows "Guest Mode" indicator

---

### Phase 2: Google Sign-In with Account Linking (Week 2)

**Tasks**:
1. Implement Google sign-in handler
2. Try to link anonymous account to Google account
3. Handle linking success (data stays at same UID)
4. Handle linking failure (Google account already exists)
5. Show backup & merge dialog on linking failure

**Files to Create**:
- `lib/features/auth/presentation/handlers/google_sign_in_handler.dart`
- `lib/features/auth/presentation/dialogs/backup_merge_dialog.dart`

**Deliverables**:
- [ ] Account linking works when Google account is new
- [ ] Backup dialog shown when Google account exists
- [ ] ZIP backup created before signing in
- [ ] User can import backup after signing in

---

### Phase 3: Cloud Function Cleanup (Week 3)

**Tasks**:
1. Create Cloud Function to delete old anonymous users
2. Run daily at 2 AM UTC
3. Delete anonymous users inactive for 30+ days
4. Delete associated Firestore data

**Files to Create**:
- `functions/src/cleanupAnonymousUsers.ts`

**Deliverables**:
- [ ] Cloud Function deployed
- [ ] Cleanup runs daily
- [ ] Old anonymous data deleted

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

